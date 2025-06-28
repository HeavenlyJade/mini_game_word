local MainStorage   = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local cloudDataMgr = require(ServerStorage.MCloudDataMgr) ---@type MCloudDataMgr


local gg            = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg
local ClassMgr  = require(MainStorage.Code.Common.Untils.ClassMgr) ---@type ClassMgr
local common_const  = require(MainStorage.Code.Common.GameConfig.MConst) ---@type common_const
local Entity      = require(MainStorage.Code.MServer.EntityTypes.Entity) ---@type Entity
local ServerEventManager      = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

local ServerScheduler = require(MainStorage.Code.MServer.Scheduler.ServerScheduler) ---@type ServerScheduler



local MainStorage   = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local cloudDataMgr = require(ServerStorage.MCloudDataMgr) ---@type MCloudDataMgr
local gg            = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg
local ClassMgr      = require(MainStorage.Code.Common.Untils.ClassMgr) ---@type ClassMgr
local common_const  = require(MainStorage.Code.Common.GameConfig.MConst) ---@type common_const
local Entity        = require(MainStorage.Code.MServer.EntityTypes.Entity) ---@type Entity

---@class MPlayer : Entity    --玩家类  (单个玩家) (管理玩家状态)
---@field dict_btn_skill table
local _MPlayer = ClassMgr.Class('Player', Entity)

function _MPlayer:OnInit(info_)
    Entity.OnInit(self, info_)    --父类初始化
    
    self.uin = info_.uin
    self.name = info_.nickname
    self.isPlayer = true

    self.auto_attack      = 0          --自动攻击技能id
    self.auto_attack_tick = 10         --攻击间隔
    self.auto_wait_tick   = 0
    self.player_net_stat = common_const.PLAYER_NET_STAT.INITING         --玩家网络状态

    self.loginTime = os.time()
end

--直接获得游戏中的actor的位置
function _MPlayer:getPosition()
    return self.actor.Position
end

--改变状态
function _MPlayer:setPlayerNetStat(player_net_stat_)
    gg.log('setPlayerNetStat:', self.uin, player_net_stat_)
    self.player_net_stat = player_net_stat_
end

--初始化技能列表（default）
function _MPlayer:initSkillData()
    --先读取云数据
    self:syncSkillData()
end


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



--玩家离开游戏 (立即存盘)
function _MPlayer:leaveGame()
    cloudDataMgr.SavePlayerData(self.uin, true)
    cloudDataMgr.SaveGameTaskData(self)
    cloudDataMgr.SaveSkillConfig(self)
    -- cloudDataMgr.savePlayerData(self.uin, true)
end

--tick刷新
function _MPlayer:updatePlayer()
    self:update()
    if self.auto_attack > 0 then
        self.auto_wait_tick = self.auto_wait_tick - 1
        if self.auto_wait_tick > 0 then
            --go on
        else
            if self.stat_flags and self.stat_flags.skill_uuid then
                --正在施法中
            else
                -- skillMgr.tryAutoAttack(self, self.auto_attack)     --自动攻击
                self.auto_wait_tick = self.auto_attack_tick          --每N帧攻击一次
            end
        end
    end
end

return _MPlayer
