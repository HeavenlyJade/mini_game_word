local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local VectorUtils = require(MainStorage.Code.Untils.VectorUtils) ---@type VectorUtils
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

---@class BattleSystem 战斗系统
---@field entity any 所属实体
local BattleSystem = ClassMgr.Class("BattleSystem")

-- 初始化战斗系统
function BattleSystem:OnInit(entity)
    self.entity = entity -- 所属实体
end

-- 战斗核心 --------------------------------------------------------

--- 攻击目标
---@param victim any 目标对象
---@param baseDamage number 基础伤害
---@param source string|nil 伤害来源
---@param castParam any|nil 施法参数
---@return any 战斗结果
function BattleSystem:Attack(victim, baseDamage, source, castParam)
    if not victim or not victim.CanBeTargeted or not victim:CanBeTargeted() then
        return nil
    end

    -- 检查敌对关系
    if not self:IsEnemy(victim) then
        return nil
    end

    -- 创建战斗对象计算伤害
    local Battle = require(MainStorage.Code.MServer.Battle)
    if not Battle then
        -- 如果没有Battle类，使用简化计算
        return self:SimpleAttack(victim, baseDamage, source, castParam)
    end

    local battle = Battle.New(self.entity, victim, source, castParam)
    battle:AddModifier("BASE", "增加", baseDamage)
    
    -- 触发攻击者的攻击词条
    if self.entity.tagSystem then
        self.entity.tagSystem:TriggerTags("攻击", victim, castParam, battle)
    end
    
    -- 触发受害者的防御词条
    if victim.tagSystem then
        victim.tagSystem:TriggerTags("受击", self.entity, castParam, battle)
    end
    
    battle:CalculateBattle()

    -- 对目标造成伤害
    if victim.Hurt then
        victim:Hurt(battle:GetFinalDamage(), self.entity, battle.isCrit)
    end
    
    -- 触发攻击后事件
    self:TriggerBattleEvent("AttackComplete", {
        attacker = self.entity,
        victim = victim,
        damage = battle:GetFinalDamage(),
        isCrit = battle.isCrit,
        battle = battle
    })

    return battle
end

--- 简化攻击（当没有Battle类时使用）
---@param victim any 目标对象
---@param baseDamage number 基础伤害
---@param source string|nil 伤害来源
---@param castParam any|nil 施法参数
---@return table 简化战斗结果
function BattleSystem:SimpleAttack(victim, baseDamage, source, castParam)
    -- 获取攻击者属性
    local attackPower = baseDamage
    if self.entity.statSystem then
        attackPower = attackPower + self.entity.statSystem:GetStat("攻击", nil, false)
    end
    
    -- 获取目标防御
    local defense = 0
    if victim.statSystem then
        defense = victim.statSystem:GetStat("防御", nil, false)
    end
    
    -- 简单伤害计算
    local finalDamage = math.max(1, attackPower - defense)
    local isCrit = math.random() < 0.1 -- 10%暴击率
    
    if isCrit then
        finalDamage = finalDamage * 2
    end
    
    -- 对目标造成伤害
    if victim.Hurt then
        victim:Hurt(finalDamage, self.entity, isCrit)
    end
    
    -- 触发攻击后事件
    self:TriggerBattleEvent("AttackComplete", {
        attacker = self.entity,
        victim = victim,
        damage = finalDamage,
        isCrit = isCrit
    })
    
    return {
        finalDamage = finalDamage,
        isCrit = isCrit,
        GetFinalDamage = function() return finalDamage end
    }
end

--- 范围攻击
---@param position Vector3 攻击位置
---@param radius number 攻击半径
---@param baseDamage number 基础伤害
---@param source string|nil 伤害来源
---@param castParam any|nil 施法参数
---@return table[] 战斗结果列表
function BattleSystem:AreaAttack(position, radius, baseDamage, source, castParam)
    local results = {}
    local targets = self:GetTargetsInRange(position, radius)
    
    for _, target in ipairs(targets) do
        if self:IsEnemy(target) and target:CanBeTargeted() then
            local result = self:Attack(target, baseDamage, source, castParam)
            if result then
                table.insert(results, result)
            end
        end
    end
    
    return results
end

