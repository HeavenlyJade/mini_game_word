local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask


---@class PlayerActionHandler
local PlayerActionHandler = ClassMgr.Class("PlayerActionHandler")

function PlayerActionHandler:OnInit()
    gg.log("PlayerActionHandler 初始化...")
    self:SubscribeServerEvents()
end

--- 订阅所有来自服务端的事件
function PlayerActionHandler:SubscribeServerEvents()
    -- 从配置中获取事件名
    local launchEventName = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER
    ---@param data LaunchPlayerParams
    ClientEventManager.Subscribe(launchEventName, function(data)
        self:OnLaunchPlayer(data)
    end)
    
    -- 以后可以在这里添加更多事件订阅
    -- ClientEventManager.Subscribe("S2C_AnotherAction", function(data) self:OnAnotherAction(data) end)
end

--- 处理来自服务端的“发射玩家”指令
---@param data LaunchPlayerParams 事件数据，包含发射参数
function PlayerActionHandler:OnLaunchPlayer(data)
    gg.log("接收到 S2C_LaunchPlayer 事件, 数据: ", gg.table2str(data))

    ---@type Character
    local actor = gg.getClientLocalPlayer()
    if not actor then
        gg.log("OnLaunchPlayer: 无法获取客户端本地玩家的 Actor！")
        return
    end

    -- 从配置中获取默认参数
    local eventName = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER
    local defaultConfig = EventPlayerConfig.ACTION_PARAMS[eventName]

    -- 从数据中解析参数，如果数据中没有，则使用配置中的默认值
    local jumpSpeed = data.jumpSpeed or defaultConfig.jumpSpeed
    local moveSpeed = data.moveSpeed or defaultConfig.moveSpeed
    local recoveryDelay = data.recoveryDelay or defaultConfig.recoveryDelay
    local jumpDuration = data.jumpDuration or defaultConfig.jumpDuration

    -- 1. 保存原始速度属性
    local originalJumpSpeed = actor.JumpBaseSpeed
    local originalMoveSpeed = actor.Movespeed
    gg.log(string.format("OnLaunchPlayer: 玩家原始 JumpSpeed: %s, MoveSpeed: %s", tostring(originalJumpSpeed), tostring(originalMoveSpeed)))

    -- 2. 设置一个超高的跳跃速度和前冲速度
    actor.JumpBaseSpeed = jumpSpeed
    actor.Movespeed = moveSpeed
    gg.log(string.format("OnLaunchPlayer: 设置临时 JumpSpeed: %s, MoveSpeed: %s", tostring(actor.JumpBaseSpeed), tostring(actor.Movespeed)))

    -- 3. 执行发射动作 (在客户端执行，保证有效)
    actor:Jump(true)
    gg.log("OnLaunchPlayer: 已调用 Jump(true)")
    
    -- 【核心修正】使用全局的 ScheduledTask 来执行延迟调用，而不是 actor 自身的 timer
    ScheduledTask.AddDelay(jumpDuration, function()
        if actor and not actor.isDestroyed then
            actor:Jump(false)
            gg.log("OnLaunchPlayer (延迟): 已调用 Jump(false)，停止持续跳跃。")
        end
    end)

    -- 4. 在指定延迟后，恢复玩家的所有状态
    ScheduledTask.AddDelay(recoveryDelay, function()
        if actor and not actor.isDestroyed then
            gg.log("OnLaunchPlayer (延迟恢复): 正在恢复属性...")
            actor:StopMove() -- 停止前冲
            actor.JumpBaseSpeed = originalJumpSpeed
            actor.Movespeed = originalMoveSpeed
            gg.log("OnLaunchPlayer (延迟恢复): 玩家属性已恢复。")
        end
    end)
end

-- 可以在这里添加其他服务端事件的处理函数
-- function PlayerActionHandler:OnAnotherAction(data)
--     -- ...
-- end

return PlayerActionHandler