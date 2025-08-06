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
local RewardMgr = require(ServerStorage.MSystems.Reward.RewardMgr) ---@type RewardMgr

local MPlayer       = require(ServerStorage.EntityTypes.MPlayer)          ---@type MPlayer
local PlayerInitMgr = require(ServerStorage.MSystems.PlayerInitMgr) ---@type PlayerInitMgr

local cloudDataMgr  = require(ServerStorage.CloundDataMgr.MCloudDataMgr)    ---@type MCloudDataMgr


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
        -- MServerInitPlayer.player_leave_game(player)
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
    player_actor_.Movespeed = 800

    --加载数据 1 玩家历史等级经验值
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
    local isNewPlayer = next(cloud_player_data_) == nil

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
    player_actor_.CollideGroupID = 4

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
    RewardMgr.OnPlayerJoin(player_)
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
    MServerInitPlayer.EnsureDecorativeObjectsSync(player_actor_)

    gg.log("玩家进入了游戏", gg.player_scene_map,player)


end

-- 【新增】确保装饰性对象的同步设置正确
function MServerInitPlayer.EnsureDecorativeObjectsSync(player_actor)
    if not player_actor then
        return
    end

    -- 装饰性对象的名称列表
    local decorativeObjectNames = {
        "Pet1", "Pet2", "Pet3", "Pet4", "Pet5", "Pet6",
        "Partner1", "Partner2",
        "Wings1",
        "尾迹"
    }

    for _, objectName in ipairs(decorativeObjectNames) do
        local decorativeNode = player_actor:FindFirstChild(objectName)
        if decorativeNode then
            -- 确保同步设置正确
            decorativeNode.IgnoreStreamSync = false
        end
    end
end

-- 向客户端同步玩家数据
function MServerInitPlayer.syncPlayerDataToClient(mplayer)
    local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig
    local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
    local AchievementEventManager = require(ServerStorage.MSystems.Achievement.AchievementEventManager) ---@type AchievementEventManager

    local uin = mplayer.uin

            -- 获取背包数据 - 修改这里

    local bag = BagMgr.GetPlayerBag(uin)
    if bag then
        -- 标记为全量同步，确保发送完整的背包数据
        bag:MarkDirty(true)  -- true 表示全量同步
        bag:SyncToClient()   -- 直接调用背包的同步方法
        --gg.log("已使用 Bag:SyncToClient() 同步背包数据到客户端:", uin)
    else
        --gg.log("警告: 玩家", uin, "的背包数据不存在，跳过背包同步")
    end

    -- 【新增】同步宠物数据
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        local petListData = petManager:GetPlayerPetList()
        local PetEventManager = require(ServerStorage.MSystems.Pet.EventManager.PetEventManager) ---@type PetEventManager
        PetEventManager.NotifyPetListUpdate(uin, petListData)
        --gg.log("已主动同步宠物数据到客户端:", uin, "宠物数量:", petManager:GetPetCount())
    else
        --gg.log("警告: 玩家", uin, "的宠物数据不存在，跳过宠物数据同步")
    end

    -- 【新增】同步伙伴数据
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if partnerManager then
        local partnerListData = partnerManager:GetPlayerPartnerList()
        local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager
        PartnerEventManager.NotifyPartnerListUpdate(uin, partnerListData)
    else
        --gg.log("警告: 玩家", uin, "的伙伴数据不存在，跳过伙伴数据同步")
    end

    -- 【新增】同步翅膀数据
    local wingManager = WingMgr.GetPlayerWing(uin)
    if wingManager then
        local wingListData = wingManager:GetPlayerWingList()
        local WingEventManager = require(ServerStorage.MSystems.Pet.EventManager.WingEventManager) ---@type WingEventManager
        WingEventManager.NotifyWingListUpdate(uin, wingListData)
    else
        --gg.log("警告: 玩家", uin, "的翅膀数据不存在，跳过翅膀数据同步")
    end

    -- 【新增】同步尾迹数据
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if trailManager then
        local trailListData = trailManager:GetPlayerTrailList()
        local TrailEventManager = require(ServerStorage.MSystems.Trail.TrailEventManager) ---@type TrailEventManager
        TrailEventManager.NotifyTrailListUpdate(uin, trailListData)
        --gg.log("已主动同步尾迹数据到客户端:", uin, "尾迹数量:", trailManager:GetTrailCount())
    else
        --gg.log("警告: 玩家", uin, "的尾迹数据不存在，跳过尾迹数据同步")
    end

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

    -- 获取任务数据
    -- 【重构】调用成就事件管理器来处理所有成就数据的同步
    AchievementEventManager.NotifyAllDataToClient(uin)

    --gg.log("已向客户端", uin, "同步完整玩家数据")
end
-- 玩家离开游戏
function MServerInitPlayer.player_leave_game(player)
    gg.log("player_leave_game====", player.UserId, player.Name, player.Nickname)
    local uin_ = player.UserId

    local mplayer = serverDataMgr.server_players_list[uin_] ---@type MPlayer
    if mplayer then
        -- 【新增】清理玩家场景映射
        gg.player_scene_map[uin_] = nil
        
        -- 通知各个系统玩家已离开
        MailMgr.OnPlayerLeave(uin_)
        BagMgr.OnPlayerLeave(uin_)
        PetMgr.OnPlayerLeave(uin_)
        PartnerMgr.OnPlayerLeave(uin_)
        WingMgr.OnPlayerLeave(uin_)
        TrailMgr.OnPlayerLeave(uin_)
        AchievementMgr.OnPlayerLeave(uin_)
        RewardMgr.OnPlayerLeave(uin_)
        -- 其他管理器（如技能、任务等）的离线处理也可以在这里添加
        mplayer:leaveGame() -- 保存玩家基础数据
        serverDataMgr.removePlayer(uin_, player.Name)
    end
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
