local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)  ---@type ClassMgr
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase) ---@type SceneNodeHandlerBase
local GameModeManager = require(ServerStorage.GameModes.GameModeManager) ---@type GameModeManager
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class RaceTriggerHandler : SceneNodeHandlerBase
---@field super SceneNodeHandlerBase
local RaceTriggerHandler = ClassMgr.Class("RaceTriggerHandler", SceneNodeHandlerBase)

--- 当有实体进入触发区域时调用
---@param player MPlayer
function RaceTriggerHandler:OnEntityEnter(player)
    -- 核心修正：直接检查 isPlayer 属性，这是最简单且最正确的判断方法
    if not player or not player.isPlayer then
        return
    end

    -- 【核心修正】从处理器配置中获取关联的关卡ID，使用面向对象的方式访问
    local levelId = self.config.linkedLevel
    if not levelId then
        gg.log(string.format("错误: 飞车触发器(%s) - 场景节点配置中缺少'linkedLevel'字段。", self.name))
        return
    end

    -- 2. 使用关卡ID，从LevelConfig中获取详细的关卡规则
    -- 在函数内部require, 避免循环依赖
    local levelConfig = ConfigLoader.Levels
    local levelData = levelConfig and levelConfig[levelId] ---@type LevelType
    if not levelData then
        gg.log(string.format("错误: 飞车触发器(%s) - 在LevelConfig中找不到ID为'%s'的关卡配置。", self.name, levelId))
        return
    end

    -- 3. 从关卡规则中，获取游戏模式的名称
    local gameModeName = levelData.defaultGameMode
    if not gameModeName or gameModeName == "" then
        gg.log(string.format("错误: 飞车触发器(%s) - 关卡'%s'的配置中缺少'默认玩法'字段。", self.name, levelId))
        return
    end

    -- 5. 调用GameModeManager，请求将玩家加入比赛
    -- 我们使用场景节点配置中的'唯一ID'作为这场比赛的唯一实例ID
    local instanceId = self.config.uuid
    if not instanceId then
        gg.log(string.format("错误: 飞车触发器(%s) - 场景节点配置中缺少'uuid'字段。", self.name))
        return
    end

    GameModeManager:AddPlayerToMode(player, gameModeName, instanceId, levelData, self.handlerId)

    gg.log(string.format("成功: 飞车触发器 - 玩家 %s 已被请求加入游戏模式 %s (实例ID: %s)", player.name, gameModeName, instanceId))
end

--- 当实体离开触发区域时调用
---@param player MPlayer
function RaceTriggerHandler:OnEntityLeave(player)
    if not player or not player.isPlayer then return end
    
    gg.log(string.format("XXXXS玩家 %s 离开了 '%s' 触发区域。", player.name, self.name))
    
    -- 【新增】检查玩家是否在比赛中，如果在准备阶段离开则将其移除（考虑传送保护期）
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager  ---@type GameModeManager
    if GameModeManager:IsPlayerInMode(player.uin) then
        -- 获取玩家当前所在的比赛实例
        local instanceId = GameModeManager.playerModes[player.uin]
        local currentMode = GameModeManager.activeModes[instanceId]
        -- 如果比赛还在准备阶段，检查保护期并可能将玩家从比赛中移除
        if currentMode and (currentMode.state == "WAITING" or currentMode.state == "PREPARING") then
            -- 【新增】检查传送保护期
            local uin = player.uin
            gg.log("currentMode.teleportProtectionData", currentMode.teleportProtectionData,os.time())
            if currentMode.teleportProtectionData and currentMode.teleportProtectionData[uin] then
                local protectionEndTime = currentMode.teleportProtectionData[uin]
                if os.time() < protectionEndTime then
                    gg.log(string.format("RaceTriggerHandler:OnEntityLeave玩家 %s 在传送保护期内离开区域，忽略此次离开事件", player.name))
                    return
                else
                    -- 保护期结束，清理数据
                    currentMode.teleportProtectionData[uin] = nil
                end
            end

            local participantsCount = currentMode:_getParticipantCount()
            gg.log(string.format("玩家 %s 在准备阶段离开了比赛区域，将其从比赛中移除。当前参赛者数量: %d", player.name, participantsCount))
            
            -- 【新增】通过RaceGameEventManager发送停止倒计时事件
            local RaceGameEventManager = require(ServerStorage.GameModes.Modes.RaceGameEventManager) ---@type RaceGameEventManager
            RaceGameEventManager.SendStopPrepareCountdown(player, "退出准备区域")
            
            -- 移除玩家
            GameModeManager:RemovePlayerFromCurrentMode(player)
        end
    end
end

--- 【新增】静态方法：清理指定玩家的比赛数据（用于玩家离开游戏时调用）
---@param player MPlayer 玩家实例
function RaceTriggerHandler.CleanupPlayerData(player)
    if not player then return end
    
    local uin = player.uin
    gg.log(string.format("开始清理玩家 %s (%d) 的比赛数据", player.name or "未知", uin))
    
    -- 1. 从GameModeManager中移除玩家
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager
    
    if GameModeManager and GameModeManager:IsPlayerInMode(uin) then
        local instanceId = GameModeManager.playerModes[uin]
        local currentMode = GameModeManager.activeModes[instanceId]
        
        if currentMode then
            gg.log(string.format("玩家 %s 在比赛实例 %s 中，开始清理", player.name or uin, instanceId))
            
            -- 为该玩家执行游戏结束指令，以恢复其状态（如速度）
            if currentMode._executeGameEndCommandsForPlayer then
                currentMode:_executeGameEndCommandsForPlayer(player)
            end
            
            -- 调用 OnPlayerLeave，清理其在比赛实例中的所有数据
            if currentMode.OnPlayerLeave then
                currentMode:OnPlayerLeave(player)
            end
            
            -- 发送比赛结束通知
            local RaceGameEventManager = require(ServerStorage.GameModes.Modes.RaceGameEventManager)
            if RaceGameEventManager and RaceGameEventManager.SendRaceEndNotification then
                RaceGameEventManager.SendRaceEndNotification(player)
            end
            
            -- 停止自动比赛（如果有）
            local AutoRaceManager = require(ServerStorage.AutoRaceSystem.AutoRaceManager)
            if AutoRaceManager and AutoRaceManager.StopAutoRaceForPlayer then
                AutoRaceManager.StopAutoRaceForPlayer(player, "玩家离开游戏")
            end
        end
        
        -- 从 GameModeManager 中移除玩家记录
        GameModeManager.playerModes[uin] = nil
    end
    
    -- 2. 遍历所有比赛触发器处理器，清理该玩家的数据
    local allHandlers = serverDataMgr.scene_node_handlers
    for handlerId, handler in pairs(allHandlers) do
        if handler and handler.className == "RaceTriggerHandler" then
            handler:CleanupPlayerDataInstance(player)
        end
    end
    
    gg.log(string.format("玩家 %s (%d) 的比赛数据清理完成", player.name or "未知", uin))
end

--- 【新增】实例方法：清理指定玩家在当前触发器的数据
---@param player MPlayer 玩家实例
function RaceTriggerHandler:CleanupPlayerDataInstance(player)
    if not player then return end
    
    local uin = player.uin
    
    -- 从区域内玩家列表中移除（如果有的话）
    if self.entitiesInZone and self.entitiesInZone[uin] then
        self.entitiesInZone[uin] = nil
        gg.log(string.format("从比赛触发器 '%s' 的区域列表中移除玩家 %s", self.name, player.name or uin))
    end
end

return RaceTriggerHandler
