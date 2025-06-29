--- V109 miniw-haima
--- 玩家初始化模块

local game     = game
local pairs    = pairs
local ipairs   = ipairs
local Vector3  = Vector3
local Enum = Enum

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg                = require(MainStorage.Code.Untils.MGlobal)    ---@type gg
local ClassMgr          = require(MainStorage.Code.Untils.ClassMgr)    ---@type ClassMgr
local common_const      = require(MainStorage.Code.Common.GameConfig.MConst)     ---@type common_const
local Scene      = require(MainStorage.Code.MServer.Scene)         ---@type Scene
local Player       = require(MainStorage.Code.MServer.EntityTypes.MPlayer)

local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager

local cloudDataMgr  = require(ServerStorage.MCloudDataMgr)    ---@type MCloudDataMgr
local serverDataMgr     = require(ServerStorage.MServerDataManager) ---@type MServerDataManager


---@class MServerInitPlayer
local MServerInitPlayer = {}

-- 私有变量
local initFinished = false
local waitingPlayers = {} -- 存储等待初始化的玩家

-- 设置初始化完成状态
function MServerInitPlayer.setInitFinished(finished)
    initFinished = finished
    
    -- 如果初始化完成，处理等待的玩家
    if finished then
        for _, player in ipairs(waitingPlayers) do
            MServerInitPlayer.player_enter_game(player)
        end
        waitingPlayers = {} -- 清空等待列表
    end
end

-- 注册玩家进游戏和出游戏消息
function MServerInitPlayer.register_player_in_out()
    local players = game:GetService("Players")

    players.PlayerAdded:Connect(function(player)
        gg.log('====PlayerAdded', player.UserId)
        if initFinished then
            MServerInitPlayer.player_enter_game(player)
        else
            table.insert(waitingPlayers, player)
            gg.log('====PlayerAdded to waiting list', player.UserId)
        end
    end)

    players.PlayerRemoving:Connect(function(player)
        gg.log('====PlayerRemoving', player.UserId)
        -- 如果玩家在等待列表中，需要移除
        for i, waitingPlayer in ipairs(waitingPlayers) do
            if waitingPlayer.UserId == player.UserId then
                table.remove(waitingPlayers, i)
                break
            end
        end
        MServerInitPlayer.player_leave_game(player)
    end)
end

-- 玩家进入游戏，数据加载
function MServerInitPlayer.player_enter_game(player)
    player.DefaultDie = false   --取消默认死亡

    local uin_ = player.UserId
    if serverDataMgr.server_players_list[uin_] then
        gg.log('WARNING, Same uin enter game:', uin_)

        -- 清理旧的玩家实例（防止重复登录）
        local oldPlayer = serverDataMgr.server_players_list[uin_]
        if oldPlayer then
            oldPlayer:Save()  -- 保存旧玩家数据
            oldPlayer:leaveGame()  -- 执行离线清理
            serverDataMgr.removePlayer(uin_, oldPlayer.name or "Unknown")  -- 从列表中移除
            gg.log('Old player instance removed for uin:', uin_)
        end
    end

    local player_actor_ = player.Character
    player_actor_.CollideGroupID = 4
    player_actor_.Movespeed = 800

    --加载数据 1 玩家历史等级经验值
    local ret1_, cloud_player_data_ = cloudDataMgr.ReadPlayerData(uin_)
    if ret1_ == 0 then
        gg.log('clould_player_data ok:', uin_, cloud_player_data_)
        gg.network_channel:fireClient(uin_, { cmd="cmd_client_show_msg", txt='加载玩家等级数据成功' })     --飘字
    else
        gg.log('clould_player_data fail:', uin_, cloud_player_data_)
        gg.network_channel:fireClient(uin_, { cmd="cmd_client_show_msg", txt='加载玩家等级数据失败，请退出游戏后重试' })    --飘字
        return   --加载数据网络层失败
    end

    -- 玩家信息初始化（MPlayer会自动调用initPlayerData初始化背包和邮件）
    ---@type MPlayer
    local player_ = Player.New({
        position = Vector3.New(600, 400, -3400),      --(617,292,-3419)
        uin = uin_,
        nickname = player.Nickname,
        npc_type = common_const.NPC_TYPE.PLAYER,
        level = cloud_player_data_.level,
        exp = cloud_player_data_.exp,
        variables = cloud_player_data_.vars or {}
    })
    
    -- 读取任务数据
    cloudDataMgr.ReadGameTaskData(player_)

    -- 同步玩家的全服邮件数据
    MailManager:SyncGlobalMailsForPlayer(uin_)

    player_actor_.Size = Vector3.New(120, 160, 120)      --碰撞盒子的大小
    player_actor_.Center = Vector3.New(0, 80, 0)      --盒子中心位置

    player_:setGameActor(player_actor_)     --player
    player_actor_.CollideGroupID = 4
    -- player_:setPlayerNetStat(common_const.PLAYER_NET_STAT.LOGIN_IN)    --player_net_stat login ok

    -- player_:initSkillData()                 --- 加载玩家技能
    -- player_:RefreshStats()               --重生 --刷新战斗属性
    -- player_:SetHealth(player_.maxHealth)
    -- player_:UpdateHud()
    if Scene.spawnScene then
        if not player_:IsNear(Scene.spawnScene.node.Position, 500) then
            player_actor_.Position = Scene.spawnScene.node.Position
        end
    end
    -- player_.inited = true
    ServerEventManager.Publish("PlayerInited", {player = player_})
    serverDataMgr.addPlayer(uin_, player_, player.Nickname)

    -- 主动推送邮件列表到客户端
    MailManager:SendMailListToClient(uin_)
end

-- 玩家离开游戏
function MServerInitPlayer.player_leave_game(player)
    gg.log("player_leave_game====", player.UserId, player.Name, player.Nickname)
    local uin_ = player.UserId

    if serverDataMgr.server_players_list[uin_] then
        serverDataMgr.server_players_list[uin_]:OnLeaveGame()
        serverDataMgr.server_players_list[uin_]:Save()
    end
    serverDataMgr.removePlayer(uin_, player.Name)
end

-- 获取等待中的玩家列表（用于调试）
function MServerInitPlayer.getWaitingPlayers()
    return waitingPlayers
end

-- 获取初始化状态（用于调试）
function MServerInitPlayer.getInitFinished()
    return initFinished
end

return MServerInitPlayer 