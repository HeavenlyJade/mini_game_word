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
local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr) ---@type AchievementMgr

local MPlayer       = require(ServerStorage.EntityTypes.MPlayer)          ---@type MPlayer

local cloudDataMgr  = require(ServerStorage.CloundDataMgr.MCloudDataMgr)    ---@type MCloudDataMgr


---@class MServerInitPlayer
local MServerInitPlayer = {}

-- 私有变量
local initFinished = false
local waitingPlayers = {} -- 存储等待初始化的玩家

-- 设置初始化完成状态
function MServerInitPlayer.setInitFinished(finished)
    initFinished = finished
    gg.log('====waitingPlayers', waitingPlayers)
    -- 如果初始化完成，处理等待的玩家
    if finished then
        for _, player in ipairs(waitingPlayers) do
            gg.log('====player_enter_game', player)
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
        -- MServerInitPlayer.player_enter_game(player)

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
    gg.log("player_enter_game====", player.UserId, player.Name, player.Nickname)
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
        gg.log('clould_player_data ok:', uin_, cloud_player_data_)
        gg.network_channel:fireClient(uin_, { cmd="cmd_client_show_msg", txt='加载玩家等级数据成功' })     --飘字
    else
        gg.log('clould_player_data fail:', uin_, cloud_player_data_)
        gg.network_channel:fireClient(uin_, { cmd="cmd_client_show_msg", txt='加载玩家等级数据失败，请退出游戏后重试' })    --飘字
        return   --加载数据网络层失败
    end

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

    -- 加载玩家邮件数据到MailMgr统一管理（包括个人邮件和全服邮件状态）


    player_actor_.Size = Vector3.New(120, 160, 120)      --碰撞盒子的大小
    player_actor_.Center = Vector3.New(0, 80, 0)      --盒子中心位置

    player_:setGameActor(player_actor_)     --player
    player_actor_.CollideGroupID = 4
    
    -- player_:setPlayerNetStat(common_const.PLAYER_NET_STAT.LOGIN_IN)    --player_net_stat login ok

    -- player_:initSkillData()                 --- 加载玩家技能
    -- player_:RefreshStats()               --重生 --刷新战斗属性
    -- if gg.spawnSceneHandler and gg.spawnSceneHandler.node then
    --     if not player_:IsNear(gg.spawnSceneHandler.node.Position, 500) then
    --         player_actor_.Position = gg.spawnSceneHandler.node.Position
    --     end
    -- end
    -- player_.inited = true
    ServerEventManager.Publish("PlayerInited", {player = player_})
    serverDataMgr.addPlayer(uin_, player_, player.Nickname)
    AchievementMgr.OnPlayerJoin(uin_)
    MailMgr.OnPlayerJoin(player_)
    BagMgr.OnPlayerJoin(player_)
    PetMgr.OnPlayerJoin(player_)
    PartnerMgr.OnPlayerJoin(player_)
    gg.log("玩家", uin_, "登录完成，邮件、背包、宠物、伙伴和天赋数据已加载")
    MServerInitPlayer.syncPlayerDataToClient(player_)

    
end

-- 向客户端同步玩家数据
-- 向客户端同步玩家数据
function MServerInitPlayer.syncPlayerDataToClient(mplayer)
    local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig
    local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
    local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr) ---@type AchievementMgr


    local uin = mplayer.uin
    
            -- 获取背包数据 - 修改这里

    local bag = BagMgr.GetPlayerBag(uin)
    if bag then
        -- 标记为全量同步，确保发送完整的背包数据
        bag:MarkDirty(true)  -- true 表示全量同步
        bag:SyncToClient()   -- 直接调用背包的同步方法
        gg.log("已使用 Bag:SyncToClient() 同步背包数据到客户端:", uin)
    else
        gg.log("警告: 玩家", uin, "的背包数据不存在，跳过背包同步")
    end
    
    -- 【新增】同步宠物数据
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        local petListData = petManager:GetPlayerPetList()
        local PetEventManager = require(ServerStorage.MSystems.Pet.EventManager.PetEventManager) ---@type PetEventManager
        PetEventManager.NotifyPetListUpdate(uin, petListData.petList)
        gg.log("已主动同步宠物数据到客户端:", uin, "宠物数量:", petManager:GetPetCount())
    else
        gg.log("警告: 玩家", uin, "的宠物数据不存在，跳过宠物数据同步")
    end

    -- 【新增】同步伙伴数据
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if partnerManager then
        local partnerListData = partnerManager:GetPlayerPartnerList()
        local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager
        PartnerEventManager.NotifyPartnerListUpdate(uin, partnerListData.partnerList)
        gg.log("已主动同步伙伴数据到客户端:", uin, "伙伴数量:", partnerManager:GetPartnerCount())
    else
        gg.log("警告: 玩家", uin, "的伙伴数据不存在，跳过伙伴数据同步")
    end
    
    -- 获取变量数据
    local variableData = mplayer.variables or {}
    -- 获取任务数据
    local questData = mplayer.questData or {}
    
    gg.network_channel:fireClient(uin, { 
        cmd = EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE, 
        variableData = variableData,
    })
    
    gg.network_channel:fireClient(uin, { 
        cmd = EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_QUEST, 
        questData = questData,
    })
    
        -- 【新增】同步天赋成就数据
        local playerAchievement = AchievementMgr.server_player_achievement_data[uin]
        if playerAchievement then
            -- 构建天赋响应数据
            local talentData = playerAchievement:GetAllTalentData()
            local normalAchievements = playerAchievement:GetAllNormalAchievements()
            
            local achievementResponseData = {
                talents = {},
                normalAchievements = {},
                totalTalentCount = playerAchievement:GetTalentCount(),
                totalNormalCount = playerAchievement:GetUnlockedNormalAchievementCount()
            }
            
            -- 构建天赋列表
            for talentId, talentInfo in pairs(talentData) do
                achievementResponseData.talents[talentId] = {
                    talentId = talentId,
                    currentLevel = talentInfo.currentLevel,
                    unlockTime = talentInfo.unlockTime
                }
            end
            
            -- 构建普通成就列表
            for achievementId, achievementInfo in pairs(normalAchievements) do
                achievementResponseData.normalAchievements[achievementId] = {
                    achievementId = achievementId,
                    unlocked = achievementInfo.unlocked,
                    unlockTime = achievementInfo.unlockTime
                }
            end
            
     
            gg.network_channel:fireClient(uin, {
                cmd = AchievementEventConfig.RESPONSE.LIST_RESPONSE,
                data = achievementResponseData
            })
            
            gg.log("已主动同步天赋成就数据到客户端:", uin, "天赋数量:", achievementResponseData.totalTalentCount, "普通成就数量:", achievementResponseData.totalNormalCount)
        else
            gg.log("警告: 玩家", uin, "的天赋成就数据不存在，跳过天赋数据同步")
        end
        
    gg.log("已向客户端", uin, "同步完整玩家数据")
end
-- 玩家离开游戏
function MServerInitPlayer.player_leave_game(player)
    gg.log("player_leave_game====", player.UserId, player.Name, player.Nickname)
    local uin_ = player.UserId

    local mplayer = serverDataMgr.server_players_list[uin_] ---@type MPlayer
    if mplayer then
        -- 通知各个系统玩家已离开
        MailMgr.OnPlayerLeave(uin_)
        BagMgr.OnPlayerLeave(uin_)
        PetMgr.OnPlayerLeave(uin_)
        PartnerMgr.OnPlayerLeave(uin_)
        AchievementMgr.OnPlayerLeave(uin_)
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