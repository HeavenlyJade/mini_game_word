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
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
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
local MiniApiFriendsService = require(MainStorage.Code.MServer.MiniApiServices.MiniApiFriendsService) ---@type MiniApiFriendsService

local cloudDataMgr  = require(ServerStorage.CloundDataMgr.MCloudDataMgr)    ---@type MCloudDataMgr
local NodeCloneGenerator = require(ServerStorage.ServerUntils.NodeCloneGenerator) ---@type NodeCloneGenerator
local MPlayerTraitManager = require(ServerStorage.Manager.MPlayerTraitManager) ---@type MPlayerTraitManager


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
        -- 【新增】清理房间好友记录
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
    local dailyLoginData = cloud_player_data_.dailyLogin or {}
    local lastLoginDate = dailyLoginData.lastLoginDate or ""
    local consecutiveDays = dailyLoginData.consecutiveDays or 0
    local totalLoginDays = dailyLoginData.totalLoginDays or 0
    local firstLoginDate = dailyLoginData.firstLoginDate or ""
    local adWatchCount = cloud_player_data_.adWatchCount or 0
    -- 玩家信息初始化（MPlayer会自动调用initPlayerData初始化背包和邮件）
    ---@type MPlayer
    local player_ = MPlayer.New({
        position = Vector3.New(600, 400, -3400),      --(617,292,-3419)
        uin = uin_,
        nickname = player.Nickname,
        npc_type = common_const.NPC_TYPE.PLAYER,
        level = cloud_player_data_.level,
        exp = cloud_player_data_.exp,
        variables = cloud_player_data_.vars or {},
        lastLoginDate = lastLoginDate,
        consecutiveDays = consecutiveDays,
        totalLoginDays = totalLoginDays,
        firstLoginDate = firstLoginDate,
        adWatchCount = adWatchCount
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
    local RewardBonusMgr = require(ServerStorage.MSystems.RewardBonus.RewardBonusMgr) ---@type RewardBonusMgr
    RewardBonusMgr.OnPlayerJoin(player_)
    -- 判断是否为新玩家：数据为空、isNew为false、或者vars为空表
    local isNewPlayer = cloud_player_data_ == nil or 
                       not cloud_player_data_.vars or 
                       next(cloud_player_data_.vars) == nil
    
    if isNewPlayer then
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
    
    -- 【新增】设置玩家Actor事件监听
    MServerInitPlayer.setupPlayerActorEvents(player_)
    
    gg.log("玩家碰撞组设置验证:", player.name, "CollideGroupID:", player_actor_.CollideGroupID)
    gg.log("玩家进入了游戏", gg.player_scene_map,player)

    -- 执行指令执行配置中的指令列表
    MServerInitPlayer.ExecuteCommandConfig(player_)
    -- 【新增】记录房间内好友关系
    -- 【新增】广播当前房间玩家列表给所有在线玩家（客户端用于刷新UI，如好友加成）
    do
        local allPlayers = {}
        for u, _ in pairs(serverDataMgr.server_players_list) do
            table.insert(allPlayers, u)
        end
        for u, _ in pairs(serverDataMgr.server_players_list) do
            gg.network_channel:fireClient(u, {
                cmd = EventPlayerConfig.NOTIFY.ROOM_PLAYERS_BROADCAST,
                players = allPlayers,
            })
        end
    end
    local isFirstLoginToday, consecutiveDays = player_:CheckDailyLogin()

    if isFirstLoginToday then
        gg.log("玩家今日首次登录，开始处理每日重置逻辑", player.Nickname, "连续登录", consecutiveDays, "天")
        player_:SetAdWatchCount(0)
    end
    
    -- 【新增】检查玩家是否通过邀请进入以及是否为新玩家
    -- MServerInitPlayer.checkPlayerInviteAndNewPlayerStatus(player_)
end

-- 执行指令执行配置中的指令列表
function MServerInitPlayer.ExecuteCommandConfig(player)
    local common_config = require(MainStorage.Code.Common.GameConfig.MConfig) ---@type common_config
    local CommandManager = require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager

    for _, command in ipairs(common_config.CommandExecutionConfig) do
        gg.log("执行指令:", command)
        CommandManager.ExecuteCommand(command, player, true)
    end
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

    -- 【新增】同步奖励加成数据
    local RewardBonusEventManager = require(ServerStorage.MSystems.RewardBonus.RewardBonusEventManager) ---@type RewardBonusEventManager
    RewardBonusEventManager.SyncPlayerRewardData(uin)

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

    -- 【新增】同步玩家广告观看次数数据
    local MServerEventManager = require(ServerStorage.Manager.MServerEventManager) ---@type MServerEventManager
    MServerEventManager.syncAdWatchCountToClient(mplayer)

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
        local RewardBonusMgr = require(ServerStorage.MSystems.RewardBonus.RewardBonusMgr) ---@type RewardBonusMgr
        RewardBonusMgr.OnPlayerLeave(mplayer)
    end


    local allPlayers = {}
    for u, _ in pairs(serverDataMgr.server_players_list) do
        table.insert(allPlayers, u)
    end
    for u, _ in pairs(serverDataMgr.server_players_list) do
        gg.network_channel:fireClient(u, {
            cmd = EventPlayerConfig.NOTIFY.ROOM_PLAYERS_BROADCAST,
            players = allPlayers,
        })
    end

end

function MServerInitPlayer.OnPlayerSave(uin_)
    local RewardMgr = require(ServerStorage.MSystems.Reward.RewardMgr) ---@type RewardMgr
    local mplayer = serverDataMgr.server_players_list[uin_] ---@type MPlayer
    
    if not mplayer then
        return
    end
    
        -- 保存各个系统的数据
    -- MailMgr.SavePlayerMailData(uin_)
    mplayer:leaveGame()
    BagMgr.SaveAllOnlinePlayerBags(uin_)
    PetMgr.ForceSavePlayerData(uin_)
    PartnerMgr.SavePlayerPartnerData(uin_)
    WingMgr.SavePlayerWingData(uin_)
    TrailMgr.SavePlayerTrailData(uin_)
    -- LotteryMgr.SavePlayerLotteryData(uin_)


    -- AchievementMgr.SavePlayerAchievementData(uin_)
    -- RewardMgr.SavePlayerRewardData(uin_)
    local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr
    -- ShopMgr.SavePlayerShopData(uin_)
    local RewardBonusMgr = require(ServerStorage.MSystems.RewardBonus.RewardBonusMgr) ---@type RewardBonusMgr
    -- RewardBonusMgr.SavePlayerData(uin_)
    -- 保存玩家基础数据
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

-- 监听玩家Actor的各种事件
function MServerInitPlayer.setupPlayerActorEvents(mplayer)
    local actor = mplayer.actor
    if not actor then
        gg.log("错误：玩家", mplayer.uin, "的Actor不存在，无法设置事件监听")
        return
    end

    -- 监听行走事件
    actor.Walking:Connect(function(isWalking)
        if isWalking then
            -- 检查是否装备了翅膀，如果装备了则播放翅膀扇动音效
            MServerInitPlayer.playWingSoundIfEquipped(mplayer, true)
        else
            -- 停止翅膀扇动音效
            MServerInitPlayer.playWingSoundIfEquipped(mplayer, false)
        end
    end)

end

-- 检查是否装备了翅膀并播放/停止翅膀扇动音效
function MServerInitPlayer.playWingSoundIfEquipped(mplayer, isPlaying)
    if not mplayer or not mplayer.uin then
        return
    end

    local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
    
    -- 检查玩家是否装备了翅膀
    -- local hasEquippedWings = WingMgr.HasEquippedWings(mplayer.uin)
    
    -- if hasEquippedWings then
    --     local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
    --     local wingSoundAssetId = CardIcon.soundResources["翅膀扇动音效1"]
        
    --     if wingSoundAssetId then
    --         if isPlaying then
    --             -- 播放翅膀扇动音效
    --             gg.network_channel:fireClient(mplayer.uin, {
    --                 cmd = "PlaySound",
    --                 soundAssetId = wingSoundAssetId,
    --                 key = "wing_flap_" .. mplayer.uin, -- 使用玩家ID作为唯一键
    --                 volume = 3, -- 设置合适的音量
    --                 isLoop = true -- 循环播放
    --             })
    --         else
    --             -- 停止翅膀扇动音效
    --             gg.network_channel:fireClient(mplayer.uin, {
    --                 cmd = "StopKeyedSound",
    --                 key = "wing_flap_" .. mplayer.uin
    --             })
    --         end
    --     else
    --     end
    -- end
end

-- 【新增】检查玩家是否通过邀请进入以及是否为新玩家
---@param player MPlayer 玩家对象
function MServerInitPlayer.checkPlayerInviteAndNewPlayerStatus(player)
    if not player or not player:Is("MPlayer") then
        return
    end
    
    gg.log("开始检查玩家邀请和新玩家状态:", player.name, "UIN:", player.uin)
    
    -- 检查是否有邀请者
    local inviteData = MPlayerTraitManager.GetInvitePlayer(player)
    if inviteData then
        gg.log("玩家通过邀请进入:", player.name, "邀请者信息:", inviteData)
        
        -- 可以在这里处理邀请相关的逻辑
        -- 比如给邀请者奖励、记录邀请关系等
        MServerInitPlayer.handleInvitePlayerLogic(player, inviteData)
    else
        gg.log("玩家非邀请进入:", player.name)
    end
    
    -- 检查是否为新玩家
    local isNewToMap = MPlayerTraitManager.IsNewToThisMap(player)
    if isNewToMap ~= nil then
        if isNewToMap then
            gg.log("玩家是地图新玩家:", player.name, "地图ID:", MPlayerTraitManager.mapId)
            -- 可以在这里处理新玩家相关的逻辑
            -- 比如给新玩家奖励、显示引导等
            MServerInitPlayer.handleNewPlayerLogic(player)
        else
            gg.log("玩家不是地图新玩家:", player.name, "地图ID:", MPlayerTraitManager.mapId)
        end
    else
        gg.log("无法判断玩家是否为新玩家:", player.name)
    end
    
    -- 【新增】检查被邀请者列表
    local invitedList = MPlayerTraitManager.GetInvitedPlayerList(player)

    if invitedList and #invitedList > 0 then
        gg.log("玩家有被邀请者:", player.name, "被邀请者数量:", #invitedList, "被邀请者列表:", invitedList)
        
        -- 可以在这里处理被邀请者相关的逻辑
        -- 比如统计邀请数量、给邀请者奖励等
        MServerInitPlayer.handleInvitedPlayerListLogic(player, invitedList)
    else
        gg.log("玩家没有被邀请者:", player.name)
    end
end

-- 【新增】处理邀请玩家逻辑
---@param player MPlayer 玩家对象
---@param inviteData table 邀请者信息
function MServerInitPlayer.handleInvitePlayerLogic(player, inviteData)
    -- 这里可以添加邀请相关的业务逻辑
    -- 例如：
    -- 1. 给邀请者发送奖励
    -- 2. 记录邀请关系
    -- 3. 发送邀请成功通知
    -- 4. 更新邀请统计等
    
    gg.log("处理邀请玩家逻辑:", player.name, "邀请者数据:", inviteData)
    
    -- 示例：发送邀请成功通知给客户端
    gg.network_channel:fireClient(player.uin, {
        cmd = "INVITE_SUCCESS_NOTIFICATION",
        message = "欢迎通过邀请进入游戏！",
        inviteData = inviteData
    })
end

-- 【新增】处理新玩家逻辑
---@param player MPlayer 玩家对象
function MServerInitPlayer.handleNewPlayerLogic(player)
    -- 这里可以添加新玩家相关的业务逻辑
    -- 例如：
    -- 1. 给新玩家新手奖励
    -- 2. 显示新手引导
    -- 3. 发送欢迎消息
    -- 4. 记录新玩家数据等
    
    gg.log("处理新玩家逻辑:", player.name)
    
    -- 示例：发送新玩家欢迎通知给客户端
    gg.network_channel:fireClient(player.uin, {
        cmd = "NEW_PLAYER_WELCOME",
        message = "欢迎来到新地图！",
        isNewPlayer = true
    })
end

-- 【新增】处理被邀请者列表逻辑
---@param player MPlayer 玩家对象
---@param invitedList table 被邀请者列表
function MServerInitPlayer.handleInvitedPlayerListLogic(player, invitedList)
    -- 这里可以添加被邀请者相关的业务逻辑
    -- 例如：
    -- 1. 统计邀请数量
    -- 2. 给邀请者发放奖励
    -- 3. 更新邀请统计
    -- 4. 发送邀请成就通知等
    
    gg.log("处理被邀请者列表逻辑:", player.name, "被邀请者数量:", #invitedList)
    
    -- 示例：发送邀请统计通知给客户端
    gg.network_channel:fireClient(player.uin, {
        cmd = "INVITE_STATISTICS_UPDATE",
        message = string.format("您已成功邀请 %d 名玩家！", #invitedList),
        invitedCount = #invitedList,
        invitedList = invitedList
    })
    
    -- 示例：根据邀请数量给邀请者奖励
    if #invitedList >= 5 then
        gg.log("邀请者获得邀请成就奖励:", player.name, "邀请数量:", #invitedList)
        -- 可以在这里添加具体的奖励逻辑
    end
end

return MServerInitPlayer
