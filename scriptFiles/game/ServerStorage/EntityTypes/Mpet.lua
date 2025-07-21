-- EntityTypes/Mpet.lua
-- 宠物实体类
-- 继承自Entity，专注于宠物在场景中的行为表现和实体逻辑
-- 与MSystems/Pet的数据管理分离，保持职责单一

local game = game
local math = math
local table = table
local pairs = pairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local Entity = require(ServerStorage.EntityTypes.Entity) ---@type Entity
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class Mpet:Entity 宠物实体类
---@field petConfigName string 宠物配置名称
---@field ownerUin number 主人UIN
---@field slotIndex number 槽位索引
---@field petConfig PetTypeConfig 宠物配置数据
---@field followTarget Entity 跟随目标
---@field behaviorState string 行为状态
---@field lastStateTime number 上次状态切换时间
---@field aiTimer number AI更新计时器
---@field skillCooldowns table<string, number> 技能冷却时间
---@field isFollowing boolean 是否正在跟随
local Mpet = ClassMgr.Class("Mpet", Entity)

---初始化宠物实体
---@param info table 初始化信息
function Mpet:OnInit(info)
    -- 调用父类初始化
    Entity.OnInit(self, info)
    
    -- 宠物实体专用初始化
    self.petConfigName = info.petConfigName or ""
    self.ownerUin = info.ownerUin or 0
    self.slotIndex = info.slotIndex or 0
    self.followTarget = nil
    self.behaviorState = "idle"
    self.lastStateTime = os.time()
    self.aiTimer = 0
    self.skillCooldowns = {}
    self.isFollowing = false
    
    -- 加载宠物配置
    self:LoadPetConfig()
    
    -- 初始化Actor
    self:InitializeActor()
    
    gg.log("Mpet实体创建", self.petConfigName, "主人", self.ownerUin, "UUID", self.uuid)
end

---加载宠物配置
function Mpet:LoadPetConfig()
    if self.petConfigName == "" then
        gg.log("警告：宠物配置名称为空", self.ownerUin)
        return
    end
    
    self.petConfig = ConfigLoader.GetConfig("PetType", self.petConfigName)
    if not self.petConfig then
        gg.log("警告：找不到宠物配置", self.petConfigName)
    end
end

---初始化Actor
function Mpet:InitializeActor()
    if not self.petConfig or not self.petConfig.modelPath then
        gg.log("警告：宠物配置或模型路径缺失", self.petConfigName)
        return
    end
    
    -- 创建宠物Actor
    local actor = game:GetService("WorldService"):CreateActor(self.petConfig.modelPath)
    if actor then
        self.actor = actor
        self.actor.Name = self.petConfigName .. "_" .. self.uuid
        
        -- 设置基础属性
        self:ApplyBaseAttributes()
        
        -- 绑定实体映射
        Entity.node2Entity[actor] = self
        
        gg.log("宠物Actor创建成功", self.petConfigName, self.actor.Name)
    else
        gg.log("宠物Actor创建失败", self.petConfigName)
    end
end

---应用基础属性
function Mpet:ApplyBaseAttributes()
    if not self.actor or not self.petConfig then
        return
    end
    
    -- 从MSystems/Pet获取计算后的属性
    local PetMgr = require(ServerStorage.MSystems.Pet.PetMgr) ---@type PetMgr
    local petInstance = PetMgr.GetPetInstance(self.ownerUin, self.slotIndex)
    
    if petInstance then
        -- 应用速度
        local speed = petInstance:GetFinalAttribute("速度")
        if speed > 0 then
            self.actor.Movespeed = speed
        end
        
        -- 应用生命值
        local health = petInstance:GetFinalAttribute("生命")
        if health > 0 then
            self:SetMaxHealth(health)
        end
        
        gg.log("宠物属性已应用", self.petConfigName, "速度", speed, "生命", health)
    else
        -- 使用默认配置值
        if self.petConfig.baseAttributes then
            self.actor.Movespeed = self.petConfig.baseAttributes["速度"] or 100
            self:SetMaxHealth(self.petConfig.baseAttributes["生命"] or 100)
        end
    end
