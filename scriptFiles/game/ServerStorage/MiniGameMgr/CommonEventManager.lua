-- CommonEventManager.lua
-- 通用事件管理器：集中处理客户端发来的通用请求（如传送等）
-- 参考 BagEventManager 的简单结构与写法，避免过度设计

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local CommonEventConfig = require(MainStorage.Code.Event.CommonEvent) ---@type CommonEventConfig

---@class CommonEventManager
local CommonEventManager = {}

-- 事件常量（与配置保持一致，便于外部引用）
CommonEventManager.REQUEST = CommonEventConfig.REQUEST

-- 注册事件
function CommonEventManager.Init()
    CommonEventManager.RegisterEventHandlers()
end

function CommonEventManager.RegisterEventHandlers()
    ServerEventManager.Subscribe(CommonEventConfig.REQUEST.TELEPORT_TO, function(evt)
        CommonEventManager.HandleTeleportTo(evt)
    end)
end

--- 验证玩家
---@param evt table
---@return MPlayer|nil
local function ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player and env_player.uin
    if not uin then
        return nil
    end
    return MServerDataManager.getPlayerByUin(uin) ---@type Mplayer
end

--- 处理传送请求
---@param evt table { nodePath:string, pointName:string, cost:number }
function CommonEventManager.HandleTeleportTo(evt)
    --gg.log("[传送] 收到请求:", evt)
    local player = ValidatePlayer(evt) ---@type MPlayer
    if not player then --gg.log("[传送] 失败：无玩家");
    return end

    local args = evt.args or {}
    local nodePath = args.nodePath
    local pointName = args.pointName -- 传送点名称
    if not nodePath or nodePath == "" then
        --gg.log("[传送] 失败：缺少 nodePath")
        return
    end
    --gg.log("[传送] 玩家:", player.name, " nodePath:", nodePath)

    -- 查找目标节点
    local targetNode = MServerDataManager.GetNodeByFullPath(nodePath)
    if not targetNode then
        --gg.log("[传送] 失败：找不到目标节点", nodePath)
        return
    end
    --gg.log("[传送] 找到目标节点:", targetNode.Name or tostring(targetNode))

    -- 计算目标位置
    local targetPosition = nil
    if targetNode.Position then
        targetPosition = targetNode.Position
        --gg.log("[传送] 使用 Position:", targetPosition)
    elseif targetNode.Transform and targetNode.Transform.Position then
        targetPosition = targetNode.Transform.Position
        --gg.log("[传送] 使用 Transform.Position:", targetPosition)
    else
        --gg.log("[传送] 失败：节点无位置(Position/Transform.Position)")
        return
    end

    local actor = player.actor
    if not actor then --gg.log("[传送] 失败：玩家无 actor");
    return end

    -- 执行传送
    local TeleportService = game:GetService('TeleportService')
    --gg.log("[传送] 调用 TeleportService:Teleport", targetPosition)
    local ok, err = pcall(function()
        TeleportService:Teleport(actor, targetPosition)
    end)
    if not ok then
        --gg.log("[传送] TeleportService 异常:", tostring(err))
        return
    end
    --gg.log("[传送] 成功：", player.name, " -> ", tostring(targetPosition))

    -- 传送成功后，更新玩家场景映射
    if pointName then
        -- 从传送点配置中获取场景节点
        local TeleportPointConfig = require(MainStorage.Code.Common.Config.TeleportPointConfig) ---@type TeleportPointConfig
        local pointConfig = TeleportPointConfig.Data[pointName]
        
        if pointConfig and pointConfig['场景节点'] then
            local sceneNode = pointConfig['场景节点']
            local uin = player.uin
            -- gg.log("传送点名称: " .. pointName, "场景节点: " .. sceneNode, "玩家ID: " .. uin)
            
            -- 【修改】直接在MPlayer对象中更新场景信息
            player.currentScene = sceneNode
            -- gg.log("[传送] 更新玩家场景信息:", player.name, " -> ", sceneNode)
            
            -- 更新全局场景映射（保持兼容性）
            if gg.player_scene_map then
                gg.player_scene_map[uin] = sceneNode
            end
        end
    end

    -- TODO: 如有传送消耗(cost)，在此扣除；当前按KISS原则暂不实现
end

return CommonEventManager


