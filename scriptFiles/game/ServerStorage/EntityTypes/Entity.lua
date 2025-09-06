local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
-- local common_const = require(MainStorage.Code.Common.GameConfig.MConst) ---@type common_const
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local VectorUtils = require(MainStorage.Code.Untils.VectorUtils) ---@type VectorUtils
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local ServerScheduler = require(MainStorage.Code.MServer.Scheduler.ServerScheduler) ---@type ServerScheduler
local serverDataMgr     = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local VariableSystem = require(MainStorage.Code.MServer.Systems.VariableSystem)


---@class Entity :Class  轻量级实体容器，管理actor实例和基本属性
---@field info any
---@field uuid string
---@field uin  number
---@field tick number
---@field wait_tick number
---@field stat_flags any
---@field actor Actor
---@field target Entity
---@field isDead boolean 是否已死亡
---@field isDestroyed boolean 是否已销毁
---@field New fun( info_:table ):Entity
local _M = ClassMgr.Class("Entity") -- 父类 (子类： Player, Monster )
_M.node2Entity = {}

--- 生成唯一ID
function _M:GenerateUUID()
    serverDataMgr.uuid_start = serverDataMgr.uuid_start + 1
    -- 结合时间和uin确保唯一性
    return "entity_" .. serverDataMgr.uuid_start .. "_" .. (self.uin or "none")
end

-- 属性触发类型映射
local TRIGGER_STAT_TYPES = {
    ["生命"] = function(entity, value)
        if entity.SetMaxHealth then
            entity:SetMaxHealth(value)
        end
    end,
    ["速度"] = function(entity, value)
        gg.log("速度", value)
        if entity.actor then
            entity.actor.Movespeed = value
        end
    end,
    ["攻击"] = function(entity, value)
        -- 攻击力变化时的逻辑
        if entity._attackCache ~= nil then
            entity._attackCache = value
        end
    end,
    ["防御"] = function(entity, value)
        -- 防御力变化时的逻辑
    end,
    ["魔法"] = function(entity, value)
        -- 魔法力变化时的逻辑
        if entity.SetMaxMana then
            entity:SetMaxMana(value)
        end
    end
}

-- 初始化实体
function _M:OnInit(info_)
    self.uuid = info_.uin or self:GenerateUUID()
    self.uin = info_.uin
    self.scene = nil 
    self.level = info_.level or 1
    self.exp = info_.exp or 0
    self.type = info_.npc_type
    self.spawnPos = info_.position
    self.name = info_.name or ""
    self.isDestroyed = false
    self.isEntity = true
    self.isPlayer = false
    -- 简化属性系统 - 去掉来源机制
    self.stats = {} ---@type table<string, number> 属性直接存储 statName = value
    self._attackCache = 0
    self.initialStats = {} ---@type table<string, number>
    
    -- Actor相关
    self.actor = nil -- game_actor
    self.target = nil -- 当前目标 Entity
    
    -- 生命状态
    self.isDead = false
    self.combatTime = 0 -- 战斗时间计数器
    
    -- 基本属性
    self.health = 0
    self.maxHealth = 100
    self.mana = 0
    self.maxMana = 100
    
    -- UI相关
    self.bb_title = nil -- 头顶名字和等级 billboard
    
    -- tick系统
    self.tick = 0 -- 总tick值(递增)
    self.wait_tick = 0 -- 等待状态tick值(递减)
    self.last_anim = '' -- 最后一个播放的动作
    
    -- 状态标志
    self.stat_flags = {} -- 状态标志（施法等）
    
    -- -- 模型播放器
    -- self.modelPlayer = nil  ---@type ModelPlayer
end



-- 事件订阅
function _M:SubscribeEvent(eventType, listener, priority)
    ServerEventManager.Subscribe(eventType, listener, priority, self.uuid)
end

-- Actor和模型管理 --------------------------------------------------------

-- 设置模型
function _M:SetModel(model, animator, stateMachine)
    if not self.actor then return end
    self.actor.ModelId = model
    self.actor["Animator"].ControllerAsset = animator
end



-- 位置和方向管理 --------------------------------------------------------

function _M:SetPosition(position)
    if self.actor then
        self.actor.LocalPosition = position
    end
end