--- 治疗目标
---@param target any 目标对象
---@param baseHeal number 基础治疗量
---@param source string|nil 治疗来源
---@param castParam any|nil 施法参数
---@return number 实际治疗量
function BattleSystem:Heal(target, baseHeal, source, castParam)
    if not target or target.isDead then
        return 0
    end

    -- 检查是否为友军
    if not self:IsAlly(target) then
        return 0
    end

    local finalHeal = baseHeal
    
    -- 获取治疗加成
    if self.entity.statSystem then
        local healPower = self.entity.statSystem:GetStat("治疗强度", nil, false)
        finalHeal = finalHeal + healPower
    end
    
    -- 触发治疗词条
    if self.entity.tagSystem then
        -- 这里可以添加治疗词条逻辑
    end
    
    -- 执行治疗
    if target.Heal then
        target:Heal(finalHeal, source)
    end
    
    -- 触发治疗事件
    self:TriggerBattleEvent("HealComplete", {
        healer = self.entity,
        target = target,
        healAmount = finalHeal
    })
    
    return finalHeal
end

-- 敌对关系 --------------------------------------------------------

--- 检查是否为敌人
---@param target any 目标对象
---@return boolean
function BattleSystem:IsEnemy(target)
    if not target or not self.entity then
        return false
    end
    
    -- 如果目标就是自己，不是敌人
    if target == self.entity then
        return false
    end
    
    -- 如果都是玩家，默认不是敌人（除非有PVP设置）
    if self.entity.isPlayer and target.isPlayer then
        return false
    end
    
    -- 玩家 vs 怪物
    if self.entity.isPlayer and not target.isPlayer then
        return true
    end
    
    -- 怪物 vs 玩家
    if not self.entity.isPlayer and target.isPlayer then
        return true
    end
    
    -- 使用碰撞组判断敌对关系
    return self:CheckEnemyByCollisionGroup(target)
end

--- 检查是否为友军
---@param target any 目标对象
---@return boolean
function BattleSystem:IsAlly(target)
    if not target or not self.entity then
        return false
    end
    
    -- 自己总是友军
    if target == self.entity then
        return true
    end
    
    -- 简单判断：相同类型为友军
    if self.entity.isPlayer == target.isPlayer then
        return true
    end
    
    return false
end

--- 通过碰撞组检查敌对关系
---@param target any 目标对象
---@return boolean
function BattleSystem:CheckEnemyByCollisionGroup(target)
    if not self.entity.actor or not target.actor then
        return false
    end
    
    local myGroup = self.entity.actor.CollideGroupID
    local targetGroup = target.actor.CollideGroupID
    
    -- 获取敌对组列表
    local enemyGroups = self:GetEnemyGroups()
    
    for _, enemyGroup in ipairs(enemyGroups) do
        if targetGroup == enemyGroup then
            return true
        end
    end
    
    return false
end

--- 获取敌对组列表
---@return number[]
function BattleSystem:GetEnemyGroups()
    if not self.entity.actor then
        return {1}
    end
    
    local groupId = self.entity.actor.CollideGroupID
    if groupId == 3 then
        return {4}
    elseif groupId == 4 then
        return {3}
    else
        return {3, 4}
    end
end

-- 目标搜索 --------------------------------------------------------

--- 获取范围内的目标
---@param position Vector3 中心位置
---@param radius number 搜索半径
---@return any[] 目标列表
function BattleSystem:GetTargetsInRange(position, radius)
    local targets = {}
    
    if not self.entity.scene then
        return targets
    end
    
    -- 搜索场景中的所有实体
    for _, entity in pairs(self.entity.scene.uuid2Entity) do
        if entity ~= self.entity and entity:CanBeTargeted() then
            local distance = VectorUtils.Vec.Distance3(position, entity:GetPosition())
            if distance <= radius then
                table.insert(targets, entity)
            end
        end
    end
    
    return targets
end

--- 获取最近的敌人
---@param maxDistance number|nil 最大搜索距离，默认无限制
---@return any|nil 最近的敌人
function BattleSystem:GetNearestEnemy(maxDistance)
    local nearestEnemy = nil
    local nearestDistance = maxDistance or math.huge
    local myPosition = self.entity:GetPosition()
    
    if not self.entity.scene then
        return nil
    end
    
    for _, entity in pairs(self.entity.scene.uuid2Entity) do
        if self:IsEnemy(entity) and entity:CanBeTargeted() then
            local distance = VectorUtils.Vec.Distance3(myPosition, entity:GetPosition())
            if distance < nearestDistance then
                nearestDistance = distance
                nearestEnemy = entity
            end
        end
    end
    
    return nearestEnemy
end

--- 获取范围内的敌人
---@param radius number 搜索半径
---@return any[] 敌人列表
function BattleSystem:GetEnemiesInRange(radius)
    local enemies = {}
    local targets = self:GetTargetsInRange(self.entity:GetPosition(), radius)
    
    for _, target in ipairs(targets) do
        if self:IsEnemy(target) then
            table.insert(enemies, target)
        end
    end
    
    return enemies
