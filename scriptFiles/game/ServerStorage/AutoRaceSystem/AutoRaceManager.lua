local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local VectorUtils = require(MainStorage.Code.Untils.VectorUtils) ---@type VectorUtils
local Vec = VectorUtils.Vec
local GameModeManager = require(ServerStorage.GameModes.GameModeManager) ---@type GameModeManager
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask

---@class AutoRaceManager
local AutoRaceManager = {}

-- 存储玩家自动比赛状态
local playerAutoRaceState = {}
-- 【新增】存储玩家位置历史（用于检测卡顿）
local playerPositionHistory = {}
-- 自动比赛检查定时器
local autoRaceCheckTimer = nil

-- 初始化自动比赛管理器
function AutoRaceManager.Init()
    -- 启动定时检查
    AutoRaceManager.StartAutoRaceCheck()
end

-- 【新增】检测玩家是否卡住（最近3次位置变化均小于阈值）
---@param player MPlayer 玩家对象
---@return boolean 是否卡住
function AutoRaceManager.CheckPlayerStuck(player)
    if not player or not player.actor then return false end

    local uin = player.uin
    local currentPos = player.actor.Position

    if not playerPositionHistory[uin] then
        playerPositionHistory[uin] = {}
    end

    local history = playerPositionHistory[uin]
    table.insert(history, currentPos)

    -- 只保留最近3次位置记录
    if #history > 3 then
        table.remove(history, 1)
    end

    if #history < 3 then
        return false
    end

    local threshold = 2.0
    local pos1, pos2, pos3 = history[1], history[2], history[3]
    local thrSq = threshold * threshold
    local dist12Sq = Vec.DistanceSq3(pos1, pos2)
    local dist23Sq = Vec.DistanceSq3(pos2, pos3)
    local dist13Sq = Vec.DistanceSq3(pos1, pos3)

    if dist12Sq < thrSq and dist23Sq < thrSq and dist13Sq < thrSq then
        return true
    end

    return false
end

-- 【新增】获取比赛目标位置
---@param player MPlayer 玩家对象
---@return Vector3|nil 目标位置
function AutoRaceManager.GetRaceTargetPosition(player)
    if not player then return nil end

    local currentScene = player.currentScene
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local raceNodes = ConfigLoader.GetSceneNodesBy(currentScene, "飞行比赛")

    if #raceNodes == 0 then
        return nil
    end

    local raceNode = raceNodes[1]
    local sceneNode = gg.GetChild(game.WorkSpace, raceNode.nodePath)
    if not sceneNode then
        return nil
    end

    local navNodeName = raceNode.areaConfig["导航节点"]
    if not navNodeName or navNodeName == "" then
        return nil
    end

    local navNode = sceneNode[navNodeName]
    if not navNode then
        return nil
    end

    return navNode.Position
end

-- 【新增】传送玩家到目标比赛点
---@param player MPlayer 玩家对象
---@param targetPosition Vector3 目标位置
function AutoRaceManager.TeleportPlayerToRaceTarget(player, targetPosition)
    if not player or not targetPosition then return end

    local actor = player.actor
    if not actor then
        gg.log("玩家无actor对象，传送失败")
        return
    end

    local TeleportService = game:GetService('TeleportService')
    local success, err = pcall(function()
        TeleportService:Teleport(actor, targetPosition)
    end)

    if success then
        gg.log("玩家", player.uin, "被传送到目标位置（解除卡顿）")
        playerPositionHistory[player.uin] = nil
    else
        gg.log("传送失败:", tostring(err))
    end
end

-- 启动自动比赛检查定时器
function AutoRaceManager.StartAutoRaceCheck()
    if autoRaceCheckTimer then
        ScheduledTask.Remove(autoRaceCheckTimer)
    end
    
    autoRaceCheckTimer = ScheduledTask.AddInterval(5, "AutoRaceCheck", function()
        AutoRaceManager.CheckAllPlayersAutoRace()
    end)
    
end

-- 检查所有玩家的自动比赛状态
function AutoRaceManager.CheckAllPlayersAutoRace()
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    
    
    -- 检查是否有启用自动比赛的玩家
    local hasEnabledPlayers = false
    for uin, enabled in pairs(playerAutoRaceState) do
        if enabled then
            hasEnabledPlayers = true
            break
        end
    end
    
    -- 如果没有启用自动比赛的玩家，直接返回
    if not hasEnabledPlayers then
        return
    end
    
    -- 只检查按下了自动比赛按钮的玩家
    for uin, enabled in pairs(playerAutoRaceState) do
        if enabled then  -- 只处理启用了自动比赛的玩家
            local player = MServerDataManager.getPlayerByUin(uin)
            if player then
                -- 新增：若玩家标注在某模式实例中，直接跳过
                if player.currentGameModeInstanceId then
                    gg.log(string.format("玩家 %d 当前在模式实例 %s 中，跳过自动导航", uin, tostring(player.currentGameModeInstanceId)))
                else
                    -- 检查玩家是否在比赛中（直接检查playerModes）
                    local isInRace = GameModeManager.playerModes[uin] ~= nil
                    if not isInRace then
                        -- 【新增】优先检测卡顿并尝试传送
                        if AutoRaceManager.CheckPlayerStuck(player) then
                            gg.log("检测到玩家", uin, "卡住，尝试传送到目标位置")
                            local targetPosition = AutoRaceManager.GetRaceTargetPosition(player)
                            if targetPosition then
                                AutoRaceManager.TeleportPlayerToRaceTarget(player, targetPosition)
                            else
                                gg.log("无法获取比赛目标位置，跳过传送")
                            end
                        else
                            -- 玩家不在比赛中且未卡住，重新启动自动比赛
                            AutoRaceManager.StartAutoRace(player)
                        end
                    end
                end
            else
                -- 玩家不存在，清除状态
                playerAutoRaceState[uin] = nil
                -- 【新增】清理位置历史
                playerPositionHistory[uin] = nil
            end
        end
    end
