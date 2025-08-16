local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)  ---@type ClassMgr
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase) ---@type SceneNodeHandlerBase
local GameModeManager = require(ServerStorage.GameModes.GameModeManager) ---@type GameModeManager
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

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
        --gg.log(string.format("错误: 飞车触发器(%s) - 场景节点配置中缺少'linkedLevel'字段。", self.name))
        return
    end

    -- 2. 使用关卡ID，从LevelConfig中获取详细的关卡规则
    -- 在函数内部require, 避免循环依赖
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local levelConfig = ConfigLoader.Levels
    local levelData = levelConfig and levelConfig[levelId] ---@type LevelType
    if not levelData then
        --gg.log(string.format("错误: 飞车触发器(%s) - 在LevelConfig中找不到ID为'%s'的关卡配置。", self.name, levelId))
        return
    end

    -- 【调试】输出关卡数据信息

    if levelData then
        -- 如果defaultGameMode为空，尝试输出原始数据
        if not levelData.defaultGameMode or levelData.defaultGameMode == "" then
            --gg.log("调试: defaultGameMode为空，检查原始配置数据...")

            -- 尝试访问原始的LevelConfig数据
            local LevelConfig = require(MainStorage.Code.Common.Config.LevelConfig)
            local rawData = LevelConfig.Data[levelId]
            if rawData then
                --gg.log(string.format("调试: 原始配置中的'默认玩法' = %s", tostring(rawData["默认玩法"])))
                for key, value in pairs(rawData) do
                    --gg.log(string.format("调试: 原始配置[%s] = %s", tostring(key), tostring(value)))
                end
            else
                --gg.log("调试: 在原始LevelConfig中也找不到该关卡数据")
            end
        end
    end

    -- 3. 从关卡规则中，获取游戏模式的名称
    local gameModeName = levelData.defaultGameMode
    if not gameModeName or gameModeName == "" then
        --gg.log(string.format("错误: 飞车触发器(%s) - 关卡'%s'的配置中缺少'默认玩法'字段。", self.name, levelId))
        return
    end

    -- 5. 调用GameModeManager，请求将玩家加入比赛
    -- 我们使用场景节点配置中的'唯一ID'作为这场比赛的唯一实例ID
    local instanceId = self.config.uuid
    if not instanceId then
        --gg.log(string.format("错误: 飞车触发器(%s) - 场景节点配置中缺少'uuid'字段。", self.name))
        return
    end

    GameModeManager:AddPlayerToMode(player, gameModeName, instanceId, levelData, self.handlerId)

    --gg.log(string.format("成功: 飞车触发器 - 玩家 %s 已被请求加入游戏模式 %s (实例ID: %s)", player.name, gameModeName, instanceId))
end

--- 当实体离开触发区域时调用
---@param player MPlayer
function RaceTriggerHandler:OnEntityLeave(player)
    if not player or not player.isPlayer then return end
    
    --gg.log(string.format("玩家 %s 离开了 '%s' 触发区域。", player.name, self.name))
    
    -- 【新增】检查玩家是否在比赛中，如果在准备阶段离开则将其移除
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager  ---@type GameModeManager
    
    if GameModeManager and GameModeManager:IsPlayerInMode(player.uin) then
        -- 获取玩家当前所在的比赛实例
        local instanceId = GameModeManager.playerModes[player.uin]
        local currentMode = GameModeManager.activeModes[instanceId]
        
        -- 如果比赛还在准备阶段，将玩家从比赛中移除
        if currentMode and currentMode.state == "WAITING" then
            local participantsCount = #currentMode.participants
            --gg.log(string.format("玩家 %s 在准备阶段离开了比赛区域，将其从比赛中移除。当前参赛者数量: %d", player.name, participantsCount))
            
            -- 【新增】通过RaceGameEventManager发送停止倒计时事件
            local RaceGameEventManager = require(ServerStorage.GameModes.Modes.RaceGameEventManager) ---@type RaceGameEventManager
            RaceGameEventManager.SendStopPrepareCountdown(player, "退出准备区域")
            
            -- 移除玩家
            GameModeManager:RemovePlayerFromCurrentMode(player)
            
            -- 根据是否为最后一个玩家提供不同的提示
            if participantsCount <= 1 then
                -- 这是最后一个玩家离开
                if player.SendHoverText then
                    player:SendHoverText("已退出比赛准备，比赛已取消")
                end
            else
                -- 还有其他玩家在准备中
                if player.SendHoverText then
                    player:SendHoverText("已退出比赛准备")
                end
            end
        end
    end
end

return RaceTriggerHandler
