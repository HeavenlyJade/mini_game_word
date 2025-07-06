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

local MS = require(MainStorage.Code.Untils.MS) ---@type MS
local gg                = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

local common_const      = require(MainStorage.Code.Common.GameConfig.Mconst)     ---@type common_const
-- local Scene      = require(ServerStorage.Scene.Scene)         ---@type Scene -- 不再需要

local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local ServerScheduler = require(MainStorage.Code.MServer.Scheduler.ServerScheduler) ---@type ServerScheduler
local serverDataMgr     = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local MServerInitPlayer = require(ServerStorage.Manager.MServerInitPlayer) ---@type MServerInitPlayer
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local SceneNodeManager = require(ServerStorage.SceneInteraction.SceneNodeManager) ---@type SceneNodeManager

-- 总入口

gg.isServer = true
---@class MainServer
local MainServer = {}

-- 处理午夜刷新
function MainServer.handleMidnightRefresh()
    local now = os.date("*t")
    local nextMidnight = os.time({
        year = now.year,
        month = now.month,
        day = now.day + 1,
        hour = 0,
        min = 0,
        sec = 0
    })
    local secondsUntilMidnight = nextMidnight - os.time()
    
    ServerScheduler.add(function()
        -- 对所有在线玩家执行刷新
        for _, player in pairs(serverDataMgr.getAllPlayers()) do
            if player and player.inited then
                player:RefreshNewDay()
            end
        end
        -- 重新设置下一个午夜的定时任务
        MainServer.handleMidnightRefresh()
    end, secondsUntilMidnight, 0, "midnight_refresh")
end

function MainServer.start_server()
    gg.log("开始服务器")
    ConfigLoader.Init()
    math.randomseed(os.time() + gg.GetTimeStamp())
    serverDataMgr.uuid_start = gg.rand_int_between(100000, 999999)
    MServerInitPlayer.register_player_in_out()   --玩家进出游戏
    MainServer.initModule()
    -- for _, node in  pairs(game.WorkSpace.Ground.Children) do -- 旧的场景初始化逻辑，已被SceneNodeManager取代
    --     local scene = Scene.New( node )
    --     serverDataMgr.addScene(node.Name, scene)
    -- end
    MainServer.createNetworkChannel()     --建立网络通道
    wait(1)                               --云服务器启动配置文件下载和解析繁忙，稍微等待
    MainServer.bind_update_tick()         --开始tick
    MainServer.handleMidnightRefresh()    --设置午夜刷新定时任务
    MServerInitPlayer.setInitFinished(true)  -- 设置初始化完成
    for _, child in pairs(MainStorage.Code.Common.Config.Children) do
        require(child)
    end
    gg.log("结束服务器")

end


function MainServer.initModule()
    gg.log("初始化模块")
    -- 初始化核心管理器
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr)
    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    serverDataMgr.BagMgr = BagMgr
    serverDataMgr.MailMgr = MailMgr

    -- 初始化事件管理器和命令管理器
    local CommandManager = require(ServerStorage.CommandSys.MCommandMgr)
    local BagEventManager = require(ServerStorage.MSystems.Bag.BagEventManager)
    local MailEventManager = require(ServerStorage.MSystems.Mail.MailEventManager)
    local GlobalMailManager = require(ServerStorage.MSystems.Mail.GlobalMailManager)

    gg.CommandManager = CommandManager
    gg.GlobalMailManager = GlobalMailManager:OnInit()

    BagEventManager:Init()
    MailEventManager:Init()
    
    -- 初始化场景交互系统
    SceneNodeManager:Init()
    
    gg.log("模块初始化完成")
end

-- --设置碰撞组
-- function MainServer.SetCollisionGroup()
--     --设置碰撞组
--     local WS = game:GetService("PhysXService")
--     WS:SetCollideInfo(0, 0, false)   --玩家不与玩家碰撞
--     WS:SetCollideInfo(1, 1, false)   --怪物不与怪物碰撞
--     WS:SetCollideInfo(0, 1, false)   --玩家不与怪物碰撞
-- end



--建立网络通道
function MainServer.createNetworkChannel()

        gg.network_channel = MainStorage:WaitForChild("NetworkChannel")
        gg.network_channel.OnServerNotify:Connect(MainServer.OnServerNotify)
end


--消息回调 (优化版本，使用命令表和错误处理)
function MainServer.OnServerNotify(uin_, args)
    if type(args) ~= 'table' then return end
    if not args.cmd then return end

    local player_ = serverDataMgr.getPlayerByUin(uin_)
    args.player = player_
    if args.__cb then
        args.Return = function(returnData)
            gg.network_channel:fireClient(uin_, {
                cmd = args.__cb .. "_Return",
                data = returnData
            })
        end
    end
    ServerEventManager.Publish(args.cmd, args)
    return

end

--开启update
function MainServer.bind_update_tick()
    -- 一个定时器, 实现tick update
    local timer = SandboxNode.New("Timer", game.WorkSpace)
    timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE

    timer.Name = 'timer_server'
    timer.Delay = 0.1      -- 延迟多少秒开始
    timer.Loop = true      -- 是否循环
    timer.Interval = 0.03   -- 循环间隔多少秒 (1秒=20帧)
    timer.Callback = MainServer.update
    timer:Start()     -- 启动定时器
    gg.timer = timer;
end

--定时器update
function MainServer.update()
    serverDataMgr.tick = serverDataMgr.tick + 1

    -- 更新场景的逻辑已移至 SceneControllerHandler:OnUpdate()
    -- for _, scene_ in pairs(serverDataMgr.getAllScenes()) do
    --     scene_:update()
    -- end
    
    -- 更新调度器（按秒为单位，而不是每tick）
    ServerScheduler.tick = serverDataMgr.tick
    if ServerScheduler.updateTiming() then
        ServerScheduler.update()
    end
end

return MainServer;
