-- /scriptFiles/game/ServerStorage/SceneInteraction/handlers/TeleportSpotHandler.lua
-- 传送点处理器：玩家进入传送点包围盒时，向客户端打开传送界面 WaypointGui

local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase) ---@type SceneNodeHandlerBase
local gg = require(MainStorage.Code.Untils.MGlobal)
local CommandManager = require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager

---@class TeleportSpotHandler : SceneNodeHandlerBase
local TeleportSpotHandler = ClassMgr.Class("TeleportSpotHandler", SceneNodeHandlerBase)

--- 初始化
function TeleportSpotHandler:OnInit(node, config, debugId)
    -- 父类初始化
    SceneNodeHandlerBase.OnInit(self, node, config, debugId)
end

--- 执行指令字符串
---@param player MPlayer
---@param commandStr string
local function executeCommand(player, commandStr)
    if not commandStr or commandStr == "" then
        return
    end
    CommandManager.ExecuteCommand(commandStr, player, true)
end

--- 当实体进入传送点包围盒
---@param entity Entity
function TeleportSpotHandler:OnEntityEnter(entity)
    SceneNodeHandlerBase.OnEntityEnter(self, entity)
    if not entity or not entity.isPlayer then
        return
    end
    ---@cast entity MPlayer
    -- 优先使用配置的进入指令；若未配置则默认打开 WaypointGui
    if self.config.enterCommand and self.config.enterCommand ~= "" then
        executeCommand(entity, self.config.enterCommand)
    else
        executeCommand(entity, 'openui { "操作类型": "打开界面", "界面名": "WaypointGui" }')
    end

    -- 可选播放音效
    if self.config.soundAsset and self.config.soundAsset ~= "" then
        self:PlaySound(self.config.soundAsset, entity.actor, 1.0, 1.0, 10)
    end
end

--- 当实体离开传送点包围盒
---@param entity Entity
function TeleportSpotHandler:OnEntityLeave(entity)
    SceneNodeHandlerBase.OnEntityLeave(self, entity)
    if not entity or not entity.isPlayer then
        return
    end
    ---@cast entity MPlayer
    -- 优先使用配置的离开指令；若未配置则默认关闭 WaypointGui
    if self.config.leaveCommand and self.config.leaveCommand ~= "" then
        executeCommand(entity, self.config.leaveCommand)
    else
        executeCommand(entity, 'openui { "操作类型": "关闭界面", "界面名": "WaypointGui" }')
    end
end

function TeleportSpotHandler:OnDestroy()
    SceneNodeHandlerBase.OnDestroy(self)
end

return TeleportSpotHandler


