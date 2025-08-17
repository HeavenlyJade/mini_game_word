local MainStorage   = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg            = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClassMgr      = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local common_const  = require(MainStorage.Code.Common.GameConfig.Mconst) ---@type common_const
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

local cloudDataMgr    =     require(ServerStorage.CloundDataMgr.MCloudDataMgr) ---@type MCloudDataMgr
local Entity             = require(ServerStorage.EntityTypes.Entity) ---@type Entity

local VariableSystem = require(MainStorage.Code.MServer.Systems.VariableSystem) ---@type VariableSystem


---@class MPlayer : Entity    --玩家类  (单个玩家) (管理玩家状态)
---@field bag Bag 背包管理器实例
---@field dict_btn_skill table 技能按钮映射
---@field auto_attack number 自动攻击技能ID
---@field auto_attack_tick number 攻击间隔
---@field auto_wait_tick number 等待tick
---@field player_net_stat number 玩家网络状态
---@field loginTime number 登录时间
---@field variableSystem VariableSystem 变量系统实例
local _MPlayer = ClassMgr.Class('MPlayer', Entity)

function _MPlayer:OnInit(info_)
    Entity.OnInit(self, info_)    --父类初始化

    -- 玩家特有属性
    self.uin = info_.uin
    self.name = info_.nickname or info_.name or ""
    self.isPlayer = true
    ---@type VariableSystem
    self.variableSystem = VariableSystem.New("玩家", info_.variables or {})
    self.currentScene = info_.currentScene or "init_map"

    -- 技能相关
    self.dict_btn_skill = nil -- 技能按钮映射
    self.auto_attack = 0 -- 自动攻击技能id
    self.auto_attack_tick = 10 -- 攻击间隔
    self.auto_wait_tick = 0 -- 等待tick

    -- 网络状态
    self.player_net_stat  = common_const.PLAYER_NET_STAT.INITING -- 网络状态
    self.loginTime = os.time() -- 登录时间
end


--直接获得游戏中的actor的位置
function _MPlayer:getPosition()
    return self.actor and self.actor.Position or Vector3.New(0, 0, 0)
end

--改变网络状态
function _MPlayer:setPlayerNetStat(player_net_stat_)
    --gg.log('setPlayerNetStat:', self.uin, player_net_stat_)
    self.player_net_stat = player_net_stat_
end

-- 技能系统相关 ------------------------------------------------------

--通知客户端玩家的技能框和技能id
function _MPlayer:syncSkillData()
    if self.dict_btn_skill then
        gg.network_channel:fireClient(self.uin, {
            cmd = 'cmd_sync_player_skill',
            uin = self.uin,
            skill = self.dict_btn_skill
        })
    end
end

-- 【新增】同步玩家等级和经验到客户端
function _MPlayer:syncLevelExpToClient()
    local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
    gg.network_channel:fireClient(self.uin, {
        cmd = EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_LEVEL_EXP,
        level = self.level or 1,
        exp = self.exp or 0,
    })
end

-- 兼容性方法：同步给客户端当前目标的资料
---@param target_ Entity
---@param with_name_ boolean
function _MPlayer:syncTargetInfo(target_, with_name_)
    local info_ = {
        cmd = 'cmd_sync_target_info',
        show = 1, -- 0=不显示， 1=显示
        hp = target_.health,
        hp_max = target_.maxHealth
    }

    if with_name_ then
        info_.name = target_.name or ""
    end

    gg.network_channel:fireClient(self.uin, info_)
end

-- 显示伤害飘字，闪避，升级等特效
function _MPlayer:showDamage(number_, eff_, victim)
    if not victim then return end

    local victimPosition = victim:GetCenterPosition()
    local position = victimPosition + (self:GetCenterPosition() - victimPosition):Normalize() * 2 * victim:GetSize().x

    gg.network_channel:fireClient(self.uin, {
        cmd = "ShowDamage",
        amount = number_,
        isCrit = eff_.cr == 1,
        position = {
            x = position.x,
            y = position.y + victim:GetSize().y,
            z = position.z
        },
        percent = math.min(1, number_ / 100) -- 简化伤害百分比计算
    })
end

-- 生命周期管理 --------------------------------------------------------

--玩家离开游戏 (立即存盘)
function _MPlayer:leaveGame()
    -- 保存各种数据
    if self.variableSystem then
        self.variables = self.variableSystem.variables
        -- --gg.log("同步VariableSystem数据到variables", self.uin)
    end
    cloudDataMgr.SavePlayerData(self.uin, true)
    -- cloudDataMgr.SaveGameTaskData(self)
    -- cloudDataMgr.SaveSkillConfig(self)

end