end

---设置跟随目标
---@param target Entity 跟随目标
function Mpet:SetFollowTarget(target)
    self.followTarget = target
    self.isFollowing = true
    self:ChangeState("following")
    gg.log("宠物设置跟随目标", self.petConfigName, target and target.uuid or "nil")
end

---停止跟随
function Mpet:StopFollowing()
    self.followTarget = nil
    self.isFollowing = false
    self:ChangeState("idle")
    gg.log("宠物停止跟随", self.petConfigName)
end

---改变行为状态
---@param newState string 新状态
function Mpet:ChangeState(newState)
    if self.behaviorState ~= newState then
        local oldState = self.behaviorState
        self.behaviorState = newState
        self.lastStateTime = os.time()
        
        self:OnStateChanged(oldState, newState)
        gg.log("宠物状态切换", self.petConfigName, oldState, "->", newState)
    end
end

---状态切换回调
---@param oldState string 旧状态
---@param newState string 新状态
function Mpet:OnStateChanged(oldState, newState)
    if newState == "following" then
        self:StartFollowing()
    elseif newState == "idle" then
        self:StopMoving()
    elseif newState == "attacking" then
        self:StartAttacking()
    end
end

---开始跟随
function Mpet:StartFollowing()
    if not self.followTarget or not self.actor then
        return
    end
    
    -- 实现跟随逻辑
    local targetPos = self.followTarget.actor and self.followTarget.actor.Position or nil
    if targetPos then
        local myPos = self.actor.Position
        local distance = (targetPos - myPos).Magnitude
        
        -- 如果距离过远，则移动向目标
        if distance > 50 then -- 跟随距离阈值
            self.actor:MoveTo(targetPos)
        elseif distance < 20 then -- 太近了就停下
            self:StopMoving()
        end
    end
end

---停止移动
function Mpet:StopMoving()
    if self.actor then
        self.actor:StopMove()
    end
end

---开始攻击
function Mpet:StartAttacking()
    if not self.target or not self.actor then
        return
    end
    
    -- 实现攻击逻辑
    self:UseSkill("基础攻击")
end

---使用技能
---@param skillId string 技能ID
---@return boolean 是否成功使用
function Mpet:UseSkill(skillId)
    if not skillId or skillId == "" then
        return false
    end
    
    -- 检查冷却时间
    local currentTime = os.time()
    if self.skillCooldowns[skillId] and currentTime < self.skillCooldowns[skillId] then
        return false
    end
    
    -- 从MSystems/Pet检查是否学会技能
    local PetMgr = require(ServerStorage.MSystems.Pet.PetMgr) ---@type PetMgr
    local petInstance = PetMgr.GetPetInstance(self.ownerUin, self.slotIndex)
    
    if petInstance then
        local learnedSkills = petInstance.petData.learnedSkills or {}
        if skillId ~= "基础攻击" and not learnedSkills[skillId] then
            gg.log("宠物未学会技能", self.petConfigName, skillId)
            return false
        end
    end
    
    -- 执行技能效果
    self:ExecuteSkill(skillId)
    
    -- 设置冷却时间
    local skillConfig = ConfigLoader.GetConfig("PetSkill", skillId)
    if skillConfig and skillConfig.cooldown then
        self.skillCooldowns[skillId] = currentTime + skillConfig.cooldown
    end
    
    gg.log("宠物使用技能", self.petConfigName, skillId)
    return true
end

---执行技能效果
---@param skillId string 技能ID
function Mpet:ExecuteSkill(skillId)
    if not self.actor then
        return
    end
    
    local skillConfig = ConfigLoader.GetConfig("PetSkill", skillId)
    if not skillConfig then
        -- 如果没有配置，默认为基础攻击
        if skillId == "基础攻击" then
            self:ExecuteBasicAttack()
        end
        return
    end
    
    -- 根据技能类型执行不同效果
    if skillConfig.type == "attack" then
        self:ExecuteAttackSkill(skillConfig)
    elseif skillConfig.type == "buff" then
        self:ExecuteBuffSkill(skillConfig)
    elseif skillConfig.type == "heal" then
        self:ExecuteHealSkill(skillConfig)
    end
