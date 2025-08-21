local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local SceneNodeType = require(MainStorage.Code.Common.TypeConfig.SceneNodeType) ---@type SceneNodeType
local GameModeManager = require(ServerStorage.GameModes.GameModeManager) ---@type GameModeManager
local TeleportService = game:GetService("TeleportService")
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask

---@class AutoRaceManager
local AutoRaceManager = {}

-- 存储玩家自动比赛状态
local playerAutoRaceState = {}
-- 自动比赛检查定时器
local autoRaceCheckTimer = nil

-- 初始化自动比赛管理器
function AutoRaceManager.Init()
    -- 启动定时检查
    AutoRaceManager.StartAutoRaceCheck()
end

-- 启动自动比赛检查定时器
function AutoRaceManager.StartAutoRaceCheck()
    if autoRaceCheckTimer then
        ScheduledTask.Remove(autoRaceCheckTimer)
    end
    
    autoRaceCheckTimer = ScheduledTask.AddInterval(3, "AutoRaceCheck", function()
        AutoRaceManager.CheckAllPlayersAutoRace()
    end)
    
    --gg.log("自动比赛检查定时器已启动，每5秒检查一次")
end

-- 检查所有玩家的自动比赛状态
function AutoRaceManager.CheckAllPlayersAutoRace()
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    
    --gg.log("playerAutoRaceState", playerAutoRaceState)
    
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
                -- 检查玩家是否在比赛中（直接检查playerModes）
                local isInRace = GameModeManager.playerModes[uin] ~= nil
                if not isInRace then
                    -- 玩家不在比赛中，重新启动自动比赛
                    AutoRaceManager.StartAutoRace(player)
                end
            else
                -- 玩家不存在，清除状态
                playerAutoRaceState[uin] = nil
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
    --gg.log("raceNodes",raceNodes)
    if #raceNodes == 0 then
        --gg.log("未找到可用的飞行比赛节点，所属场景:", tostring(currentScene))
        return
    end
    
    -- 选择第一个比赛节点
    local raceNode = raceNodes[1]
    local nodePath = raceNode.nodePath
    --gg.log("nodePath", nodePath,raceNodes)
    -- 解析节点路径，获取场景节点
    local sceneNode = gg.GetChild(game.WorkSpace, nodePath)
    if not sceneNode then
        --gg.log("无法找到比赛节点:", nodePath)
        return
    end
    
    -- 获取导航节点位置
    local navNodeName = raceNode.areaConfig["导航节点"]
    if not navNodeName or navNodeName == "" then
        --gg.log("比赛节点没有配置导航节点:", nodePath)
        return
    end
    
    -- 查找导航节点
    local navNode = sceneNode[navNodeName]
    if not navNode then
        --gg.log("无法找到导航节点:", navNodeName)
        return
    end
    
    -- 通过事件管理器发送导航指令到客户端
    local targetPosition = navNode.Position
    --gg.log("targetPosition",targetPosition,navNode)
    local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
    AutoRaceEventManager.SendNavigateToPosition(uin, targetPosition, "自动导航到比赛节点位置")
    
    --gg.log("已发送导航指令给玩家", uin, "，目标位置:", tostring(targetPosition))
end

-- 停止自动比赛
---@param mPlayer MPlayer 玩家实例
function AutoRaceManager.StopAutoRace(mPlayer)
    if not mPlayer then return end
    
    local uin = mPlayer.uin
    -- 确保完全清理状态
    playerAutoRaceState[uin] = nil
    
    -- 向客户端发送停止导航指令
    local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
    AutoRaceEventManager.SendStopNavigation(uin, "自动比赛已停止，停止导航")
    
    --gg.log("已停止玩家", uin, "的自动比赛")
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

return AutoRaceManager