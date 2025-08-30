-- AutoPlayManager.lua
-- 自动挂机管理器 - 修改为直接传送模式

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local SceneNodeType = require(MainStorage.Code.Common.TypeConfig.SceneNodeType) ---@type SceneNodeType
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask
local ActionCosteRewardCal = require(MainStorage.Code.GameReward.RewardCalc.ActionCosteRewardCal) ---@type ActionCosteRewardCal

---@class AutoPlayManager
local AutoPlayManager = {}

-- 存储玩家自动挂机状态
local playerAutoPlayState = {}

-- 初始化自动挂机管理器
function AutoPlayManager.Init()
    -- 启动定时检查
    AutoPlayManager.StartAutoPlayCheck()
end

-- 启动自动挂机检查定时器
function AutoPlayManager.StartAutoPlayCheck()
    local timer = ScheduledTask.AddInterval(5, "AutoPlayCheck", function()
        AutoPlayManager.CheckAllPlayersAutoPlay()
    end)
    
    gg.log("自动挂机检查定时器已启动，每5秒检查一次")
end

-- 检查所有玩家的自动挂机状态
function AutoPlayManager.CheckAllPlayersAutoPlay()
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    
    -- 检查是否有启用自动挂机的玩家
    local hasEnabledPlayers = false
    for uin, enabled in pairs(playerAutoPlayState) do
        if enabled then
            hasEnabledPlayers = true
            break
        end
    end
    
    -- 如果没有启用自动挂机的玩家，直接返回
    if not hasEnabledPlayers then
        return
    end
    
    -- 检查启用了自动挂机的玩家
    for uin, enabled in pairs(playerAutoPlayState) do
        if enabled then
            local player = MServerDataManager.getPlayerByUin(uin)
            if player then
                -- 检查玩家是否在挂机点
                local isInSpot = AutoPlayManager.IsPlayerInAutoPlaySpot(player)
                local currentSpot = player:GetCurrentIdleSpot()
                
                -- gg.log(string.format("玩家 %s (UIN: %s) 自动挂机检查 - 挂机状态: %s, 当前挂机点: %s", 
                --     player.name, uin, tostring(isInSpot), currentSpot and currentSpot.name or "无"))
                
                -- 如果玩家不在挂机点，重新寻找并传送到最佳挂机点
                if not isInSpot then
                    AutoPlayManager.FindAndTeleportToBestAutoPlaySpot(player)
                end
            end
        end
    end
end

-- 检查玩家是否在挂机点内
---@param player MPlayer 玩家对象
---@return boolean 是否在挂机点内
function AutoPlayManager.IsPlayerInAutoPlaySpot(player)
    if not player or not player.actor then
        return false
    end
    
    local currentSpot = player:GetCurrentIdleSpot()
    return currentSpot ~= nil
end

-- 寻找并传送到最佳挂机点
---@param player MPlayer 玩家对象
function AutoPlayManager.FindAndTeleportToBestAutoPlaySpot(player)
    if not player then return end
    
    local bestSpot = AutoPlayManager.FindBestAutoPlaySpot(player)
    if bestSpot then
        AutoPlayManager.TeleportPlayerToAutoPlaySpot(player, bestSpot)
    else
        gg.log("玩家", player.uin, "找不到合适的挂机点")
    end
end

-- 寻找最佳挂机点
---@param player MPlayer 玩家对象
---@return SceneNodeType|nil 最佳挂机点
function AutoPlayManager.FindBestAutoPlaySpot(player)
    if not player then return nil end
    
    local autoPlaySpots = AutoPlayManager.GetAllAutoPlaySpots(player.currentScene)
    if not autoPlaySpots or #autoPlaySpots == 0 then
        return nil
    end
    
    local bestSpot = nil
    local bestEfficiency = -1
    
    for _, spot in ipairs(autoPlaySpots) do
        if AutoPlayManager.CanPlayerUseSpot(spot, player) then
            local efficiency = AutoPlayManager.CalculateEfficiency(spot, player)
            if efficiency > bestEfficiency then
                bestEfficiency = efficiency
                bestSpot = spot
            end
        end
    end
    
    return bestSpot
end

-- 获取所有自动挂机点（可按场景过滤）
---@param belongScene string|nil 所属场景，可为nil表示不过滤
---@return SceneNodeType[] 挂机点列表
function AutoPlayManager.GetAllAutoPlaySpots(belongScene)
    return ConfigLoader.GetSceneNodesBy(belongScene, "挂机点")
end

-- 检查玩家是否可以使用挂机点
function AutoPlayManager.CanPlayerUseSpot(spot, player)
    if not spot or not player then return false end
    
    local playerData = player.variableSystem:GetVariablesDictionary()
    local bagData = player.bagMgr
    -- gg.log("playerData1111",playerData)
    local canEnter, message = spot:CheckVariableCondition(playerData, bagData, nil)
    -- gg.log("canEnter, messag",canEnter, message)
    return canEnter
end

-- 计算挂机效率（直接使用配置的"作数值的配置"）
---@param node SceneNodeType 挂机点节点
---@param player MPlayer 玩家对象
---@return number 挂机效率
function AutoPlayManager.CalculateEfficiency(node, player)
    local value = (node and node.effectValueConfig) or 0
    return tonumber(value) or 0
end