end

---执行基础攻击
function Mpet:ExecuteBasicAttack()
    if not self.target or not self.target.actor then
        return
    end
    
    -- 获取攻击力
    local PetMgr = require(ServerStorage.MSystems.Pet.PetMgr) ---@type PetMgr
    local petInstance = PetMgr.GetPetInstance(self.ownerUin, self.slotIndex)
    local attackPower = petInstance and petInstance:GetFinalAttribute("攻击") or 50
    
    -- 造成伤害
    if self.target.TakeDamage then
        self.target:TakeDamage(attackPower, self)
    end
    
    gg.log("宠物基础攻击", self.petConfigName, "伤害", attackPower, "目标", self.target.uuid)
end

---执行攻击技能
---@param skillConfig table 技能配置
function Mpet:ExecuteAttackSkill(skillConfig)
    if not self.target or not self.target.actor then
        return
    end
    
    -- 获取攻击力
    local PetMgr = require(ServerStorage.MSystems.Pet.PetMgr) ---@type PetMgr
    local petInstance = PetMgr.GetPetInstance(self.ownerUin, self.slotIndex)
    local attackPower = petInstance and petInstance:GetFinalAttribute("攻击") or 50
    
    -- 计算伤害
    local damage = attackPower * (skillConfig.damageMultiplier or 1.0)
    
    -- 造成伤害
    if self.target.TakeDamage then
        self.target:TakeDamage(damage, self)
    end
    
    gg.log("宠物攻击技能", self.petConfigName, skillConfig.name, "伤害", damage, "目标", self.target.uuid)
end

---执行增益技能
---@param skillConfig table 技能配置
function Mpet:ExecuteBuffSkill(skillConfig)
    -- 对跟随目标施加增益
    local target = self.followTarget or self
    if target and target.AddBuff then
        target:AddBuff(skillConfig.buffId, skillConfig.duration or 30)
    end
    
    gg.log("宠物增益技能", self.petConfigName, skillConfig.name)
end

---执行治疗技能
---@param skillConfig table 技能配置
function Mpet:ExecuteHealSkill(skillConfig)
    local target = self.followTarget or self
    if not target then
        return
    end
    
    local healAmount = skillConfig.healAmount or 50
    if target.Heal then
        target:Heal(healAmount, self)
    end
    
    gg.log("宠物治疗技能", self.petConfigName, skillConfig.name, "治疗量", healAmount)
end

---更新AI行为
---@param deltaTime number 时间间隔
function Mpet:UpdateAI(deltaTime)
    self.aiTimer = self.aiTimer + deltaTime
    
    -- AI更新频率控制：每0.5秒更新一次
    if self.aiTimer < 0.5 then
        return
    end
    
    self.aiTimer = 0
    
    -- 根据当前状态执行AI逻辑
    if self.behaviorState == "following" then
        self:UpdateFollowingAI()
    elseif self.behaviorState == "idle" then
        self:UpdateIdleAI()
    elseif self.behaviorState == "attacking" then
        self:UpdateAttackingAI()
    end
end

---更新跟随AI
function Mpet:UpdateFollowingAI()
    if not self.followTarget then
        self:ChangeState("idle")
        return
    end
    
    -- 检查跟随目标是否还存在
    if self.followTarget.isDead or self.followTarget.isDestroyed then
        self.followTarget = nil
        self:ChangeState("idle")
        return
    end
    
    -- 执行跟随逻辑
    self:StartFollowing()
    
    -- 检查是否需要攻击敌人
    local enemy = self:FindNearbyEnemy()
    if enemy then
        self.target = enemy
        self:ChangeState("attacking")
    end
end

---更新空闲AI
function Mpet:UpdateIdleAI()
    -- 检查是否有主人在附近
    local owner = self:FindOwnerEntity()
    if owner then
        self:SetFollowTarget(owner)
    end
