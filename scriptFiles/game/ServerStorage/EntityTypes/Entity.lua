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
    self.uuid = self:GenerateUUID()
    self.uin = info_.uin
    self.scene = nil ---@type SceneControllerHandler
    self.level = info_.level or 1
    self.exp = info_.exp or 0
    self.type = info_.npc_type
    self.spawnPos = info_.position
    self.name = info_.name or ""
    self.isDestroyed = false
    self.isEntity = true
    self.isPlayer = false
    -- 属性系统
    self.stats = {} ---@type table<string, table<string, number>> 属性存储 [source][statName] = value
    self._attackCache = 0 -- 攻击力缓存
    
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
    self:SetAnimationController(stateMachine)
end

-- 设置动画控制器
function _M:SetAnimationController(name)
    if self.modelPlayer and self.modelPlayer.name == name then
        return
    end
    if self.modelPlayer then
        self.modelPlayer.walkingTask:Disconnect()
        self.modelPlayer.standingTaskId:Disconnect()
        self.modelPlayer = nil
    end
    if name then
        local AnimationConfig = require(MainStorage.Code.Common.config.AnimationConfig) ---@type AnimationConfig
        local ModelPlayer = require(MainStorage.Code.MServer.graphic.ModelPlayer) ---@type ModelPlayer
        local animator = self.actor.Animator
        local animationConfig = AnimationConfig.Get(name)
        if animator and animationConfig then
            self.modelPlayer = ModelPlayer.New(name, animator, animationConfig)
            self.modelPlayer.walkingTask = self.actor.Walking:Connect(function(isWalking)
                if isWalking then
                    self.modelPlayer:OnWalk()
                end
            end)
            self.modelPlayer.standingTaskId = self.actor.Standing:Connect(function(isStanding)
                if isStanding then
                    self.modelPlayer:OnStand()
                end
            end)
        end
    end
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

    if actor_:IsA("Actor") then
        actor_.PhysXRoleType = Enum.PhysicsRoleType.BOX
        actor_.IgnoreStreamSync = false
    end
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

-- 玩家改变场景
---@param new_scene string|Scene
function _M:ChangeScene(new_scene)
    if type(new_scene) == "string" then
        new_scene = gg.server_scene_list[new_scene]
    end
    if self.scene and self.scene == new_scene then
        return
    end

    -- 离开旧场景
    if self.scene then
        self.scene.uuid2Entity[self.uuid] = nil
    end

    -- 进入新场景
    self.scene = new_scene
    if self.scene then
        self.scene.uuid2Entity[self.uuid] = self
    end
end

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

--- 添加属性
---@param statName string 属性名
---@param amount number 属性值
---@param source string|nil 来源，默认为"BASE"
---@param refresh boolean|nil 是否刷新，默认为true
function _M:AddStat(statName, amount, source, refresh)
    if not amount then
        return
    end
    source = source or "BASE"
    refresh = refresh == nil and true or refresh

    if not self.stats[source] then
        self.stats[source] = {}
    end

    if not self.stats[source][statName] then
        self.stats[source][statName] = 0
    end

    self.stats[source][statName] = self.stats[source][statName] + amount

    if self.actor and refresh and TRIGGER_STAT_TYPES[statName] then
        TRIGGER_STAT_TYPES[statName](self, self:GetStat(statName))
    end
end

--- 设置属性
---@param statName string 属性名
---@param amount number 属性值
---@param source string|nil 来源，默认为"BASE"
---@param refresh boolean|nil 是否刷新，默认为true
function _M:SetStat(statName, amount, source, refresh)
    source = source or "BASE"
    refresh = refresh == nil and true or refresh

    if not self.stats[source] then
        self.stats[source] = {}
    end

    self.stats[source][statName] = amount

    if self.actor and refresh and TRIGGER_STAT_TYPES[statName] then
        TRIGGER_STAT_TYPES[statName](self, self:GetStat(statName))
    end
end

--- 获取属性值
---@param statName string 属性名
---@param sources string[]|nil 来源列表，nil表示所有来源
---@return number 属性值
function _M:GetStat(statName, sources)
    local amount = 0

    -- 遍历所有来源的属性
    for source, statMap in pairs(self.stats) do
        if not sources or self:TableContains(sources, source) then
            if statMap[statName] then
                amount = amount + statMap[statName]
            end
        end
    end

    return amount
end

--- 重置属性
---@param source string 来源ID
function _M:ResetStats(source)
    if self.stats[source] then
        self.stats[source] = nil
    end
end

--- 刷新属性（触发实体属性更新）
function _M:RefreshStats()
    if not self.actor then return end

    -- 重置装备属性
    self:ResetStats("EQUIP")

    -- 遍历所有需要触发的属性类型并刷新
    for statName, triggerFunc in pairs(TRIGGER_STAT_TYPES) do
        local value = self:GetStat(statName)
        triggerFunc(self, value)
    end
    
    -- 更新攻击缓存
    self._attackCache = self:GetStat("攻击")
end

--- 检查表中是否包含值
---@param tbl table 表
---@param value any 值
---@return boolean
function _M:TableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

return _M