function _M:GetPosition()
    return self.actor and self.actor.LocalPosition or Vector3.New(0, 0, 0)
end

function _M:GetCenterPosition()
    return VectorUtils.Vec.Add3(self:GetPosition(), 0, self:GetSize().y/2, 0)
end

function _M:GetDirection()
    return self.actor and self.actor.ForwardDir or Vector3.New(0, 0, 1)
end

function _M:GetSize()
    if not self.actor then
        return Vector3.New(1, 1, 1)
    end
    local size = self.actor.Size
    local scale = self.actor.LocalScale
    return Vector3.New(size.x * scale.x, size.y * scale.y, size.z * scale.z)
end

-- 距离判断
function _M:IsNear(loc, dist)
    return VectorUtils.Vec.DistanceSq3(loc, self:GetPosition()) < dist ^ 2
end

-- 生命周期管理 --------------------------------------------------------

-- 设置游戏场景中使用的actor实例
function _M:setGameActor(actor_)
    self.actor = actor_
    _M.node2Entity[actor_] = self
end


-- 开始处理死亡逻辑
function _M:Die()
    if self.isDead then return end
    self.isDead = true

    -- 停止导航
    if self.actor then
        self.actor:StopNavigate()
    end
    
    local deathTime = 0
    if self.modelPlayer then
        deathTime = self.modelPlayer:OnDead()
    end
    
    -- 发布死亡事件
    local evt = {
        entity = self,
        deathTime = deathTime
    }
    ServerEventManager.Publish("EntityDeadEvent", evt)
    
    -- 非玩家实体延迟销毁
    if not self.isPlayer then
        if evt.deathTime > 0 then
            ServerScheduler.add(function()
                self:DestroyObject()
            end, evt.deathTime, nil, "destroy_" .. self.uuid)
        else
            self:DestroyObject()
        end
    end
end

-- 销毁对象
function _M:DestroyObject()
    if not self.isDead then
        self:Die()
    end
    self.isDestroyed = true
    if self.actor then
        _M.node2Entity[self.actor] = nil
        self.actor:Destroy()
        self.actor = nil
    end
    ServerEventManager.UnsubscribeByKey(self.uuid)
end

-- 是否可被攻击
function _M:CanBeTargeted()
    return not self.isDead and not self.isDestroyed
end

-- 基本属性管理 --------------------------------------------------------

function _M:SetLevel(level)
    self.level = level
end

-- 设置最大生命值
function _M:SetMaxHealth(amount)
    local percentage
    if self.maxHealth == 0 then
        percentage = 1
    else
        percentage = math.min(1, self.health / self.maxHealth)
    end

    self.maxHealth = amount
    self.health = self.maxHealth * percentage
    if self.actor then
        self.actor.MaxHealth = self.maxHealth
        self.actor.Health = self.health
    end
end

-- 设置当前生命值
function _M:SetHealth(health)
    self.health = math.max(0, math.min(self.maxHealth, health))
    if self.actor then
        self.actor.Health = self.health
    end
    
    -- 检查死亡
    if self.health <= 0 and not self.isDead then
        self:Die()
    end
end

-- 受到伤害
function _M:Hurt(amount, damager, isCrit)
    if self.isDead then
        return
    end

    -- 扣除生命值
    self:SetHealth(self.health - amount)
    
    -- 进入战斗状态
    self.combatTime = 10
    
    -- 显示受伤描边效果
    if self.actor then
        self.actor.OutlineActive = true
        ServerScheduler.add(function()
            if self.actor then
                self.actor.OutlineActive = false
            end
        end, 0.5, nil, "outline_" .. self.uuid)
    end
end

-- 治疗
function _M:Heal(health, source)
    self:SetHealth(self.health + health)
end

-- 增加经验值
function _M:addExp(exp_)
    self.exp = self.exp + exp_
    -- 经验升级逻辑可以在对应的管理器中处理
end

-- 场景管理 --------------------------------------------------------



-- UI相关 --------------------------------------------------------

