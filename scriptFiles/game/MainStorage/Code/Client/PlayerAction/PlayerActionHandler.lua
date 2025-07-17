local Enum = Enum
local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask

-- 【重构】行为模块注册表
local ActionModules = {
    [EventPlayerConfig.GAME_MODES.RACE_GAME] = require(MainStorage.Code.Client.PlayerAction.ActionModules.RaceGameAction)
    -- 未来新增其他模式的模块，在此处注册即可
}


---@class PlayerActionHandler : Class
-- 客户端玩家行为的"管理器"，负责加载和管理不同游戏模式下的具体行为模块。
local PlayerActionHandler = ClassMgr.Class("PlayerActionHandler")

function PlayerActionHandler:OnInit()
    gg.log("PlayerActionHandler 初始化...")
    self:SubscribeServerEvents()
    self:ListenToPlayerEvents()
    self.activeModule = nil -- 当前激活的行为模块
end

--- 监听本地玩家核心事件（如移动状态变化），并将事件转发给激活的模块
function PlayerActionHandler:ListenToPlayerEvents()
    ---@type Actor
    local actor = gg.getClientLocalPlayer()
    if not actor then
        return
    end

    gg.log("PlayerActionHandler: 成功获取本地玩家 Actor，开始监听事件...")

    -- 监听移动状态变化，并转发给当前模块
    actor.MoveStateChange:Connect(function(before, after)
        if self.activeModule and self.activeModule.OnMoveStateChange then
            self.activeModule:OnMoveStateChange(before, after)
        end
    end)

    -- 新增：监听飞行状态变化，并转发给当前模块
    -- actor.Flying:Connect(function(isFlying)
    --     -- gg.log("PlayerActionHandler: 监听到飞行状态变化，isFlying: ", tostring(isFlying))
    -- end)
end

--- 当具体的行为模块完成其生命周期后，会调用此函数
---@param module table 已经结束的模块实例
function PlayerActionHandler:OnModuleFinished(module)
    -- 确认是当前模块请求的结束
    if self.activeModule == module then
        gg.log("PlayerActionHandler: 已收到模块结束通知，正在清理。")
        self.activeModule = nil
    end
end

--- 订阅所有来自服务端的事件
function PlayerActionHandler:SubscribeServerEvents()
    local launchEventName = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER
    ---@param data LaunchPlayerParams
    ClientEventManager.Subscribe(launchEventName, function(data)
        -- 将事件分发到独立的方法中处理
        self:OnReceiveLaunchCommand(data)
    end)
end

--- 处理来自服务端的通用"发射"或"开始特殊模式"指令
---@param data LaunchPlayerParams
function PlayerActionHandler:OnReceiveLaunchCommand(data)
    gg.log("PlayerActionHandler: 接收到启动指令, 数据: ", gg.table2str(data))

    -- 1. 如果有旧模块在运行，先调用其 OnEnd() 强制结束
    if self.activeModule and self.activeModule.OnEnd then
        gg.log("PlayerActionHandler: 检测到旧模块仍在运行，将强制结束它。")
        self.activeModule:OnEnd()
        self.activeModule = nil -- 立即清除引用
    end

    -- 2. 根据 gameMode 查找对应的模块类
    local gameMode = data.gameMode
    local ModuleClass = ActionModules[gameMode]

    if not ModuleClass then
        gg.log("PlayerActionHandler: 未找到与游戏模式 '" .. tostring(gameMode) .. "' 对应的行为模块。")
        return
    end

    -- 3. 创建模块实例，并开始其生命周期
    gg.log("PlayerActionHandler: 正在创建并启动模块: " .. tostring(gameMode))
    self.activeModule = ModuleClass.New(self) -- 将自身作为 handler 传入
    if self.activeModule.OnStart then
        self.activeModule:OnStart(data)
    end
end

return PlayerActionHandler