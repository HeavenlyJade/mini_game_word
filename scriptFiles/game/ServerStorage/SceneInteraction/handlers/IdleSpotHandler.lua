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
---@field idlePlayerTimers table<string, table<Timer>> 每个玩家的挂机定时器列表
local IdleSpotHandler = ClassMgr.Class("IdleSpotHandler", SceneNodeHandlerBase)
IdleSpotHandler.static_instance_registry = IdleSpotHandler.static_instance_registry or {}

--- 初始化挂机点处理器
function IdleSpotHandler:OnInit(node, config, debugId)
    SceneNodeHandlerBase.OnInit(self, node, config, debugId)
    self.idlePlayerTimers = {}
    self.conditionCalculator = ActionCosteRewardCal.New() ---@type ActionCosteRewardCal
    IdleSpotHandler.static_instance_registry[self] = true

    gg.log(string.format("挂机点处理器 '%s' 初始化完成", self.name))
end



function IdleSpotHandler.CleanupPlayerTimersGlobally(playerId)
    local cleanupCount = 0
    for instance, _ in pairs(IdleSpotHandler.static_instance_registry) do
        if instance.idlePlayerTimers and instance.idlePlayerTimers[playerId] then
            local timers = instance.idlePlayerTimers[playerId]
            gg.log(string.format("全局清理：在挂机点 '%s' 中发现玩家 %s 的定时器 %d 个", 
                instance.name or "未知", playerId, #timers))
            
            -- 停止并销毁所有定时器
            for _, timer in ipairs(timers) do
                if timer and not timer.isDestroyed then
                    timer:Stop()
                    timer:Destroy()
                end
            end
            
            -- 清理玩家数据
            instance.idlePlayerTimers[playerId] = nil
            if instance.entitiesInZone then
                instance.entitiesInZone[playerId] = nil
            end
            
            cleanupCount = cleanupCount + #timers
        end
    end
    
    if cleanupCount > 0 then
        gg.log(string.format("全局清理完成：为玩家 %s 清理了 %d 个挂机定时器", playerId, cleanupCount))
    end
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
    local AutoPlayManager = require(ServerStorage.AutoRaceSystem.AutoPlayManager) 
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager
    
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

    -- 启动定时奖励
    self:startIdleRewards(entity)
    
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
---@param entity Entity
function IdleSpotHandler:OnEntityLeave(entity)
    if not entity or not entity.isPlayer then
        return
    end

    ---@cast entity MPlayer

    -- 调用父类方法
    SceneNodeHandlerBase.OnEntityLeave(self, entity)

    gg.log(string.format("玩家 '%s' 离开挂机点 '%s'", entity.name, self.name))

    -- 设置玩家挂机状态
    entity:SetIdlingState(false, nil)
    
    -- 停止定时奖励
    self:stopIdleRewards(entity)
    
    -- 执行离开指令
    if self.config.leaveCommand and self.config.leaveCommand ~= "" then
        executeCommand(entity, self.config.leaveCommand, self)
    end
end

--- 启动玩家的挂机奖励定时器
---@param player MPlayer
function IdleSpotHandler:startIdleRewards(player)
    -- 【修复】统一使用uin作为playerId
    local playerId = player.uin

    -- 如果玩家已有定时器，先清理
    if self.idlePlayerTimers[playerId] then
        self:stopIdleRewards(player)
    end

    -- 检查定时指令配置
    if not self.config.timedCommands or #self.config.timedCommands == 0 then
        gg.log(string.format("挂机点 '%s' 未配置定时指令", self.name))
        return
    end

    -- 初始化玩家定时器列表
    self.idlePlayerTimers[playerId] = {}

    gg.log(string.format("开始为玩家 '%s' 创建挂机定时器，共 %d 个", player.name, #self.config.timedCommands))

    -- 为每个定时指令创建定时器
    for index, timedCommand in ipairs(self.config.timedCommands) do
        local command = timedCommand["指令"]
        local interval = timedCommand["间隔"]

        if command and interval and interval > 0 then
            -- 创建定时器
            local timer = SandboxNode.New("Timer", game.WorkSpace)
            timer.Name = string.format("IdleReward_%s_%s_%d_%d", self.name, playerId, interval, index)
            
            -- 【修复】先设置Callback，再设置其他属性
            timer.Callback = function()
                -- 检查玩家是否还在挂机点内
                if not self.entitiesInZone[playerId] then
                    gg.log(string.format("玩家 %s 已离开挂机点，停止定时器 %s", playerId, timer.Name))
                    timer:Stop()
                    -- 从玩家定时器列表中移除
                    if self.idlePlayerTimers[playerId] then
                        for i, t in ipairs(self.idlePlayerTimers[playerId]) do
                            if t == timer then
                                table.remove(self.idlePlayerTimers[playerId], i)
                                break
                            end
                        end
                    end
                    return
                end

                -- gg.log(string.format("执行挂机奖励指令: %s (玩家: %s)", command, player.name))
                -- 执行挂机奖励指令
                executeCommand(player, command, self)
            end
            
            -- 【修复】设置定时器属性
            timer.Delay = interval    -- 首次延迟
            timer.Loop = true         -- 循环执行
            timer.Interval = interval -- 循环间隔

            -- 启动定时器
            timer:Start()

            -- 添加到玩家定时器列表
            table.insert(self.idlePlayerTimers[playerId], timer)

            gg.log(string.format("为玩家 '%s' 创建挂机定时器成功，间隔: %d秒，指令: %s", player.name, interval, command))
        else
            gg.log(string.format("挂机定时器配置无效: 指令='%s', 间隔=%s", tostring(command), tostring(interval)))
        end
    end
    
    gg.log(string.format("玩家 '%s' 挂机定时器启动完成，共创建 %d 个定时器", player.name, #self.idlePlayerTimers[playerId]))
end

--- 停止玩家的挂机奖励定时器
---@param player MPlayer
function IdleSpotHandler:stopIdleRewards(player)
    -- 【修复】统一使用uin作为playerId
    local playerId = player.uin
    local timers = self.idlePlayerTimers[playerId]

    if timers then
        gg.log(string.format("停止玩家 '%s' 的所有挂机定时器，共 %d 个", player.name, #timers))
        -- 停止所有定时器
        for _, timer in ipairs(timers) do
            if timer then
                timer:Stop()
                timer:Destroy()
            end
        end
        self.idlePlayerTimers[playerId] = nil
        gg.log(string.format("玩家 '%s' 的挂机定时器已全部清理", player.name))
    end
end

--- 处理器销毁时清理所有定时器
function IdleSpotHandler:OnDestroy()
    gg.log(string.format("挂机点处理器 '%s' 开始销毁", self.name))
    
    -- 清理所有玩家的定时器
    for playerId, timers in pairs(self.idlePlayerTimers) do
        if timers then
            for _, timer in ipairs(timers) do
                if timer then
                    timer:Stop()
                    timer:Destroy()
                end
            end
        end
    end
    self.idlePlayerTimers = {}

    -- 调用父类销毁方法
    SceneNodeHandlerBase.OnDestroy(self)

    gg.log(string.format("挂机点处理器 '%s' 已销毁", self.name))
end

return IdleSpotHandler