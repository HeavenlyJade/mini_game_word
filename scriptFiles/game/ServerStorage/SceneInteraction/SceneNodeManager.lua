-- /scriptFiles/game/ServerStorage/SceneInteraction/SceneNodeManager.lua
-- 负责初始化和管理所有场景交互节点的总管理器

local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")

local SceneNodeConfig = require(MainStorage.Code.Common.Config.SceneNodeConfig)
local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local gg = require(MainStorage.Code.Untils.MGlobal)  ---@type gg

---@class SceneNodeManager
local SceneNodeManager = {}

-- 映射场景类型到处理器的路径
local HANDLER_TYPE_MAP = {
    ["跳台"] = require(ServerStorage.SceneInteraction.handlers.JumpPlatformHandler), ---@type JumpPlatformHandler
    ["飞行比赛"] = require(ServerStorage.SceneInteraction.handlers.RaceTriggerHandler), ---@type RaceTriggerHandler
    -- ["陷阱"] = require(ServerStorage.SceneInteraction.handlers.TrapHandler), -- 示例
    -- ["治疗区域"] = require(ServerStorage.SceneInteraction.handlers.HealZoneHandler), -- 示例
}

--- 初始化所有在配置中定义的场景节点
function SceneNodeManager:Init()
    gg.log("SceneNodeManager: 开始初始化场景交互节点...")
    local allNodeConfigs = SceneNodeConfig.Data
    if not allNodeConfigs then
        gg.log("SceneNodeManager: [警告] 找不到任何场景节点配置。")
        return
    end

    for configName, configData in pairs(allNodeConfigs) do
        local nodePath = configData["场景节点路径"]
        local nodeType = configData["场景类型"]

        if not nodePath or not nodeType then
            gg.log(string.format("SceneNodeManager: [警告] 配置 '%s' 缺少 '场景节点路径' 或 '场景类型'", configName))
        else
            -- 1. 获取物理节点 (使用新的公共方法)
            local node = ServerDataManager.GetNodeByFullPath(nodePath)

            if not node then
                gg.log(string.format("SceneNodeManager: [错误] 无法在场景中找到路径为 '%s' 的节点 (来自配置 '%s')", nodePath, configName))
            else
                -- 2. 获取对应的处理器类
                local HandlerClass = HANDLER_TYPE_MAP[nodeType]
                if not HandlerClass then
                    gg.log(string.format("SceneNodeManager: [警告] 找不到类型为 '%s' 的处理器 (来自配置 '%s')", nodeType, configName))
                else
                    -- 3. 实例化处理器
                    local debugId = math.random(1000, 9999) -- 创建一个随机的调试ID
                    gg.log(string.format("SceneNodeManager: [DebugID: %d] 正在为 '%s' 创建 '%s' 类型的处理器...", debugId, configName, nodeType))
                    local handler = HandlerClass.New(node, configData, debugId)
                    if not handler then
                        gg.log(string.format("SceneNodeManager: [错误] 实例化处理器 '%s' 失败。", configName))
                    end
                end
            end
        end
    end

    gg.log("SceneNodeManager: 场景交互节点初始化完成。")
end

return SceneNodeManager