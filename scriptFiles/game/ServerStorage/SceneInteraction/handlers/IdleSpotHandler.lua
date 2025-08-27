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

--- 初始化挂机点处理器
function IdleSpotHandler:OnInit(node, config, debugId)
    -- 调用父类初始化
    SceneNodeHandlerBase.OnInit(self, node, config, debugId)

    -- 初始化玩家挂机状态跟踪
    self.idlePlayerTimers = {}

    -- 初始化条件计算器
    self.conditionCalculator = ActionCosteRewardCal.New() ---@type ActionCosteRewardCal

    --gg.log(string.format("挂机点处理器 '%s' 初始化完成", self.name))
end

--- 执行指令字符串
---@param player MPlayer 目标玩家
---@param commandStr string 指令字符串
---@param handlerInstance IdleSpotHandler 处理器实例引用
local function executeCommand(player, commandStr, handlerInstance)
    if not commandStr or commandStr == "" then
        return
    end

    -- 直接使用CommandManager执行所有指令
    CommandManager.ExecuteCommand(commandStr, player, true)
end



--- 当玩家进入挂机点时
---@param entity Entity
function IdleSpotHandler:OnEntityEnter(entity)
    -- 只处理玩家
    if not entity or not entity.isPlayer then
        return
    end

    ---@cast entity MPlayer
    
    -- 检查进入条件 - 提前检查，避免不必要的父类调用
    if not self:checkEnterConditions(entity) then
        --gg.log(string.format("玩家 '%s' 不满足挂机点 '%s' 的进入条件，拒绝进入", entity.name, self.name))
        -- 重要：如果条件不满足，需要从entitiesInZone中移除，避免后续TouchEnded事件误触发
        local entityId = entity.uuid
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
        --gg.log("玩家处于自动比赛状态，拒绝进入挂机点")
        return
    end
    
    -- 检查玩家是否在比赛中
    if GameModeManager and GameModeManager:IsPlayerInMode(entity.uin) then
        --gg.log("玩家处于比赛状态，拒绝进入挂机点")
        return
    end

    -- 条件满足后，再调用父类方法处理通用逻辑
    SceneNodeHandlerBase.OnEntityEnter(self, entity)

    -- 【新增】将玩家传送到此挂机点的精确传送位置
    if self.teleportNode and self.teleportNode.Position then
        local actor = entity.actor
        if actor then
            local TeleportService = game:GetService('TeleportService')
            pcall(function()
                TeleportService:Teleport(actor, self.teleportNode.Position)
            end)
            --gg.log(string.format("玩家 '%s' 已被传送到挂机点 '%s' 的精确位置", entity.name, self.name))
        end
    end

    local playerId = entity.uuid

    --gg.log(string.format("玩家 '%s' 进入挂机点 '%s'", entity.name, self.name))

    -- 设置玩家挂机状态
    entity:SetIdlingState(true, self.name)
    
    -- 执行进入指令
    if self.config.enterCommand and self.config.enterCommand ~= "" then
        executeCommand(entity, self.config.enterCommand, self)
    end

    -- 启动定时奖励
    self:startIdleRewards(entity)
end

