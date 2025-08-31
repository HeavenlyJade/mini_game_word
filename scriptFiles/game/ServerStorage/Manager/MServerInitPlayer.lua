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
local common_const      = require(MainStorage.Code.Common.GameConfig.Mconst)     ---@type common_const
-- local Scene      = require(ServerStorage.Scene.Scene)         ---@type Scene -- [REMOVED]
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local serverDataMgr     = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr) ---@type MailMgr
local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr
local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
local TrailMgr = require(ServerStorage.MSystems.Trail.TrailMgr) ---@type TrailMgr
local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr) ---@type AchievementMgr
local LotteryMgr = require(ServerStorage.MSystems.Lottery.LotteryMgr) ---@type LotteryMgr

local MPlayer       = require(ServerStorage.EntityTypes.MPlayer)          ---@type MPlayer
local PlayerInitMgr = require(ServerStorage.MSystems.PlayerInitMgr) ---@type PlayerInitMgr

local cloudDataMgr  = require(ServerStorage.CloundDataMgr.MCloudDataMgr)    ---@type MCloudDataMgr
local NodeCloneGenerator = require(ServerStorage.ServerUntils.NodeCloneGenerator) ---@type NodeCloneGenerator


---@class MServerInitPlayer
local MServerInitPlayer = {}

-- 私有变量
local initFinished = false
local waitingPlayers = {} -- 存储等待初始化的玩家

-- 设置初始化完成状态
function MServerInitPlayer.setInitFinished(finished)
    initFinished = finished
    --gg.log('====waitingPlayers', waitingPlayers)
    -- 如果初始化完成，处理等待的玩家
    if finished then
        for _, player in ipairs(waitingPlayers) do
            --gg.log('====player_enter_game', player)
            MServerInitPlayer.player_enter_game(player)
        end
        waitingPlayers = {} -- 清空等待列表
    end
end

