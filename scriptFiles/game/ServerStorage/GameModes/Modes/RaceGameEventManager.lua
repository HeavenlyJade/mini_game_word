local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class RaceGameEventManager
local RaceGameEventManager = {
}

--- 初始化
function RaceGameEventManager.Init()

    
    RaceGameEventManager.RegisterEventHandlers()
    gg.log("RaceGameEventManager 初始化完成")
end

--- 注册事件处理器
function RaceGameEventManager.RegisterEventHandlers()
    -- 注册玩家落地事件

    ServerEventManager.Subscribe(EventPlayerConfig.REQUEST.PLAYER_LANDED, RaceGameEventManager.HandlePlayerLanded)

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
        --gg.log("ERROR: RaceGameEventManager - GameModeManager 未在 serverDataMgr 中初始化。")
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
        --gg.log(string.format("RaceEventManager: 收到玩家 %s 的落地报告，转发给比赛实例 %s", player.name, currentMode.instanceId))
        -- 3. 调用该【具体实例】的 OnPlayerLanded 方法
        currentMode:OnPlayerLanded(player)
    else
        -- 仅在调试时打印，正常游戏时此日志可能过于频繁
        -- --gg.log(string.format("RaceEventManager: 收到玩家 %s 的落地报告，但玩家不在比赛中或模式不匹配，忽略。", player.name))
    end
end

--- 【新增】向指定玩家发送比赛开始通知
---@param player MPlayer 目标玩家
---@param raceTime number 比赛时长
function RaceGameEventManager.SendRaceStartNotification(player, raceTime)
    if not player or not player.uin then return end
    
    if not gg.network_channel then
        gg.log("警告: RaceGameEventManager - 网络通道未初始化，无法发送比赛开始通知")
        return
    end
    
    local eventData = {
        cmd = EventPlayerConfig.NOTIFY.RACE_CONTEST_SHOW,
        gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME,
        raceTime = raceTime or 60
    }
    
    gg.network_channel:fireClient(player.uin, eventData)
    gg.log(string.format("RaceGameEventManager: 已向玩家 %s 发送比赛开始通知", player.name or player.uin))
end

--- 【新增】向指定玩家发送比赛结束通知
---@param player MPlayer 目标玩家
function RaceGameEventManager.SendRaceEndNotification(player)
    if not player or not player.uin then return end
    
    if not gg.network_channel then
        gg.log("警告: RaceGameEventManager - 网络通道未初始化，无法发送比赛结束通知")
        return
    end
    
    local eventData = {
        cmd = EventPlayerConfig.NOTIFY.RACE_CONTEST_HIDE,
        gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME
    }
    
    gg.network_channel:fireClient(player.uin, eventData)
    gg.log(string.format("RaceGameEventManager: 已向玩家 %s 发送比赛结束通知", player.name or player.uin))
end

--- 【新增】向指定玩家发送比赛数据更新
---@param player MPlayer 目标玩家
---@param raceData table 比赛数据 {raceTime, elapsedTime, remainingTime, topThree, totalPlayers}
function RaceGameEventManager.SendRaceDataUpdate(player, raceData)
    if not player or not player.uin then return end
    if not raceData then return end
    
    if not gg.network_channel then
        gg.log("警告: RaceGameEventManager - 网络通道未初始化，无法发送比赛数据更新")
        return
    end
    
    local eventData = {
        cmd = EventPlayerConfig.NOTIFY.RACE_CONTEST_UPDATE,
        gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME,
        raceTime = raceData.raceTime,
        elapsedTime = raceData.elapsedTime,
        remainingTime = raceData.remainingTime,
        topThree = raceData.topThree,
        totalPlayers = raceData.totalPlayers
    }
    
    gg.network_channel:fireClient(player.uin, eventData)
end