-- 创建头顶标题
function _M:createTitle(nameOverride, scale)
    scale = scale or 1
    nameOverride = nameOverride or self.name
    if not self.bb_title then
        local name_level_billboard = SandboxNode.new('UIBillboard', self.actor)
        name_level_billboard.Name = 'name_level'
        name_level_billboard.Billboard = true
        name_level_billboard.CanCollide = false

        name_level_billboard.LocalPosition = Vector3.New(0, self.actor.Size.y + 100 / self.actor.LocalScale.y, 0)
        name_level_billboard.ResolutionLevel = Enum.ResolutionLevel.R4X
        name_level_billboard.LocalScale = Vector3.New(scale, 0.6 * scale, scale)

        local number_level = gg.createTextLabel(name_level_billboard, nameOverride)
        number_level.ShadowEnable = true
        number_level.ShadowOffset = Vector2.New(3, 3)
        number_level.FontSize = number_level.FontSize / self.actor.LocalScale.y

        if (self.level or 1) > 50 then
            number_level.TitleColor = ColorQuad.New(255, 0, 0, 255)
            number_level.ShadowColor = ColorQuad.New(0, 0, 0, 255)
        else
            number_level.TitleColor = ColorQuad.New(255, 255, 0, 255)
            number_level.ShadowColor = ColorQuad.New(0, 0, 0, 255)
        end

        self.bb_title = number_level
        self:createHpBar(name_level_billboard)
    else
        self.bb_title.Title = nameOverride
    end
end

-- 血条（子类实现）
function _M:createHpBar(root_)
end

-- 显示提示文字
function _M:showTips(msg_)
    local damage_billboard = SandboxNode.new('UIBillboard', self.actor)
    damage_billboard.Name = 'tips'
    damage_billboard.Billboard = true
    damage_billboard.CanCollide = false
    damage_billboard.ResolutionLevel = Enum.ResolutionLevel.R4X

    if self.isPlayer then
        damage_billboard.Size2d = Vector2.New(3, 3)
        damage_billboard.LocalPosition = Vector3.New(0, 258, 0)
    else
        damage_billboard.Size2d = Vector2.New(8, 8)
        damage_billboard.LocalPosition = Vector3.New(0, 330, 0)
    end
    local txt_ = gg.createTextLabel(damage_billboard, msg_)
    txt_.RenderIndex = 101
    
    local function long_call(damage_billboard_)
        wait(0.5)
        damage_billboard_:Destroy()
    end
    coroutine.work(long_call, damage_billboard)
end

-- 装备武器
function _M:equipWeapon(model_src_)
    if self.actor and self.actor.Hand then
        local model = SandboxNode.new('Model', self.actor.Hand)
        model.Name = 'weapon'
        model.EnablePhysics = false
        model.CanCollide = false
        model.CanTouch = false
        model.ModelId = model_src_
        model.LocalScale = Vector3.New(2, 2, 2)
        self.model_weapon = model
    end
end

-- 展示复活特效
function _M:showReviveEffect(pos_)
    local expl = SandboxNode.new('DefaultEffect', self.actor)
    expl.AssetID = 'sandboxSysId://particles/item_137_red.ent'
    expl.Position = Vector3.New(pos_.x, pos_.y, pos_.z)
    expl.LocalScale = Vector3.New(3, 3, 3)
    ServerScheduler.add(function()
        expl:Destroy()
    end, 1.5)
end

-- 玩家跳跃
function _M:doJump()
    if self.actor then
        self.actor:Jump(true)
    end
end

-- 兼容方法 --------------------------------------------------------

-- 获取调试信息
function _M:GetToStringParams()
    return {
        name = self.name
    }
end

-- 重置战斗数据（保留接口，具体逻辑在管理器中处理）
function _M:resetBattleData(resethpmp_)
    -- 由各个管理器处理具体逻辑
end

-- 设置技能施法时间（保留接口，具体逻辑在SkillMgr中处理）
function _M:setSkillCastTime(skill_uuid_, cast_time_)
    local stat_flags_ = self.stat_flags
    if stat_flags_.skill_uuid then
        self:showTips('正在施法中')
        return 1
    else
        stat_flags_.skill_uuid = skill_uuid_
        stat_flags_.cast_time = cast_time_
        stat_flags_.cast_time_max = cast_time_
        stat_flags_.cast_pos = self.actor and self.actor.Position or Vector3.New(0,0,0)

        if self.isPlayer then
            gg.network_channel:fireClient(self.uin, {
                cmd = 'cmd_player_spell',
                v = stat_flags_.cast_time,
                max = stat_flags_.cast_time_max
            })
        end
        return 0
    end
