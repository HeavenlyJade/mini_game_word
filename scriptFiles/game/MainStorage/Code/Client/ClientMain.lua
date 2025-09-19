local MainStorage     = game:GetService("MainStorage")
local game            = game
local Enum            = Enum  ---@type Enum
local MS              = require(MainStorage.Code.Untils.MS) ---@type MS
local gg              = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClassMgr    = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local Controller = require(MainStorage.Code.Client.MController) ---@type Controller
---@class ClientMain
local ClientMain = ClassMgr.Class("ClientMain")

--- 新增：初始化数据系统
function ClientMain.InitDataSystems()
    local PlayerDataManager = require(MainStorage.Code.Client.PlayerData.PlayerDataManager)
    PlayerDataManager:Init()
    --gg.log("玩家数据系统初始化完成")
end

--- 新增：专门用于初始化所有“动作处理器”模块的函数
function ClientMain.InitActionHandlers()
    -- 初始化玩家操作处理器
    local PlayerActionHandler = require(MainStorage.Code.Client.PlayerAction.PlayerActionHandler)
    PlayerActionHandler:OnInit()

    -- 以后若有其他动作处理器，可在此处继续添加
    -- local OtherActionHandler = require(...)
    -- OtherActionHandler:OnInit()
end

function ClientMain.start_client()
    ConfigLoader.Init()
    -- 【新增】初始化客户端的全局任务调度器
    local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask
    ScheduledTask.Init()

    gg.isServer = false
    ClientMain.tick = 0
    gg.uuid_start = gg.rand_int_between(100000, 999999);
    ClientMain.createNetworkChannel()
    ClientMain.handleCoreUISettings()
    Controller.init()
    ClientMain.InitActionHandlers() -- 初始化所有动作处理器
    ClientMain.InitDataSystems() -- 初始化数据系统
    do
        -- 显式注册玩家数据相关的服务端事件（防御性调用）
        local PlayerDataManager = require(MainStorage.Code.Client.PlayerData.PlayerDataManager)
        PlayerDataManager:SubscribeServerEvents()
    end

    local timer = SandboxNode.New("Timer", game.StarterGui)
    timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE

    require(MainStorage.Code.Client.Graphic.ShopManagerClient) -- 加载客户端的商城管理

    require(MainStorage.Code.Client.Graphic.DamagePool)
    require(MainStorage.Code.Client.Graphic.WorldTextAnim)
    -- 加载并初始化音效池管理
    local SoundPool = require(MainStorage.Code.Client.Graphic.SoundPool) ---@type SoundPool
    SoundPool.Init()
    


    -- 导入并初始化挂机区域节点配置
    local InitAutoSpotNodes = require(MainStorage.Code.Client.SceneNode.InitAutoSpotNodes) ---@type InitAutoSpotNodes
    InitAutoSpotNodes.InitializeAllAutoSpotNodes()

    -- 导入并初始化地图背景音乐
    local MapBackgroundMusic = require(MainStorage.Code.Client.SceneNode.MapBackgroundMusic) ---@type MapBackgroundMusic
    MapBackgroundMusic.InitializeBackgroundMusic()

    -- 导入并初始化关卡奖励节点器
    local LevelRewardNodeInitializer = require(MainStorage.Code.Client.SceneNode.LevelRewardNodeInitializer) ---@type LevelRewardNodeInitializer
    LevelRewardNodeInitializer.InitializeAllLevelRewardNodes()

    ClientEventManager.Subscribe("FetchAnimDuration", function (evt)
        local animator = gg.GetChild(game:GetService("WorkSpace"), evt.path) ---@cast animator Animator
        if animator then
            for stateId, _ in pairs(evt.states) do
                local fullState = string.format("Base Layer.%s", stateId)
                local playTimeByStr = animator:GetClipLength(fullState)
                evt.states[stateId] = playTimeByStr
            end

            evt.Return(evt.states)
        end
    end)

    if game.RunService:IsPC() then
        game.MouseService:SetMode(1)
    end
    -- 导入并初始化赛道系统
    local RaceTrack = require(MainStorage.Code.Client.SceneNode.RaceTrack) ---@type RaceTrack
    RaceTrack.InitializeRaceTrack()

end



function ClientMain.createNetworkChannel()
    gg.network_channel = MainStorage:WaitForChild("NetworkChannel") ---@type NetworkChannel
    --gg.log("gg.network_channel",gg.network_channel,gg.network_channel.OnClientNotify)
    gg.network_channel.OnClientNotify:Connect(ClientMain.OnClientNotify)

    gg.network_channel:FireServer({ cmd = 'cmd_heartbeat', msg = 'new_client_join' })

    --gg.log('网络通道建立结束')
end

--  通过CoreUI 屏蔽默认的按钮组件
function ClientMain.handleCoreUISettings()
    -- local CoreUI = game:GetService("CoreUI")
    -- CoreUI:HideCoreUi(Enum.CoreUiComponent.All )

end



function ClientMain.OnClientNotify(args)
    if type(args) ~= 'table' then return end
    if not args.cmd then return end
    if args.__cb then
        args.Return = function(returnData)
            gg.network_channel:FireServer({
                cmd = args.__cb .. "_Return",
                data = returnData
            })
        end
    end
    ClientEventManager.Publish(args.cmd, args)
end

return ClientMain

