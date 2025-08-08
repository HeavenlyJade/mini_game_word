-- /scriptFiles/game/ServerStorage/SceneInteraction/handlers/LotterySpotHandler.lua
-- 抽奖点处理器，负责处理玩家在抽奖点的交互逻辑

local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase) ---@type SceneNodeHandlerBase
local gg = require(MainStorage.Code.Untils.MGlobal)
local CommandManager = require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager

---@class LotterySpotHandler : SceneNodeHandlerBase
local LotterySpotHandler = ClassMgr.Class("LotterySpotHandler", SceneNodeHandlerBase)

--- 初始化抽奖点处理器
function LotterySpotHandler:OnInit(node, config, debugId)
    -- 调用父类初始化
    SceneNodeHandlerBase.OnInit(self, node, config, debugId)
    
    gg.log(string.format("抽奖点处理器 '%s' 初始化完成", self.name))
end

--- 执行指令字符串
---@param player MPlayer 目标玩家
---@param commandStr string 指令字符串
local function executeCommand(player, commandStr)
    if not commandStr or commandStr == "" then
        return
    end
    
    -- 使用CommandManager执行指令
    CommandManager.ExecuteCommand(commandStr, player, true)
end

--- 当玩家进入抽奖点时
---@param entity Entity
function LotterySpotHandler:OnEntityEnter(entity)
    -- 调用父类方法处理通用逻辑
    SceneNodeHandlerBase.OnEntityEnter(self, entity)
    
    -- 只处理玩家
    if not entity or not entity.isPlayer then
        return
    end
    
    ---@cast entity MPlayer
    gg.log(string.format("玩家 '%s' 进入抽奖点 '%s'", entity.name, self.name))
    
    -- 执行进入指令（打开抽奖界面）
    if self.config.enterCommand and self.config.enterCommand ~= "" then
        executeCommand(entity, self.config.enterCommand)
    end
    
    -- 播放音效（如果有配置）
    if self.config.soundAsset and self.config.soundAsset ~= "" then
        self:PlaySound(self.config.soundAsset, entity.actor, 1.0, 1.0, 10)
    end
end

--- 当玩家离开抽奖点时
---@param entity Entity
function LotterySpotHandler:OnEntityLeave(entity)
    -- 调用父类方法处理通用逻辑
    SceneNodeHandlerBase.OnEntityLeave(self, entity)
    
    -- 只处理玩家
    if not entity or not entity.isPlayer then
        return
    end
    
    ---@cast entity MPlayer
    gg.log(string.format("玩家 '%s' 离开抽奖点 '%s'", entity.name, self.name))
    
    -- 执行离开指令（如果有配置）
    if self.config.leaveCommand and self.config.leaveCommand ~= "" then
        executeCommand(entity, self.config.leaveCommand)
    end
end

--- 处理器销毁时的清理
function LotterySpotHandler:OnDestroy()
    -- 调用父类销毁方法
    SceneNodeHandlerBase.OnDestroy(self)
    
    gg.log(string.format("抽奖点处理器 '%s' 已销毁", self.name))
end

return LotterySpotHandler
