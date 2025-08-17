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

    -- TODO: 如有传送消耗(cost)，在此扣除；当前按KISS原则暂不实现
end

return CommonEventManager


