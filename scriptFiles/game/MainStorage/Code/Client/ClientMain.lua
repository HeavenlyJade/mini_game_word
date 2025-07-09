
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
function ClientMain.start_client()
    ConfigLoader.Init() 
    gg.isServer = false
    ClientMain.tick = 0
    gg.uuid_start = gg.rand_int_between(100000, 999999);
    ClientMain.createNetworkChannel()
    ClientMain.handleCoreUISettings()
    Controller.init()
    local timer = SandboxNode.New("Timer", game.StarterGui)
    timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE


    require(MainStorage.Code.Client.Graphic.DamagePool)
    require(MainStorage.Code.Client.Graphic.WorldTextAnim)
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
    ClientEventManager.Subscribe("Race_LaunchPlayer", function(data)
        gg.log("接收到 Race_LaunchPlayer 事件，准备执行发射！")
        local localPlayer = game:GetService("Players").LocalPlayer
        if localPlayer and localPlayer.Character then
            local actor = localPlayer.Character
            
            -- 在客户端执行跳跃和移动指令
            actor:Jump(true)
            actor:Move(Vector3.new(0, 0, 1), true)
            
            -- 动作执行后，客户端也需要一个机制来停止持续的Move指令
            -- 这里的恢复逻辑主要在服务器端，但客户端可以停止移动以防止意外行为
            local timer = actor:GetComponent("Timer") or actor:AddComponent("Timer")
            timer:AddDelay(0.5, function()
                if actor and not actor.isDestroyed then
                    actor:StopMove()
                end
            end)
        else
            gg.log("Race_LaunchPlayer: 找不到本地玩家或其角色。")
        end
    end)
    if game.RunService:IsPC() then
        game.MouseService:SetMode(1)
    end
    local plugins = MainStorage.Code.plugins
    if plugins then
        for _, child in pairs(plugins.Children) do
            if child and child.PluginMain then
                local plugin = require(child.PluginMain)
                if plugin.StartClient then
                    plugin.StartClient()
                end
            end
        end
    end

end



function ClientMain.createNetworkChannel()
    gg.network_channel = MainStorage:WaitForChild("NetworkChannel") ---@type NetworkChannel
    gg.log("gg.network_channel",gg.network_channel,gg.network_channel.OnClientNotify)
    gg.network_channel.OnClientNotify:Connect(ClientMain.OnClientNotify)

    gg.network_channel:FireServer({ cmd = 'cmd_heartbeat', msg = 'new_client_join' })

    gg.log('网络通道建立结束')
end

--  通过CoreUI 屏蔽默认的按钮组件
function ClientMain.handleCoreUISettings()
    local CoreUI = game:GetService("CoreUI")
    CoreUI:HideCoreUi(Enum.CoreUiComponent.All )

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