end

--- 获取范围内的友军
---@param radius number 搜索半径
---@return any[] 友军列表
function BattleSystem:GetAlliesInRange(radius)
    local allies = {}
    local targets = self:GetTargetsInRange(self.entity:GetPosition(), radius)
    
    for _, target in ipairs(targets) do
        if self:IsAlly(target) then
            table.insert(allies, target)
        end
    end
    
    return allies
end

-- 战斗状态 --------------------------------------------------------

--- 检查是否在战斗中
---@return boolean
function BattleSystem:IsInCombat()
    return self.entity.combatTime and self.entity.combatTime > 0
end

--- 进入战斗状态
---@param duration number|nil 战斗持续时间，默认10秒
function BattleSystem:EnterCombat(duration)
    duration = duration or 10
    self.entity.combatTime = duration
    
    -- 触发进入战斗事件
    self:TriggerBattleEvent("EnterCombat", {
        entity = self.entity,
        duration = duration
    })
end

--- 退出战斗状态
function BattleSystem:ExitCombat()
    self.entity.combatTime = 0
    
    -- 触发退出战斗事件
    self:TriggerBattleEvent("ExitCombat", {
        entity = self.entity
    })
end

-- 伤害类型 --------------------------------------------------------

--- 造成物理伤害
---@param target any 目标
---@param damage number 伤害值
---@param source string|nil 来源
---@return number 实际伤害
function BattleSystem:DealPhysicalDamage(target, damage, source)
    -- 计算物理防御减伤
    local defense = 0
    if target.statSystem then
        defense = target.statSystem:GetStat("物理防御", nil, false)
    end
    
    local finalDamage = math.max(1, damage - defense)
    
    if target.Hurt then
        target:Hurt(finalDamage, self.entity, false)
    end
    
    return finalDamage
end

--- 造成魔法伤害
---@param target any 目标
---@param damage number 伤害值
---@param source string|nil 来源
---@return number 实际伤害
function BattleSystem:DealMagicalDamage(target, damage, source)
    -- 计算魔法防御减伤
    local resistance = 0
    if target.statSystem then
        resistance = target.statSystem:GetStat("魔法抗性", nil, false)
    end
    
    local finalDamage = math.max(1, damage - resistance)
    
    if target.Hurt then
        target:Hurt(finalDamage, self.entity, false)
    end
    
    return finalDamage
end

--- 造成真实伤害（无视防御）
---@param target any 目标
---@param damage number 伤害值
---@param source string|nil 来源
---@return number 实际伤害
function BattleSystem:DealTrueDamage(target, damage, source)
    if target.Hurt then
        target:Hurt(damage, self.entity, false)
    end
    
    return damage
end

-- 事件系统 --------------------------------------------------------

--- 触发战斗事件
---@param eventType string 事件类型
---@param eventData table 事件数据
function BattleSystem:TriggerBattleEvent(eventType, eventData)
    eventData.eventType = eventType
    eventData.timestamp = gg.GetTimeStamp()
    ServerEventManager.Publish("BattleEvent", eventData)
end

-- 工具方法 --------------------------------------------------------

--- 计算伤害减免
---@param damage number 原始伤害
---@param armor number 护甲值
---@return number 减免后伤害
function BattleSystem:CalculateDamageReduction(damage, armor)
    -- 简单的伤害减免公式：伤害 = 原始伤害 * (100 / (100 + 护甲))
    local reduction = armor / (100 + armor)
    return damage * (1 - reduction)
end

--- 计算暴击
---@param baseDamage number 基础伤害
---@param critChance number 暴击率（0-1）
---@param critMultiplier number 暴击倍数，默认2.0
---@return number, boolean 最终伤害和是否暴击
function BattleSystem:CalculateCritical(baseDamage, critChance, critMultiplier)
    critMultiplier = critMultiplier or 2.0
    local isCrit = math.random() < critChance
    
    if isCrit then
        return baseDamage * critMultiplier, true
    else
        return baseDamage, false
    end
end

--- 计算命中
---@param accuracy number 命中率（0-1）
---@param evasion number 闪避率（0-1）
---@return boolean 是否命中
function BattleSystem:CalculateHit(accuracy, evasion)
    local hitChance = math.max(0.05, accuracy - evasion) -- 最低5%命中率
    return math.random() < hitChance
end

-- 静态方法 --------------------------------------------------------

--- 创建新的战斗系统实例
---@param entity any 所属实体
---@return BattleSystem
function BattleSystem.New(entity)
    local instance = BattleSystem()
    instance:OnInit(entity)
    return instance
end

return BattleSystem 