--- 检查玩家是否满足进入条件
---@param player MPlayer 玩家对象
---@return boolean 是否满足进入条件
function IdleSpotHandler:checkEnterConditions(player)
    -- 如果没有配置进入条件，则默认满足
    if not self.config.enterConditions or #self.config.enterConditions == 0 then
        return true
    end

    -- 获取玩家数据 - 使用MPlayer的GetConsumableData方法构建统一数据结构
    local playerData = player.variableSystem:GetVariablesDictionary()
    
    -- 获取玩家的背包数据
    local bagData = {}
    if player.bagMgr then
        bagData = player.bagMgr
    end

    -- 构建外部上下文（如果需要的话）
    local externalContext = {}

    -- 遍历所有进入条件，所有条件都必须满足
    for _, condition in ipairs(self.config.enterConditions) do
        local formula = condition["条件公式"]
        if formula and formula ~= "" then
            -- 直接使用ActionCosteRewardCal的_CheckCondition方法
            -- 参数顺序：条件表达式, 玩家数据, 背包数据, 外部上下文
            -- gg.log("formula, playerData, bagData, externalContext",formula, playerData, bagData, externalContext)
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
    -- 只处理玩家
    if not entity or not entity.isPlayer then
        return
    end

    ---@cast entity MPlayer
    local playerId = entity.uuid


    -- 调用父类方法处理通用逻辑
    SceneNodeHandlerBase.OnEntityLeave(self, entity)

    --gg.log(string.format("玩家 '%s' 离开挂机点 '%s'", entity.name, self.name))

    -- 设置玩家挂机状态
    entity:SetIdlingState(false, nil)
    
    -- 停止定时奖励
    self:stopIdleRewards(entity)

    -- 执行离开指令（消耗指令）
    if self.config.leaveCommand and self.config.leaveCommand ~= "" then
        executeCommand(entity, self.config.leaveCommand, self)
    end
end

--- 启动玩家的挂机奖励定时器
---@param player MPlayer
function IdleSpotHandler:startIdleRewards(player)
    local playerId = player.uuid

    -- 如果玩家已有定时器，先清理
    if self.idlePlayerTimers[playerId] then
        self:stopIdleRewards(player)
    end

    -- 检查是否有定时指令配置
    if not self.config.timedCommands or #self.config.timedCommands == 0 then
        --gg.log(string.format("挂机点 '%s' 未配置定时指令", self.name))
        return
    end

    -- 初始化玩家的定时器列表
    self.idlePlayerTimers[playerId] = {}

    -- 为每个定时指令创建定时器
    for _, timedCommand in ipairs(self.config.timedCommands) do
        local command = timedCommand["指令"]
        local interval = timedCommand["间隔"]

        if command and interval and interval > 0 then
            -- 创建定时器
            local timer = SandboxNode.New("Timer", game.WorkSpace)
            timer.Name = string.format("IdleReward_%s_%s_%d", self.name, playerId, interval)
            timer.Delay = interval -- 首次延迟
            timer.Loop = true      -- 循环执行
            timer.Interval = interval -- 循环间隔

            timer.Callback = function()
                -- 检查玩家是否还在挂机点内
                if not self.entitiesInZone[playerId] then
                    -- 玩家已离开，停止定时器
                    timer:Stop()
                    -- 从玩家的定时器列表中移除
                    for i, t in ipairs(self.idlePlayerTimers[playerId]) do
                        if t == timer then
                            table.remove(self.idlePlayerTimers[playerId], i)
                            break
                        end
                    end
                    return
                end

                -- 执行挂机奖励指令，传递处理器实例引用
                executeCommand(player, command, self)
            end

            timer:Start()

            -- 将定时器添加到玩家的定时器列表中
            table.insert(self.idlePlayerTimers[playerId], timer)

            --gg.log(string.format("为玩家 '%s' 启动挂机奖励定时器，间隔: %d秒", player.name, interval))
        end
    end
end

--- 停止玩家的挂机奖励定时器
---@param player MPlayer
function IdleSpotHandler:stopIdleRewards(player)
    local playerId = player.uuid
    local timers = self.idlePlayerTimers[playerId]

    if timers then
        -- 停止所有定时器
        for _, timer in ipairs(timers) do
            if timer then
                timer:Stop()
                timer:Destroy() -- 再销毁

            end
        end
        self.idlePlayerTimers[playerId] = nil
        --gg.log(string.format("停止玩家 '%s' 的所有挂机奖励定时器", player.name))
    end
end

--- 处理器销毁时清理所有定时器
function IdleSpotHandler:OnDestroy()
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

    --gg.log(string.format("挂机点处理器 '%s' 已销毁", self.name))
end

return IdleSpotHandler
