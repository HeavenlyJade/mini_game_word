local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class RaceGameEventManager
local RaceGameEventManager = {}

--- 初始化
function RaceGameEventManager.Init()
    RaceGameEventManager.RegisterEventHandlers()
end

--- 注册事件处理器
function RaceGameEventManager.RegisterEventHandlers()
    local eventName = EventPlayerConfig.REQUEST.PLAYER_LANDED
    if not eventName then
        gg.log("ERROR: RaceGameEventManager - 找不到玩家落地事件定义 (PLAYER_LANDED)。")
        return
    end

    ServerEventManager.Subscribe(eventName, RaceGameEventManager.HandlePlayerLanded)
    gg.log("已注册 RaceGame 相关的事件处理器。")
end

--- 处理玩家落地事件
---@param evt table { player: MPlayer, cmd: string }
function RaceGameEventManager.HandlePlayerLanded(evt)
    local player = evt.player
    if not player then return end

    -- 【关键】通过 MServerDataManager 获取 GameModeManager 的正确实例
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager ---@type GameModeManager
    if not GameModeManager then
        gg.log("ERROR: RaceGameEventManager - GameModeManager 未在 serverDataMgr 中初始化。")
        return
    end

    -- 1. 从 GameModeManager 获取该玩家当前所在的游戏模式实例
    local instanceId = GameModeManager.playerModes[player.uin]
    if not instanceId then
        -- 如果玩家不在任何模式中，直接忽略
        return
    end
    local currentMode = GameModeManager.activeModes[instanceId]

    -- 如果玩家在模式中，并且模式有OnPlayerLanded方法，则直接调用
    if currentMode and type(currentMode.OnPlayerLanded) == "function" then
        -- 移除不必要的ClassName检查，因为此管理器专用于RaceGame
        gg.log(string.format("RaceEventManager: 收到玩家 %s 的落地报告，转发给比赛实例 %s", player.name, currentMode.instanceId))
        -- 3. 调用该【具体实例】的 OnPlayerLanded 方法
        currentMode:OnPlayerLanded(player)
    else
        -- 仅在调试时打印，正常游戏时此日志可能过于频繁
        -- gg.log(string.format("RaceEventManager: 收到玩家 %s 的落地报告，但玩家不在比赛中或模式不匹配，忽略。", player.name))
    end
end

return RaceGameEventManager