--- 【修改】向所有在线玩家广播比赛准备倒计时（不仅仅是参赛者）
---@param participants MPlayer[] 参赛者列表（用于记录日志）
---@param prepareTime number 准备时间
function RaceGameEventManager.BroadcastPrepareCountdown(participants, prepareTime)
    if not prepareTime then return end
    
    if not gg.network_channel then
        gg.log("警告: RaceGameEventManager - 网络通道未初始化，无法广播准备倒计时")
        return
    end
    
    -- 【核心修改】从MServerDataManager获取所有在线玩家，向所有玩家发送倒计时
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local allPlayers = serverDataMgr.getAllPlayers()
    
    local successCount = 0
    local totalPlayers = 0
    
    -- 向所有在线玩家发送倒计时事件
    for uin, player in pairs(allPlayers) do
        if player and player.uin then
            -- 【新增】为每个玩家创建包含场景信息的个性化事件数据
            local playerEventData = {
                cmd = EventPlayerConfig.NOTIFY.RACE_PREPARE_COUNTDOWN,
                gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME,
                prepareTime = prepareTime,
                -- 【新增】包含玩家当前场景信息
                playerScene = player.currentScene or "init_map"
            }
            
            gg.network_channel:fireClient(player.uin, playerEventData)
            successCount = successCount + 1
        end
        totalPlayers = totalPlayers + 1
    end
    
    --gg.log(string.format("RaceGameEventManager: 已向 %d/%d 名在线玩家广播准备倒计时事件，准备时间: %d秒，参赛者数量: %d", 
    --                    successCount, totalPlayers, prepareTime, participants and #participants or 0))
end

--- 【新增】向指定玩家发送停止准备倒计时事件
---@param player MPlayer 目标玩家
---@param reason string 停止原因（可选）
function RaceGameEventManager.SendStopPrepareCountdown(player, reason)
    if not player or not player.uin then return end
    
    if not gg.network_channel then
        gg.log("警告: RaceGameEventManager - 网络通道未初始化，无法发送停止准备倒计时")
        return
    end
    
    local eventData = {
        cmd = EventPlayerConfig.NOTIFY.RACE_PREPARE_COUNTDOWN_STOP,
        gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME,
        reason = reason or "退出准备区域"
    }
    
    gg.network_channel:fireClient(player.uin, eventData)
    --gg.log(string.format("RaceGameEventManager: 已向玩家 %s 发送停止准备倒计时事件，原因: %s", player.name or player.uin, reason or "退出准备区域"))
end

--- 【修改】向所有在线玩家广播停止准备倒计时事件（不仅仅是参赛者）
---@param participants MPlayer[] 参赛者列表（用于记录日志）
---@param reason string 停止原因（可选）
function RaceGameEventManager.BroadcastStopPrepareCountdown(participants, reason)
    if not gg.network_channel then
        gg.log("警告: RaceGameEventManager - 网络通道未初始化，无法广播停止准备倒计时")
        return
    end
    
    local eventData = {
        cmd = EventPlayerConfig.NOTIFY.RACE_PREPARE_COUNTDOWN_STOP,
        gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME,
        reason = reason or "比赛已取消"
    }
    
    -- 【核心修改】从MServerDataManager获取所有在线玩家，向所有玩家发送停止倒计时
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local allPlayers = serverDataMgr.getAllPlayers()
    
    local successCount = 0
    local totalPlayers = 0
    
    -- 向所有在线玩家发送停止倒计时事件
    for uin, player in pairs(allPlayers) do
        if player and player.uin then
            gg.network_channel:fireClient(player.uin, eventData)
            successCount = successCount + 1
        end
        totalPlayers = totalPlayers + 1
    end
    
    --gg.log(string.format("RaceGameEventManager: 已向 %d/%d 名在线玩家广播停止准备倒计时事件，原因: %s，参赛者数量: %d", 
    --                     successCount, totalPlayers, reason or "比赛已取消", participants and #participants or 0))
end

--- 【新增】向所有参赛者广播比赛事件
---@param participants MPlayer[] 参赛者列表
---@param eventType string 事件类型 (RACE_CONTEST_SHOW, RACE_CONTEST_HIDE, RACE_CONTEST_UPDATE)
---@param eventData table 事件数据
function RaceGameEventManager.BroadcastRaceEvent(participants, eventType, eventData)
    if not participants or #participants == 0 then return end
    if not eventType then return end
    
    if not gg.network_channel then
        gg.log("警告: RaceGameEventManager - 网络通道未初始化，无法广播比赛事件")
        return
    end
    
    -- 确保事件数据包含必要的字段
    local finalEventData = {
        cmd = eventType,
        gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME
    }
    
    -- 合并传入的事件数据
    if eventData then
        for k, v in pairs(eventData) do
            finalEventData[k] = v
        end
    end
    
    -- 向所有参赛者发送事件
    local successCount = 0
    for _, player in ipairs(participants) do
        if player and player.uin then
            gg.network_channel:fireClient(player.uin, finalEventData)
            successCount = successCount + 1
        end
    end
    
    -- gg.log(string.format("RaceGameEventManager: 已向 %d/%d 名参赛者广播 %s 事件", 
    --                     successCount, #participants, eventType))
end

return RaceGameEventManager