-- 注册玩家进游戏和出游戏消息
function MServerInitPlayer.register_player_in_out()
    local players = game:GetService("Players")

    players.PlayerAdded:Connect(function(player)
        --gg.log('====PlayerAdded', player.UserId)
        -- MServerInitPlayer.player_enter_game(player)

        if initFinished then
            MServerInitPlayer.player_enter_game(player)
        else
            table.insert(waitingPlayers, player)
            --gg.log('====PlayerAdded to waiting list', player.UserId)
        end
    end)

    players.PlayerRemoving:Connect(function(player)
        --gg.log('====PlayerRemoving', player.UserId)
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
    --gg.log("player_enter_game====", player.UserId, player.Name, player.Nickname)
    player.DefaultDie = false   --取消默认死亡

    local uin_ = player.UserId
    if serverDataMgr.server_players_list[uin_] then
        gg.log('WARNING, Same uin enter game:', uin_)

        -- 清理旧的玩家实例（防止重复登录）
        local oldPlayer = serverDataMgr.server_players_list[uin_]
        if oldPlayer then
            oldPlayer:leaveGame()  -- 执行离线清理
        end
    end

    local player_actor_ = player.Character
    player_actor_.CollideGroupID = 4
    player_actor_.Movespeed = 400

    --加载数据   1 玩家历史等级经验值
    local ret1_, cloud_player_data_ = cloudDataMgr.ReadPlayerData(uin_)
    if ret1_ == 0 then
        --gg.log('clould_player_data ok:', uin_, cloud_player_data_)
        gg.network_channel:fireClient(uin_, { cmd="cmd_client_show_msg", txt='加载玩家等级数据成功' })     --飘字
    else
        --gg.log('clould_player_data fail:', uin_, cloud_player_data_)
        gg.network_channel:fireClient(uin_, { cmd="cmd_client_show_msg", txt='加载玩家等级数据失败，请退出游戏后重试' })    --飘字
        return   --加载数据网络层失败
    end
    --gg.log('cloud_player_data_', cloud_player_data_)
    gg.log('isNewPlayer', cloud_player_data_)
    -- 玩家信息初始化（MPlayer会自动调用initPlayerData初始化背包和邮件）
    ---@type MPlayer
    local player_ = MPlayer.New({
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


    player_actor_.Size = Vector3.New(120, 160, 120)      --碰撞盒子的大小
    player_actor_.Center = Vector3.New(0, 80, 0)      --盒子中心位置

    player_:setGameActor(player_actor_)     --player

    -- 【新增】确保装饰性对象的同步设置正确

    serverDataMgr.addPlayer(uin_, player_, player.Nickname)
    
    -- 【新增】初始化玩家场景为init_map
    gg.player_scene_map[uin_] = 'init_map'

    AchievementMgr.OnPlayerJoin(uin_)
    MailMgr.OnPlayerJoin(player_)
    BagMgr.OnPlayerJoin(player_)
    PetMgr.OnPlayerJoin(player_)
    PartnerMgr.OnPlayerJoin(player_)
    WingMgr.OnPlayerJoin(player_)
    TrailMgr.OnPlayerJoin(player_)
    local RewardMgr = require(ServerStorage.MSystems.Reward.RewardMgr) ---@type RewardMgr
    RewardMgr.OnPlayerJoin(player_)
    LotteryMgr.OnPlayerJoin(player_)
    local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr
    ShopMgr.OnPlayerJoin(player_)
    if cloud_player_data_ == nil or next(cloud_player_data_) == nil then
        PlayerInitMgr.InitializeNewPlayer(player_)
    end
    
    -- 【重构】玩家上线时，调用伙伴管理器来更新模型显示
    PartnerMgr.UpdateAllEquippedPartnerModels(player_)
    -- 【新增】玩家上线时，调用宠物管理器来更新模型显示
    PetMgr.UpdateAllEquippedPetModels(player_)
    -- 【新增】玩家上线时，调用翅膀管理器来更新模型显示
    WingMgr.UpdateAllEquippedWingModels(player_)
    -- 【新增】玩家上线时，调用尾迹管理器来更新模型显示
    TrailMgr.UpdateAllEquippedTrailModels(player_)

    MServerInitPlayer.syncPlayerDataToClient(player_)
    MServerInitPlayer.EnsureDecorativeObjectsSync(player_actor_,player_)
    gg.log("玩家碰撞组设置验证:", player.name, "CollideGroupID:", player_actor_.CollideGroupID)
    gg.log("玩家进入了游戏", gg.player_scene_map,player)


end

-- 【新增】确保装饰性对象的同步设置正确
function MServerInitPlayer.EnsureDecorativeObjectsSync(player_actor,player)
    if not player_actor then
        return
    end

    -- 生成玩家名称节点（如果未生成）
    NodeCloneGenerator.GeneratePlayerNameDisplay(player)

    -- 装饰性对象的名称列表
    local decorativeObjectNames = {
        "Pet1", "Pet2", "Pet3", "Pet4", "Pet5", "Pet6",
        "Partner1", "Partner2",
        "Wings1",
    }

    for _, objectName in ipairs(decorativeObjectNames) do
        local decorativeNode = player_actor:FindFirstChild(objectName)
        if decorativeNode then
            -- 确保同步设置正确
            decorativeNode.IgnoreStreamSync = true
            decorativeNode.CollideGroupID = 5
        end
    end


    

end

-- 向客户端同步玩家数据
function MServerInitPlayer.syncPlayerDataToClient(mplayer)
    local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig
    local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
    local AchievementEventManager = require(ServerStorage.MSystems.Achievement.AchievementEventManager) ---@type AchievementEventManager

    local uin = mplayer.uin
    BagMgr.ForceSyncToClient(uin)
    PetMgr.ForceSyncToClient(uin)

    PartnerMgr.ForceSyncToClient(uin)
    WingMgr.ForceSyncToClient(uin)
    -- 【新增】同步尾迹数据
    TrailMgr.ForceSyncToClient(uin)

    -- 【新增】同步抽奖数据
    local LotteryEventManager = require(ServerStorage.MSystems.Lottery.LotteryEventManager) ---@type LotteryEventManager
    LotteryEventManager.NotifyAllDataToClient(uin)

    -- 【新增】同步商城数据
    local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr
    ShopMgr.PushShopDataToClient(uin)


    -- 获取变量数据
    if mplayer.variableSystem then
        local variableData = mplayer.variableSystem.variables
        gg.network_channel:fireClient(uin, {
            cmd = EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE,
            variableData = variableData,
        })
    else
        --gg.log("警告: 玩家", uin, "的variableSystem不存在，跳过变量数据同步")
    end

    -- 【新增】同步玩家等级和经验数据
    mplayer:syncLevelExpToClient()

    -- 获取任务数据
    -- 【重构】调用成就事件管理器来处理所有成就数据的同步
    AchievementEventManager.NotifyAllDataToClient(uin)

    -- 【新增】同步排行榜数据
    local RankingEventManager = require(ServerStorage.MSystems.Ranking.RankingEventManager) ---@type RankingEventManager
    RankingEventManager.NotifyAllDataToClient(uin)

    gg.log("已向客户端", uin, "同步完整玩家数据")
end
-- 玩家离开游戏
function MServerInitPlayer.player_leave_game(player)
    gg.log("玩家离开游戏", player.UserId, player.Name, player.Nickname)
    local RewardMgr = require(ServerStorage.MSystems.Reward.RewardMgr) ---@type RewardMgr

    
    local uin_ = player.UserId
    local mplayer = serverDataMgr.server_players_list[uin_] ---@type MPlayer
    if mplayer then
        -- 【新增】清理玩家场景映射
         -- 【新增】清理挂机点数据
         local IdleSpotHandler = require(ServerStorage.SceneInteraction.handlers.IdleSpotHandler) ---@type IdleSpotHandler
         IdleSpotHandler.CleanupPlayerData(mplayer)
         
         -- 【新增】清理比赛数据
         local RaceTriggerHandler = require(ServerStorage.SceneInteraction.handlers.RaceTriggerHandler)
         RaceTriggerHandler.CleanupPlayerData(mplayer)
         
         -- 【新增】清理游戏模式数据
         local serverDataMgr = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
         local GameModeManager = serverDataMgr.GameModeManager ---@type GameModeManager
         if GameModeManager then
             GameModeManager:ForceCleanupPlayer(mplayer)
         end

        gg.player_scene_map[uin_] = nil

        BagMgr.OnPlayerLeave(uin_)
        MailMgr.OnPlayerLeave(uin_)
        PetMgr.OnPlayerLeave(uin_)
        PartnerMgr.OnPlayerLeave(uin_)
        WingMgr.OnPlayerLeave(uin_)
        TrailMgr.OnPlayerLeave(uin_)
        AchievementMgr.OnPlayerLeave(uin_)
        RewardMgr.OnPlayerLeave(uin_)
        LotteryMgr.OnPlayerLeave(uin_)
        mplayer:leaveGame()
        serverDataMgr.removePlayer(uin_, player.Name)
        local AutoPlayManager = require(ServerStorage.AutoRaceSystem.AutoPlayManager) ---@type AutoPlayManager
        AutoPlayManager.CleanupPlayerAutoPlayState(uin_)
        local AutoRaceManager = require(ServerStorage.AutoRaceSystem.AutoRaceManager) ---@type AutoRaceManager

        AutoRaceManager.CleanupPlayerAutoRaceState(uin_)
    end
end

function MServerInitPlayer.OnPlayerSave(uin_)
    local RewardMgr = require(ServerStorage.MSystems.Reward.RewardMgr) ---@type RewardMgr
    local mplayer = serverDataMgr.server_players_list[uin_] ---@type MPlayer
    
    if not mplayer then
        return
    end
    
        -- 保存各个系统的数据
    MailMgr.SavePlayerMailData(uin_)
    BagMgr.SaveAllOnlinePlayerBags(uin_)
    PetMgr.ForceSavePlayerData(uin_)
    PartnerMgr.SavePlayerPartnerData(uin_)
    WingMgr.SavePlayerWingData(uin_)
    TrailMgr.SavePlayerTrailData(uin_)
    AchievementMgr.SavePlayerAchievementData(uin_)
    RewardMgr.SavePlayerRewardData(uin_)
    LotteryMgr.SavePlayerLotteryData(uin_)
    local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr
    ShopMgr.SavePlayerShopData(uin_)
    -- 保存玩家基础数据
    mplayer:leaveGame()
    gg.log("统一存盘：玩家", uin_, "数据已保存")
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
