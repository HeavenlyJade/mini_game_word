local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local WorldService = game:GetService("WorldService")
---@class RaceGameAction : Class
-- 飞车挑战赛的行为模块，负责处理该模式下客户端的所有特殊逻辑
local RaceGameAction = ClassMgr.Class("RaceGameAction")

--- 当模块被 PlayerActionHandler 创建时调用
---@param handler PlayerActionHandler 对管理器的引用，用于回调
function RaceGameAction:OnInit(handler)
    gg.log("RaceGameAction: OnInit - 一个新的 RaceGameAction 实例已创建。")
    self.handler = handler
    self.pushTimer = nil -- 用于持续前推的定时器
    self.recoveryTimer = nil -- 用于恢复玩家状态的定时器
    self.stopJumpTimer = nil -- 保留用于可能的延迟跳跃停止逻辑
    self.forceGravityTimer = nil -- 强制落地定时器
    self.originalMoveSpeed = 0
    self.originalJumpSpeed = 0
    self.originalGravity = 0
    self.isEnding = false -- 新增一个状态标记，防止重复结束
    self.respawnPosition = nil -- 【新增】用于存储重生点坐标
end

--- 当游戏模式开始时，由 PlayerActionHandler 调用
---@param data table 服务端发来的 S2C_LaunchPlayer 数据
function RaceGameAction:OnStart(data)
    gg.log("RaceGameAction: OnStart - 模块启动流程开始。")
    gg.log("RaceGameAction: OnStart - 收到的初始化数据: ", data)
    ---@type Actor
    local actor = gg.getClientLocalPlayer()
    if not actor then
        gg.log("RaceGameAction: OnStart - 错误：无法获取到本地玩家 Actor，模块启动失败。")
        self:OnEnd() -- 启动失败也应通知管理器结束
        return
    end
    --gg.log("游戏启动",actor,data)
    -- 1. 解析参数
    local moveSpeed = data.moveSpeed or 400
    local recoveryDelay = data.recoveryDelay or 60  -- 使用服务端传来的比赛时长，默认60秒
    self.respawnPosition = data.respawnPosition -- 【新增】保存重生点坐标
    gg.log(string.format("RaceGameAction: OnStart - 解析参数：速度=%s, 恢复延迟=%s", tostring(moveSpeed), tostring(recoveryDelay)))

    -- 2. 保存原始属性
    self.originalJumpSpeed = actor.JumpBaseSpeed
    self.originalMoveSpeed = actor.Movespeed
    self.originalGravity = actor.Gravity -- 新增：保存原始重力
    
    -- 【新增】禁用玩家WASD移动控制
    local Controller = require(MainStorage.Code.Client.MController) ---@type Controller
    gg.log("RaceGameAction: 禁用玩家WASD移动控制", Controller.m_enableMove)
    self.originalEnableMove = Controller.m_enableMove
    Controller.m_enableMove = false
    
    actor.Gravity =0  -- 应用新的重力值

    actor.Movespeed = moveSpeed
    actor.Animator:Play("Base Layer.fei", 0, 0)
    actor.LocalEuler = Vector3.new(0, 180, 0)

    -- 4. 启动"持续前推"定时器，实现向前滑行效果
    self.pushTimer = SandboxNode.New("Timer", actor)
    self.pushTimer.Name = "RaceGameAction_PushForward"
    self.pushTimer.Delay = 0.3
    self.pushTimer.Interval = 0.3
    self.pushTimer.Loop = true
    self.pushTimer.Callback = function()
        -- if actor:GetCurMoveState() == Enum.BehaviorState.Fly then
            -- 使用 Move 指令让角色相对于相机稳定前移
        actor.Animator:Play("Base Layer.fei", 0, 0)
        -- 修改：使用 relativeToCamera = false，让移动方向不受摄像机旋转影响
        actor:Move(Vector3.new(0, 0, 1), false)
        actor.LocalEuler = Vector3.new(0, 180, 0)
    end
    self.pushTimer:Start()

    -- -- 5. 1秒后停止跳跃并设置JumpBaseSpeed为0，进入滑翔状态
    -- self.stopJumpTimer = ScheduledTask.AddDelay(0.2, "RaceGameAction_StopJump", function()
    --     if actor then
    --         -- actor:Jump(false)  -- 停止跳跃
    --         actor.JumpBaseSpeed = 10 -- 设置跳跃力为0，防止后续跳跃
    --     end
    -- end)

    -- 6. 启动"恢复状态"的延迟调用（主要的比赛时长控制）
    self.recoveryTimer = SandboxNode.New("Timer", actor)
    self.recoveryTimer.Name = "RaceGameAction_Recovery"
    self.recoveryTimer.Delay = recoveryDelay
    self.recoveryTimer.Loop = false
    self.recoveryTimer.Callback = function()
        self:OnEnd()
    end
    self.recoveryTimer:Start()


    local forceGravityDelay = math.min(recoveryDelay ,70) 
    self.forceGravityTimer = SandboxNode.New("Timer", actor)
    self.forceGravityTimer.Name = "RaceGameAction_ForceGravity"
    self.forceGravityTimer.Delay = forceGravityDelay
    self.forceGravityTimer.Loop = false
    self.forceGravityTimer.Callback = function()
        if actor and not self.isEnding then
            actor.Gravity = 500 -- 恢复正常重力，确保玩家能落地
        end
    end
    self.forceGravityTimer:Start()

