--- V109 miniw-haima

local game     = game
local pairs    = pairs
local ipairs   = ipairs
local type     = type
local SandboxNode = SandboxNode
local Vector2  = Vector2
local Vector3  = Vector3
local ColorQuad = ColorQuad
local Enum = Enum
local wait = wait
local math = math
local os   = os


local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local PhysXService =game:GetService("PhysXService")
local MS = require(MainStorage.Code.Untils.MS) ---@type MS
local gg                = require(MainStorage.Code.Untils.MGlobal)    ---@type gg


local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local serverDataMgr     = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

local MServerInitPlayer = require(ServerStorage.Manager.MServerInitPlayer) ---@type MServerInitPlayer

local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

-- 总入口

gg.isServer = true
---@class MainServer
local MainServer = {}

-- 每秒执行
function MainServer.EverySecondExecute()
    local timer = SandboxNode.New("Timer", game.WorkSpace)
    timer.Name = "EverySecondTimer"
    timer.Delay = 1  -- 1秒延迟
    timer.Loop = true  -- 循环执行
    timer.Callback = function()
        -- 对所有在线玩家执行刷新
        for _, player in pairs(serverDataMgr.getAllPlayers()) do
            if player  then                
                -- 检查并清理过期的临时buff
                local buffCountBefore = 0
                for _ in pairs(player.tempBuffs) do
                    buffCountBefore = buffCountBefore + 1
                end
                
                -- 使用MPlayer的清理方法
                player:CleanExpiredTempBuffs()
                
                local buffCountAfter = 0
                for _ in pairs(player.tempBuffs) do
                    buffCountAfter = buffCountAfter + 1
                end
                
                local cleanedCount = buffCountBefore - buffCountAfter
                if cleanedCount > 0 then
                    gg.log("每秒执行清理过期buff", player.name, "清理了", cleanedCount, "个过期的临时buff")
                end
            end
        end
    end
    timer:Start()
end

function MainServer.start_server()
    gg.log("开始服务器启动")
    ConfigLoader.Init()
    math.randomseed(os.time() + gg.GetTimeStamp())
    serverDataMgr.uuid_start = gg.rand_int_between(100000, 999999)
    MServerInitPlayer.register_player_in_out()   --玩家进出游戏
    -- local physxService = PhysXService:GetInstance()
    -- physxService:SetCollideInfo(1, 1, false)
    MainServer.initModule()

    MainServer.createNetworkChannel()     --建立网络通道
    wait(1)                               --云服务器启动配置文件下载和解析繁忙，稍微等待
    -- MainServer.bind_update_tick()         --开始tick
    MainServer.bind_save_data_tick()      --开始定时存盘
    MServerInitPlayer.setInitFinished(true)  -- 设置初始化完成
    MainServer.SetCollisionGroup()
    MainServer.EverySecondExecute()    --设置每秒执行定时任务

    gg.log("服务器启动完成")

end