-- 【新增】直接传送玩家到挂机点
---@param player MPlayer 玩家对象
---@param spot SceneNodeType 挂机点
function AutoPlayManager.TeleportPlayerToAutoPlaySpot(player, spot)
    if not player or not spot then return end
    
    local uin = player.uin
    
    -- 获取挂机点的传送位置
    local targetPosition = AutoPlayManager.GetSpotTeleportPosition(spot)
    if not targetPosition then
        gg.log("无法获取挂机点传送位置:", spot.name)
        return
    end
    
    -- 服务端直接传送玩家
    if not player.actor then
        gg.log("无法传送：玩家无有效的actor")
        return
    end
    AutoPlayManager.ExecuteTeleport(player, targetPosition)
    gg.log("已将玩家", uin, "直接传送到挂机点:", spot.name)
end

-- 【新增】获取挂机点的传送位置
---@param spot SceneNodeType 挂机点
---@return Vector3|nil 传送位置
function AutoPlayManager.GetSpotTeleportPosition(spot)
    if not spot then return nil end
    
    -- 获取挂机点场景节点
    local sceneNode = gg.GetChild(game.WorkSpace, spot.nodePath)
    if not sceneNode then
        gg.log("无法找到挂机点场景节点:", spot.nodePath)
        return nil
    end
    
    -- 优先使用传送节点位置
    local teleportNodeName = spot.areaConfig and spot.areaConfig["传送节点"]
    if teleportNodeName and teleportNodeName ~= "" then
        local teleportNode = sceneNode[teleportNodeName]
        if teleportNode and teleportNode.Position then
            return teleportNode.Position
        end
    end
    
    -- 回退到包围盒节点中心
    local triggerBoxName = spot.areaConfig and spot.areaConfig["包围盒节点"]
    if triggerBoxName and triggerBoxName ~= "" then
        local triggerBox = sceneNode[triggerBoxName]
        if triggerBox and triggerBox.Position then
            return triggerBox.Position
        end
    end
    
    -- 最后回退到场景节点位置
    if sceneNode.Position then
        return sceneNode.Position
    end
    
    return nil
end

-- 【新增】执行传送操作
---@param player MPlayer 玩家对象
---@param targetPosition Vector3 目标位置
---@return boolean 是否传送成功
function AutoPlayManager.ExecuteTeleport(player, targetPosition)
    if not player or not targetPosition then return false end
    
    local actor = player.actor
    if not actor then 
        gg.log("玩家无actor对象，传送失败")
        return false 
    end
    
    -- 使用TeleportService进行传送
    local TeleportService = game:GetService('TeleportService')
    local success, err = pcall(function()
        TeleportService:Teleport(actor, targetPosition)
    end)
    
    if not success then
        gg.log("传送异常:", tostring(err))
        return false
    end
    
    return true
end

-- 【废弃的导航方法，保留用于向后兼容】
-- 移动玩家到挂机点（已废弃，使用传送替代）
-- ---@param player MPlayer 玩家对象
-- ---@param spot SceneNodeType 挂机点
-- function AutoPlayManager.MovePlayerToAutoPlaySpot(player, spot)
--     gg.log("警告: MovePlayerToAutoPlaySpot 已废弃，请使用 TeleportPlayerToAutoPlaySpot")
--     AutoPlayManager.TeleportPlayerToAutoPlaySpot(player, spot)
-- end

-- 设置玩家自动挂机状态
---@param player MPlayer 玩家对象
---@param enabled boolean 是否启用自动挂机
function AutoPlayManager.SetPlayerAutoPlayState(player, enabled)
    if not player then return end
    
    local uin = player.uin
    if enabled then
        -- 先停止任何正在进行的导航
        local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
        AutoRaceEventManager.SendStopNavigation(uin, "启动自动挂机，停止导航")
        
        playerAutoPlayState[uin] = true
        -- 立即寻找最佳挂机点并传送
        AutoPlayManager.FindAndTeleportToBestAutoPlaySpot(player)
    else
        playerAutoPlayState[uin] = nil
    end
end

-- 检查玩家是否在自动挂机中
---@param player MPlayer 玩家实例
---@return boolean 是否在自动挂机中
function AutoPlayManager.IsPlayerAutoPlaying(player)
    if not player then return false end
    return playerAutoPlayState[player.uin] == true
end

--- 【新增】为特定玩家停止自动挂机
---@param player MPlayer 玩家对象
---@param reason string 停止原因
function AutoPlayManager.StopAutoPlayForPlayer(player, reason)
    if not player then return end

    if AutoPlayManager.IsPlayerAutoPlaying(player) then
        -- 1. 更新状态
        AutoPlayManager.SetPlayerAutoPlayState(player, false)
        
        -- 2. 发送通知
        local AutoPlayEventManager = require(ServerStorage.AutoRaceSystem.AutoPlayEvent) ---@type AutoPlayEventManager
        AutoPlayEventManager.NotifyAutoPlayStopped(player, reason or "自动挂机已停止")
        
        --gg.log("玩家", player.uin, "已停止自动挂机，原因:", reason)
    end
end

---@param uin number 玩家UIN
function AutoPlayManager.CleanupPlayerAutoPlayState(uin)
    if not uin then return end
    
    if playerAutoPlayState[uin] then
        playerAutoPlayState[uin] = nil
        gg.log("清理玩家自动挂机状态:", uin)
    end
end


return AutoPlayManager