end

-- tick刷新
function _M:update()
    self.tick = self.tick + 1
    if self.combatTime > 0 then
        self.combatTime = self.combatTime - 1
    end
end

-- 属性管理系统 --------------------------------------------------------

--- 设置属性
---@param statName string 属性名
---@param amount number 属性值
---@param refresh boolean|nil 是否刷新，默认为true
function _M:SetStat(statName, amount, refresh)
    refresh = refresh == nil and true or refresh
    
    self.stats[statName] = amount

    if self.actor and refresh and TRIGGER_STAT_TYPES[statName] then
        TRIGGER_STAT_TYPES[statName](self, amount)
    end
end

--- 获取属性值
---@param statName string 属性名
---@return number 属性值
function _M:GetStat(statName)
    return self.stats[statName] or 0
end

--- 添加属性
---@param statName string 属性名
---@param amount number 属性值
---@param refresh boolean|nil 是否刷新，默认为true
function _M:AddStat(statName, amount, refresh)
    if not amount then return end
    
    local current = self:GetStat(statName)
    self:SetStat(statName, current + amount, refresh)
end

--- 重置属性
---@param statName string|nil 属性名，nil表示重置所有
function _M:ResetStats(statName)
    if statName then
        self:SetStat(statName, 0, true)
    else
        for name in pairs(self.stats) do
            self.stats[name] = 0
        end
        self:RefreshStats()
    end
end

--- 刷新属性（触发实体属性更新）
function _M:RefreshStats()
    for statName, value in pairs(self.stats) do
        if self.actor and TRIGGER_STAT_TYPES[statName] then
            TRIGGER_STAT_TYPES[statName](self, value)
        end
    end
    
    self._attackCache = self:GetStat("攻击")
end

-- 初始属性管理 --------------------------------------------------------

--- 设置属性的初始值（仅在第一次设置时生效）
---@param statName string 属性名
---@param value number 初始值
function _M:SetInitialStat(statName, value)
    if self.initialStats[statName] == nil then
        self.initialStats[statName] = value
        --gg.log(string.format("设置属性 '%s' 的初始值为: %s", statName, tostring(value)))
    end
end

--- 获取属性的初始值
---@param statName string 属性名
---@return number 初始值，如果没有设置则返回0
function _M:GetInitialStat(statName)
    return self.initialStats[statName] or 0
end

--- 恢复指定属性到初始值
---@param statName string 属性名
function _M:RestoreStatToInitial(statName)
    local initialValue = self:GetInitialStat(statName)
    self:SetStat(statName, initialValue, true)
    gg.log(string.format("属性 '%s' 已恢复到初始值: %s", statName, tostring(initialValue)))
    return initialValue
end

--- 恢复所有属性到初始值
---@return number 恢复的属性数量
function _M:RestoreAllStatsToInitial()
    local count = 0
    for statName, initialValue in pairs(self.initialStats) do
        self:SetStat(statName, initialValue, false)
        count = count + 1
    end
    
    if count > 0 then
        self:RefreshStats()
        gg.log(string.format("已恢复 %d 个属性到初始值", count))
    end
    
    return count
end

--- 批量设置初始属性
---@param stats table<string, number> 属性名到初始值的映射
function _M:SetInitialStats(stats)
    if type(stats) == "table" then
        for statName, value in pairs(stats) do
            self:SetInitialStat(statName, value)
        end
        --gg.log(string.format("批量设置了 %d 个属性的初始值", table.getn(stats)))
    end
end

--- 获取所有当前属性
---@return table<string, number>
function _M:GetAllStats()
    local result = {}
    for statName, value in pairs(self.stats) do
        result[statName] = value
    end
    return result
end

--- 获取所有初始属性
---@return table<string, number> 属性名到初始值的映射
function _M:GetAllInitialStats()
    local result = {}
    for statName, value in pairs(self.initialStats) do
        result[statName] = value
    end
    return result
end


function _M:SendEvent(eventName, data, callback)
    if not data then
        data = {}
    end
    data.cmd = eventName
    ServerEventManager.SendToClient(self.uin, data, callback)
end

return _M