end

---更新攻击AI
function Mpet:UpdateAttackingAI()
    if not self.target or self.target.isDead then
        self.target = nil
        if self.followTarget then
            self:ChangeState("following")
        else
            self:ChangeState("idle")
        end
        return
    end
    
    -- 检查攻击距离
    if self.actor and self.target.actor then
        local distance = (self.target.actor.Position - self.actor.Position).Magnitude
        if distance > 80 then -- 攻击范围
            -- 移动到攻击范围内
            self.actor:MoveTo(self.target.actor.Position)
        else
            -- 执行攻击
            self:UseSkill("基础攻击")
        end
    end
end

---寻找附近敌人
---@return Entity|nil 敌人实体
function Mpet:FindNearbyEnemy()
    if not self.actor then
        return nil
    end
    
    -- TODO: 实现敌人搜索逻辑
    -- 这里可以遍历附近的Entity，寻找敌对目标
    return nil
end

---寻找主人实体
---@return Entity|nil 主人实体
function Mpet:FindOwnerEntity()
    if self.ownerUin == 0 then
        return nil
    end
    
    -- 从玩家管理器获取主人实体
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(self.ownerUin)
    
    return player
end

---获取宠物数据实例
---@return Pet|nil Pet数据实例
function Mpet:GetPetDataInstance()
    local PetMgr = require(ServerStorage.MSystems.Pet.PetMgr) ---@type PetMgr
    return PetMgr.GetPetInstance(self.ownerUin, self.slotIndex)
end

---同步状态到MSystems数据层
function Mpet:SyncStatusToDataLayer()
    local petInstance = self:GetPetDataInstance()
    if not petInstance then
        return
    end
    
    -- 同步位置信息（如果需要）
    if self.actor then
        -- 可以将当前位置等信息同步到数据层
        -- petInstance.lastPosition = self.actor.Position
    end
    
    -- 同步其他状态信息
    -- petInstance.lastActiveTime = os.time()
end

---实体更新
---@param deltaTime number 时间间隔
function Mpet:Update(deltaTime)
    -- 调用父类更新
    Entity.Update(self, deltaTime)
    
    -- 宠物AI更新
    self:UpdateAI(deltaTime)
    
    -- 更新技能冷却
    self:UpdateSkillCooldowns()
    
    -- 定期同步状态
    if math.random() < 0.01 then -- 1%概率同步，避免频繁操作
        self:SyncStatusToDataLayer()
    end
end

---更新技能冷却
function Mpet:UpdateSkillCooldowns()
    local currentTime = os.time()
    for skillId, cooldownEnd in pairs(self.skillCooldowns) do
        if currentTime >= cooldownEnd then
            self.skillCooldowns[skillId] = nil
        end
    end
end

---获取当前状态信息
---@return table 状态信息
function Mpet:GetStatusInfo()
    return {
        uuid = self.uuid,
        petConfigName = self.petConfigName,
        ownerUin = self.ownerUin,
        slotIndex = self.slotIndex,
        behaviorState = self.behaviorState,
        isFollowing = self.isFollowing,
        hasTarget = self.target ~= nil,
        position = self.actor and self.actor.Position or nil,
        health = self:GetCurrentHealth(),
        maxHealth = self:GetMaxHealth()
    }
end

---销毁宠物实体
function Mpet:Destroy()
    -- 同步最终状态到数据层
    self:SyncStatusToDataLayer()
    
    -- 停止AI
    self.aiTimer = 0
    self.followTarget = nil
    self.target = nil
    self.isFollowing = false
    
    -- 清理技能冷却
    self.skillCooldowns = {}
    
    -- 从映射表移除
    if self.actor then
        Entity.node2Entity[self.actor] = nil
    end
    
    -- 调用父类销毁
    Entity.Destroy(self)
    
    gg.log("Mpet实体销毁", self.petConfigName, "主人", self.ownerUin, "UUID", self.uuid)
end

return Mpet