function MainServer.initModule()
    gg.log("初始化模块")
    -- 【新增】初始化全局任务调度器
    local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask
    ScheduledTask.Init()

    -- 初始化核心管理器
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr)
    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr
    local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
    local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
    local TrailMgr = require(ServerStorage.MSystems.Trail.TrailMgr) ---@type TrailMgr
    local GameModeManager = require(ServerStorage.GameModes.GameModeManager) ---@type GameModeManager
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr) ---@type AchievementMgr
    local RewardMgr = require(ServerStorage.MSystems.Reward.RewardMgr) ---@type RewardMgr
    local LotteryMgr = require(ServerStorage.MSystems.Lottery.LotteryMgr) ---@type LotteryMgr
    local MiniShopManager = require(ServerStorage.MiniGameMgr.MiniShopManager) ---@type MiniShopManager
    local RankingMgr = require(ServerStorage.MSystems.Ranking.RankingMgr) ---@type RankingMgr
    local SceneNodeManager = require(ServerStorage.SceneInteraction.SceneNodeManager) ---@type SceneNodeManager

    -- 延迟加载RewardMgr以避免循环引用
    serverDataMgr.BagMgr = BagMgr
    serverDataMgr.MailMgr = MailMgr
    serverDataMgr.PetMgr = PetMgr
    serverDataMgr.PartnerMgr = PartnerMgr
    serverDataMgr.WingMgr = WingMgr
    serverDataMgr.TrailMgr = TrailMgr
    serverDataMgr.GameModeManager = GameModeManager
    serverDataMgr.AchievementMgr = AchievementMgr
    serverDataMgr.RewardMgr = RewardMgr  -- 延迟加载
    serverDataMgr.LotteryMgr = LotteryMgr
    serverDataMgr.MiniShopManager = MiniShopManager:OnInit()
    serverDataMgr.RankingMgr = RankingMgr
    RankingMgr.SystemInit()
    gg.log("初始化事件管理器和命令管理器")
    -- 初始化事件管理器和命令管理器
    local CommandManager = require(ServerStorage.CommandSys.MCommandMgr)
    local BagEventManager = require(ServerStorage.MSystems.Bag.BagEventManager) ---@type BagEventManager
    local MailEventManager = require(ServerStorage.MSystems.Mail.MailEventManager) ---@type MailEventManager
    local PetEventManager = require(ServerStorage.MSystems.Pet.EventManager.PetEventManager) ---@type PetEventManager
    local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager
    local WingEventManager = require(ServerStorage.MSystems.Pet.EventManager.WingEventManager) ---@type WingEventManager
    local TrailEventManager = require(ServerStorage.MSystems.Trail.TrailEventManager) ---@type TrailEventManager
    local GlobalMailManager = require(ServerStorage.MSystems.Mail.GlobalMailManager) ---@type GlobalMailManager
    local RaceGameEventManager = require(ServerStorage.GameModes.Modes.RaceGameEventManager) ---@type RaceGameEventManager
    local AchievementEventManager = require(ServerStorage.MSystems.Achievement.AchievementEventManager) ---@type AchievementEventManager
    local RewardEventManager = require(ServerStorage.MSystems.Reward.RewardEventManager) ---@type RewardEventManager
    local LotteryEventManager = require(ServerStorage.MSystems.Lottery.LotteryEventManager) ---@type LotteryEventManager
    local ShopEventManager = require(ServerStorage.MSystems.Shop.ShopEventManager) ---@type ShopEventManager
    local RewardBonusEventManager = require(ServerStorage.MSystems.RewardBonus.RewardBonusEventManager) ---@type RewardBonusEventManager
    local CommonEventManager = require(ServerStorage.MiniGameMgr.CommonEventManager) ---@type CommonEventManager
    local RankingEventManager = require(ServerStorage.MSystems.Ranking.RankingEventManager) ---@type RankingEventManager
    local SceneInteractionEventManager = require(ServerStorage.SceneInteraction.SceneInteractionEventManager) ---@type SceneInteractionEventManager
    local MServerEventManager = require(ServerStorage.Manager.MServerEventManager) ---@type MServerEventManager

    serverDataMgr.CommandManager = CommandManager
    serverDataMgr.GlobalMailManager = GlobalMailManager:OnInit()

    BagEventManager.Init()
    MailEventManager.Init()
    PetEventManager.Init()
    PartnerEventManager.Init()
    WingEventManager.Init()
    TrailEventManager.Init()
    RaceGameEventManager.Init()
    AchievementEventManager.Init()
    RewardEventManager.Init()
    LotteryEventManager.Init()
    ShopEventManager.Init()
    RewardBonusEventManager.Init()
    CommonEventManager.Init()
    RankingEventManager.Init()
    SceneInteractionEventManager.Init()
    MServerEventManager.Init()



    SceneNodeManager.Init()
    local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
    local AutoRaceManager = require(ServerStorage.AutoRaceSystem.AutoRaceManager) ---@type AutoRaceManager
    local AutoPlayEventManager = require(ServerStorage.AutoRaceSystem.AutoPlayEvent) ---@type AutoPlayEventManager
    local AutoPlayManager = require(ServerStorage.AutoRaceSystem.AutoPlayManager) ---@type AutoPlayManager
    AutoRaceManager.Init()
    AutoRaceEventManager.Init()
    AutoPlayManager.Init()
    AutoPlayEventManager.Init()
    RewardMgr.Init()



    gg.log("模块初始化完成")
end

-- --设置碰撞组
function MainServer.SetCollisionGroup()
    --设置碰撞组
    local WS = game:GetService("PhysXService")
    WS:SetCollideInfo(4, 4, false)   --玩家不与玩家碰撞
    WS:SetCollideInfo(5, 5, false)   --玩家之间的翅膀宠物伙伴不碰撞碰撞组
    -- WS:SetCollideInfo(0, 1, false)   --玩家不与怪物碰撞
end



--建立网络通道
function MainServer.createNetworkChannel()

        gg.network_channel = MainStorage:WaitForChild("NetworkChannel")
        gg.network_channel.OnServerNotify:Connect(MainServer.OnServerNotify)
end


function MainServer.OnServerNotify(uin_, args)
    if type(args) ~= 'table' then return end
    if not args.cmd then return end

    local player_ = serverDataMgr.getPlayerByUin(uin_)
    if not player_ then
        return
    end
    args.player = player_
    if args.__cb then
        args.Return = function(returnData)
            game:GetService("NetworkChannel"):fireClient({
                cmd = args.__cb .. "_Return",
                data = returnData
            })
        end
    end
    -- 自动判断：如果玩家有该事件的本地订阅，则作为本地事件发布，否则作为全局事件广播
    if ServerEventManager.HasLocalSubscription(player_, args.cmd) then
        ServerEventManager.PublishToPlayer(player_, args.cmd, args)
    else
        ServerEventManager.Publish(args.cmd, args)
    end
end

--开启update
-- function MainServer.bind_update_tick()
--     -- 一个定时器, 实现tick update
--     local timer = SandboxNode.New("Timer", game.WorkSpace)
--     timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE

--     timer.Name = 'timer_server'
--     timer.Delay = 0.1      -- 延迟多少秒开始
--     timer.Loop = true      -- 是否循环
--     timer.Interval = 0.03   -- 循环间隔多少秒 (1秒=20帧)
--     timer.Callback = MainServer.update
--     timer:Start()     -- 启动定时器
--     gg.timer = timer;
-- end

--开启定时存盘
function MainServer.bind_save_data_tick()
    local timer = SandboxNode.New("Timer", game.WorkSpace)
    timer.Name = 'timer_save_player_data'
    timer.Delay = 30      -- 延迟多少秒开始
    timer.Loop = true      -- 是否循环
    timer.Interval =  1800  -- 循环间隔多少秒
    timer.Callback = function()
        for uin, player in pairs(serverDataMgr.getAllPlayers()) do
            MServerInitPlayer.OnPlayerSave(uin)
                -- 按需等待120秒，避免触发分钟级保存次数上限
            wait(120)
        end
    end
    timer:Start()
end


--定时器update
function MainServer.update()
    serverDataMgr.tick = serverDataMgr.tick + 1
end

return MainServer;