end

-- 启动自动比赛
---@param mPlayer MPlayer 玩家实例
function AutoRaceManager.StartAutoRace(mPlayer)
    if not mPlayer then return end
    
    local uin = mPlayer.uin
    
    -- 检查玩家是否已在比赛中（直接检查playerModes）
    if GameModeManager.playerModes[uin] ~= nil then
        return
    end
    

    -- 查找当前玩家所在场景的飞行比赛节点
    local currentScene = mPlayer.currentScene 
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local raceNodes = ConfigLoader.GetSceneNodesBy(currentScene, "飞行比赛")
    gg.log("raceNodes",raceNodes)
    if #raceNodes == 0 then
        gg.log("未找到可用的飞行比赛节点，所属场景:", tostring(currentScene))
        return
    end
    
    -- 选择第一个比赛节点
    local raceNode = raceNodes[1]
    local nodePath = raceNode.nodePath
    gg.log("nodePath", nodePath,raceNodes)
    -- 解析节点路径，获取场景节点
    local sceneNode = gg.GetChild(game.WorkSpace, nodePath)
    if not sceneNode then
        gg.log("无法找到比赛节点:", nodePath)
        return
    end
    
    -- 获取导航节点位置
    local navNodeName = raceNode.areaConfig["导航节点"]
    if not navNodeName or navNodeName == "" then
        gg.log("比赛节点没有配置导航节点:", nodePath)
        return
    end
    
    -- 查找导航节点
    local navNode = sceneNode[navNodeName]
    if not navNode then
        gg.log("无法找到导航节点:", navNodeName)
        return
    end
    
    -- 通过事件管理器发送导航指令到客户端
    local targetPosition = navNode.Position
    gg.log("targetPosition",targetPosition,navNode)
    local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
    AutoRaceEventManager.SendNavigateToPosition(uin, targetPosition, "自动导航到比赛节点位置")
    
    gg.log("已发送导航指令给玩家", uin, "，目标位置:", tostring(targetPosition))
end

-- 停止自动比赛
---@param mPlayer MPlayer 玩家实例
function AutoRaceManager.StopAutoRace(mPlayer)
    if not mPlayer then return end
    
    local uin = mPlayer.uin
    -- 确保完全清理状态
    playerAutoRaceState[uin] = nil
    -- 【新增】清理位置历史
    playerPositionHistory[uin] = nil
    
    -- 向客户端发送停止导航指令
    local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
    AutoRaceEventManager.SendStopNavigation(uin, "自动比赛已停止，停止导航")
    
    gg.log("已停止玩家", uin, "的自动比赛")
end

-- 设置玩家自动比赛状态
---@param mPlayer MPlayer 玩家实例
---@param enabled boolean 是否启用自动比赛
function AutoRaceManager.SetPlayerAutoRaceState(mPlayer, enabled)
    if not mPlayer then return end
    
    local uin = mPlayer.uin
    if enabled then
        playerAutoRaceState[uin] = true
        -- 立即启动一次自动比赛
        AutoRaceManager.StartAutoRace(mPlayer)
    else
        -- 确保完全清理状态
        playerAutoRaceState[uin] = nil
        -- 【新增】清理位置历史
        playerPositionHistory[uin] = nil
        
        -- 停止导航
        local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
        AutoRaceEventManager.SendStopNavigation(uin, "自动比赛已停止，停止导航")
    end
end

-- 检查玩家是否在自动比赛中
---@param player MPlayer 玩家实例
---@return boolean 是否在自动比赛中
function AutoRaceManager.IsPlayerAutoRacing(player)
    if not player then return false end
    return playerAutoRaceState[player.uin] == true
end

--- 【新增】为特定玩家停止自动比赛
---@param player MPlayer 玩家对象
---@param reason string 停止原因
function AutoRaceManager.StopAutoRaceForPlayer(player, reason)
    if not player then return end

 
    -- 1. 更新状态
    AutoRaceManager.SetPlayerAutoRaceState(player, false)
    
    -- 2. 发送通知到客户端
    local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
    AutoRaceEventManager.NotifyAutoRaceStopped(player, reason or "自动比赛已停止")
    
    gg.log("玩家", player.uin, "已停止自动比赛，原因:", reason)

end


---@param uin number 玩家UIN
function AutoRaceManager.CleanupPlayerAutoRaceState(uin)
    if not uin then return end
    
    if playerAutoRaceState[uin] then
        playerAutoRaceState[uin] = nil
        gg.log("清理玩家自动比赛状态:", uin)
    end
    -- 【新增】同时清理位置历史
    playerPositionHistory[uin] = nil
end


return AutoRaceManager