-- 重写死亡处理
function _MPlayer:Die()
    if self.isDead then return end

    -- 玩家死亡特殊处理
    self.isDead = true

    -- 停止自动攻击
    self.auto_attack = 0
    self.auto_wait_tick = 0

    -- 清除施法状态
    self.stat_flags = {}

    -- 停止导航
    if self.actor then
        self.actor:StopNavigate()
    end

    local deathTime = 0
    if self.modelPlayer then
        deathTime = self.modelPlayer:OnDead()
    end

    -- 发布玩家死亡事件
    local evt = {
        entity = self,
        player = self,
        deathTime = deathTime
    }
    ServerEventManager.Publish("PlayerDeadEvent", evt)
    ServerEventManager.Publish("EntityDeadEvent", evt)
end

-- 【新增】重写等级设置方法，自动同步到客户端
function _MPlayer:SetLevel(level)
    if self.level ~= level then
        self.level = level
        -- 等级变化时自动同步到客户端
        self:syncLevelExpToClient()
    end
end

-- 【新增】重写经验设置方法，自动同步到客户端
function _MPlayer:SetExp(exp)
    if self.exp ~= exp then
        self.exp = exp
        -- 经验变化时自动同步到客户端
        self:syncLevelExpToClient()
    end
end

-- 【新增】添加经验值，自动同步到客户端
function _MPlayer:AddExp(expAmount)
    if expAmount and expAmount > 0 then
        self.exp = (self.exp or 0) + expAmount
        -- 经验变化时自动同步到客户端
        self:syncLevelExpToClient()
        
        -- 【新增】检查是否升级
        self:CheckLevelUp()
    end
end

-- 【新增】检查并处理等级升级
function _MPlayer:CheckLevelUp()
    local currentLevel = self.level or 1
    local currentExp = self.exp or 0
    
    -- 计算升级所需经验（这里使用简单的公式，可以根据实际需求调整）
    local requiredExp = currentLevel * 100 -- 每级需要 level * 100 经验
    
    if currentExp >= requiredExp then
        -- 升级
        local newLevel = currentLevel + 1
        self:SetLevel(newLevel)
        
        -- 扣除升级消耗的经验
        self.exp = currentExp - requiredExp
        
        -- 升级后的额外处理
        self:OnLevelUp(newLevel)
        
        -- 再次同步（因为等级和经验都变化了）
        self:syncLevelExpToClient()
    end
end

-- 【新增】等级升级后的回调方法
function _MPlayer:OnLevelUp(newLevel)
    -- 可以在这里添加升级后的逻辑，比如：
    -- - 增加属性点
    -- - 解锁新功能
    -- - 播放升级特效
    -- - 发送升级通知等
    
    -- 发送升级通知到客户端
    gg.network_channel:fireClient(self.uin, {
        cmd = "PlayerLevelUp",
        newLevel = newLevel,
        message = string.format("恭喜升级到 %d 级！", newLevel)
    })
end

-- tick刷新
function _MPlayer:updatePlayer()
    -- 调用父类update
    self:update()

    -- 自动攻击逻辑
    if self.auto_attack > 0 then
        self.auto_wait_tick = self.auto_wait_tick - 1
        if self.auto_wait_tick <= 0 then
            if not (self.stat_flags and self.stat_flags.skill_uuid) then
                -- 不在施法中，可以进行自动攻击
                -- 这里应该调用SkillMgr的自动攻击方法
                -- skillMgr.tryAutoAttack(self, self.auto_attack)
                self.auto_wait_tick = self.auto_attack_tick -- 重置攻击间隔
            end
        end
    end
end

function _MPlayer:SendEvent(eventName, data, callback)
    if not data then
        data = {}
    end
    if not eventName then
        print("发送事件时未传入事件: ".. debug.traceback())
    end
    data.cmd = eventName
    ServerEventManager.SendToClient(self.uin, eventName, data, callback)
end

function _MPlayer:SendHoverText( text, ... )
    if ... then
        text = string.format(text, ...)
    end
    self:SendEvent("SendHoverText", { txt=text })
end


-- 其他兼容性方法 --------------------------------------------------------

-- 获得经验值
function _MPlayer:getMonExp()
    return 10 * self.level -- 1级10经验  10级100经验
end

-- 检查死亡状态
function _MPlayer:checkDead()
    -- 进入战斗状态
    self.combatTime = 10

    -- 如果血量为0，触发死亡
    if self.health <= 0 and not self.isDead then
        self:Die()
    end
end

-- 重置战斗数据
function _MPlayer:resetBattleData(resethpmp_)
    -- 调用父类方法
    Entity.resetBattleData(self, resethpmp_)

    -- 玩家特有的重置逻辑
    if resethpmp_ then
        self:SetHealth(self.maxHealth)
        self.mana = self.maxMana
    end

    -- 清除战斗状态
    self.combatTime = 0
    self.auto_wait_tick = 0
end

--- 获取用于消耗计算的统一数据结构
function _MPlayer:GetConsumableData()
    local variableData = self.variableSystem:GetAllVariables()
    local playerAttribute = {
        level = self.level or 0,
        health = self.health or 0,
        maxHealth = self.maxHealth or 0,
    }
    return {
        variableData = variableData,
        playerAttribute = playerAttribute
    }
end




return _MPlayer