end


--- 当模块结束时调用，负责所有清理和状态恢复工作
function RaceGameAction:OnEnd()
    gg.log("RaceGameAction: OnEnd - 模块结束流程开始。")
    ---@type Actor
    local actor = gg.getClientLocalPlayer()
    --gg.log("客户的游戏结束")
    if self.isEnding then
        return -- 如果已经在结束流程中，则直接返回，防止重复执行
    end
    self.isEnding = true -- 设置标记，表示开始执行结束流程

    -- 核心修复：立即停止跳跃状态，防止因定时器竞态导致的状态残留
    if actor then
        actor:Jump(false)
        actor:StopMove()
        actor.Animator:Play("Base Layer.Idle", 0, 0)

        -- 恢复属性
        actor.JumpBaseSpeed = self.originalJumpSpeed
        actor.Movespeed = self.originalMoveSpeed
        actor.Gravity = self.originalGravity

        -- 恢复玩家WASD移动控制
        local Controller = require(MainStorage.Code.Client.MController) ---@type Controller
        Controller.m_enableMove = self.originalEnableMove

        -- 【核心改造】执行本地传送
        if self.respawnPosition then
            local TeleportService = game:GetService('TeleportService')
            TeleportService:Teleport(actor, self.respawnPosition)
            --gg.log("RaceGameAction: 已将玩家传送到重生点: " .. tostring(self.respawnPosition))
        else
            --gg.log("RaceGameAction: 警告 - 未收到有效的重生点坐标，无法传送。")
        end
    end

    -- 发送结束通知到服务端
    if gg.network_channel then
        local eventName = EventPlayerConfig.REQUEST.PLAYER_LANDED
        local currentState = actor and actor:GetCurMoveState() or "Unknown"
        gg.network_channel:fireServer({
            cmd = eventName,
            isLanded = (currentState ~= Enum.BehaviorState.Fly), -- 是否真的落地
            finalState = tostring(currentState) -- 最终状态
        })
    end


    -- 清理所有定时器
    if self.pushTimer and not self.pushTimer.isDestroyed then
        self.pushTimer:Stop()
        self.pushTimer:Destroy()
        self.pushTimer = nil
    end
    if self.recoveryTimer and not self.recoveryTimer.isDestroyed then
        self.recoveryTimer:Stop()
        self.recoveryTimer:Destroy()
        self.recoveryTimer = nil
    end
    if self.forceGravityTimer and not self.forceGravityTimer.isDestroyed then
        self.forceGravityTimer:Stop()
        self.forceGravityTimer:Destroy()
        self.forceGravityTimer = nil
    end

    gg.log("RaceGameAction: OnEnd - 所有定时器已清理。")

    -- 通知管理器，本模块已结束
    if self.handler then
        self.handler:OnModuleFinished(self)
        gg.log("RaceGameAction: OnEnd - 已通知 PlayerActionHandler 模块结束。")
    end
end

return RaceGameAction
