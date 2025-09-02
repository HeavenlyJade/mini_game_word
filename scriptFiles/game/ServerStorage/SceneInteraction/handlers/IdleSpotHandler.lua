-- /scriptFiles/game/ServerStorage/SceneInteraction/handlers/IdleSpotHandler.lua
-- 挂机点处理器，负责处理玩家挂机逻辑

local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase) ---@type SceneNodeHandlerBase
local gg = require(MainStorage.Code.Untils.MGlobal)
local CommandManager = require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager
local BonusManager = require(ServerStorage.BonusManager.BonusManager) ---@type BonusManager
local ActionCosteRewardCal = require(MainStorage.Code.GameReward.RewardCalc.ActionCosteRewardCal) ---@type ActionCosteRewardCal

---@class IdleSpotHandler : SceneNodeHandlerBase
local IdleSpotHandler = ClassMgr.Class("IdleSpotHandler", SceneNodeHandlerBase)

--- 初始化挂机点处理器
function IdleSpotHandler:OnInit(node, config, debugId)
    SceneNodeHandlerBase.OnInit(self, node, config, debugId)
    self.conditionCalculator = ActionCosteRewardCal.New() ---@type ActionCosteRewardCal
    gg.log(string.format("挂机点处理器 '%s' 初始化完成", self.name))
end




--- 执行指令字符串
---@param player MPlayer 目标玩家
---@param commandStr string 指令字符串
---@param handlerInstance IdleSpotHandler 处理器实例引用
local function executeCommand(player, commandStr, handlerInstance)
    if not commandStr or commandStr == "" then
        return
    end
    CommandManager.ExecuteCommand(commandStr, player, true)
end

--- 当玩家进入挂机点时
---@param entity Entity
function IdleSpotHandler:OnEntityEnter(entity)
    if not entity or not entity.isPlayer then
        return
    end

    ---@cast entity MPlayer
    
    -- 检查进入条件
    if not self:checkEnterConditions(entity) then
        gg.log(string.format("玩家 '%s' 不满足挂机点 '%s' 的进入条件，拒绝进入", entity.name, self.name))
        -- 重要：从entitiesInZone中移除，避免TouchEnded事件误触发
        local entityId = entity.uin
        if self.entitiesInZone[entityId] then
            self.entitiesInZone[entityId] = nil
        end
        return
    end
    
    local AutoRaceManager = require(ServerStorage.AutoRaceSystem.AutoRaceManager)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager ---@type GameModeManager
    
    -- 检查玩家是否在自动比赛中
    if AutoRaceManager.IsPlayerAutoRacing(entity) then
        gg.log("玩家处于自动比赛状态，拒绝进入挂机点")
        return
    end
    
    -- 检查玩家是否在比赛中
    if GameModeManager and GameModeManager:IsPlayerInMode(entity.uin) then
        gg.log("玩家处于比赛状态，拒绝进入挂机点")
        return
    end

    -- 条件满足后，调用父类方法
    SceneNodeHandlerBase.OnEntityEnter(self, entity)

    -- 传送到挂机点精确位置
    if self.teleportNode and self.teleportNode.Position then
        local actor = entity.actor
        if actor then
            local TeleportService = game:GetService('TeleportService')
            pcall(function()
                TeleportService:Teleport(actor, self.teleportNode.Position)
            end)
            gg.log(string.format("玩家 '%s' 已被传送到挂机点 '%s' 的精确位置", entity.name, self.name))
        end
    end

    -- 设置玩家挂机状态
    entity:SetIdlingState(true, self.name)
    
    -- 执行进入指令
    if self.config.enterCommand and self.config.enterCommand ~= "" then
        executeCommand(entity, self.config.enterCommand, self)
    end

    -- 【修改】启动定时器（复用父类功能）
    self:StartPlayerTimers(entity)
    
    gg.log(string.format("玩家 '%s' 进入挂机点 '%s'", entity.name, self.name))
end

--- 检查玩家是否满足进入条件
---@param player MPlayer 玩家对象
---@return boolean 是否满足进入条件
function IdleSpotHandler:checkEnterConditions(player)
    if not self.config.enterConditions or #self.config.enterConditions == 0 then
        return true
    end

    -- 获取玩家数据
    local playerData = player.variableSystem:GetVariablesDictionary()
    local bagData = {}
    if player.bagMgr then
        bagData = player.bagMgr
    end
    local externalContext = {}

    -- 检查所有进入条件
    for _, condition in ipairs(self.config.enterConditions) do
        local formula = condition["条件公式"]
        if formula and formula ~= "" then
            if not self.conditionCalculator:_CheckCondition(formula, playerData, bagData, externalContext) then
                return false
            end
        end
    end

    return true
end

--- 当玩家离开挂机点时
---@param entity MPlayer
function IdleSpotHandler:OnEntityLeave(MPlayer)
    if not MPlayer or not MPlayer.isPlayer then
        return
    end

    ---@cast entity MPlayer

    -- 调用父类方法
    SceneNodeHandlerBase.OnEntityLeave(self, MPlayer)

    gg.log(string.format("玩家 '%s' 离开挂机点 '%s'", MPlayer.name, self.name))

    -- 设置玩家挂机状态
    MPlayer:SetIdlingState(false, nil)
    
    -- 执行离开指令
    if self.config.leaveCommand and self.config.leaveCommand ~= "" then
        executeCommand(MPlayer, self.config.leaveCommand, self)
    end
end


--- 处理器销毁时清理所有定时器
function IdleSpotHandler:OnDestroy()
    gg.log(string.format("挂机点处理器 '%s' 开始销毁", self.name))
    
    SceneNodeHandlerBase.OnDestroy(self)


    gg.log(string.format("挂机点处理器 '%s' 已销毁", self.name))
end


--- 【新增】静态方法：清理指定玩家的挂机数据（用于玩家离开游戏时调用）
---@param player MPlayer 玩家实例
function IdleSpotHandler.CleanupPlayerData(player)
    if not player then return end
    
    local uin = player.uin
    gg.log(string.format("开始清理玩家 %s (%d) 的挂机数据", player.name or "未知", uin))
    
    -- 1. 重置玩家挂机状态
    if player.SetIdlingState then
        player:SetIdlingState(false, nil)
    end
    player.isIdling = false
    player.currentIdleSpot = nil
    
    -- 2. 遍历所有挂机点处理器，清理该玩家的数据
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local allHandlers = serverDataMgr.scene_node_handlers
    
    for handlerId, handler in pairs(allHandlers) do
        if handler and handler.className == "IdleSpotHandler" then
            -- 调用处理器实例的清理方法
            handler:CleanupPlayerDataInstance(player)
        end
    end
    
    gg.log(string.format("玩家 %s (%d) 的挂机数据清理完成", player.name or "未知", uin))
end

--- 【新增】实例方法：清理指定玩家在当前挂机点的数据
---@param player MPlayer 玩家实例
function IdleSpotHandler:CleanupPlayerDataInstance(player)
    if not player then return end
    
    local uin = player.uin
    
    -- 从区域内玩家列表中移除
    if self.entitiesInZone and self.entitiesInZone[uin] then
        self.entitiesInZone[uin] = nil
        gg.log(string.format("从挂机点 '%s' 的区域列表中移除玩家 %s", self.name, player.name or uin))
    end
    
    -- 清理玩家相关的定时器（如果有的话）
    self:CleanupPlayerTimers(player)
    
    -- 如果玩家当前在此挂机点，执行离开指令
    if player.currentIdleSpot == self.name then
        if self.config.leaveCommand and self.config.leaveCommand ~= "" then
            local CommandManager = require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager
            CommandManager.ExecuteCommand(self.config.leaveCommand, player, true)
        end
        player.currentIdleSpot = nil
    end
end

--- 【新增】清理玩家相关定时器的方法
---@param player MPlayer 玩家实例
function IdleSpotHandler:CleanupPlayerTimers(player)
    -- 清理与该玩家相关的所有定时器
    -- 这里需要根据你的定时器实现来清理
    -- 如果定时器是基于玩家UIN存储的，则从相应的存储中移除
    
    -- 示例：如果有玩家专属的定时器存储
    if self.playerTimers and self.playerTimers[player.uin] then
        for timerName, timer in pairs(self.playerTimers[player.uin]) do
            if timer and timer.Stop then
                timer:Stop()
            end
        end
        self.playerTimers[player.uin] = nil
    end
end

--- 【新增】实现父类钩子方法：清理玩家数据
---@param player MPlayer|table 玩家对象或包含uin的表
function IdleSpotHandler:OnPlayerDataCleanup(player)
    self:CleanupPlayerDataInstance(player)
end
return IdleSpotHandler