local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local WorldService = game:GetService("WorldService")
---@class RaceGameAction : Class
-- 飞车挑战赛的行为模块，负责处理该模式下客户端的所有特殊逻辑
local RaceGameAction = ClassMgr.Class("RaceGameAction")

--- 当模块被 PlayerActionHandler 创建时调用
---@param handler PlayerActionHandler 对管理器的引用，用于回调
function RaceGameAction:OnInit(handler)
    self.handler = handler
    self.pushTimer = nil -- 用于持续前推的定时器
    self.recoveryTimer = nil -- 用于恢复玩家状态的定时器
    self.stopJumpTimer = nil -- 保留用于可能的延迟跳跃停止逻辑
    self.forceGravityTimer = nil -- 强制落地定时器
    self.originalMoveSpeed = 0
    self.originalJumpSpeed = 0
    self.originalGravity = 0
    self.isEnding = false -- 新增一个状态标记，防止重复结束
end

--- 当游戏模式开始时，由 PlayerActionHandler 调用
---@param data table 服务端发来的 S2C_LaunchPlayer 数据
function RaceGameAction:OnStart(data)
    ---@type Actor
    local actor = gg.getClientLocalPlayer()
    if not actor then
        gg.log("RaceGameAction: 无法获取 Actor，模块启动失败。")
        self:OnEnd() -- 启动失败也应通知管理器结束
        return
    end
    gg.log("游戏启动",actor,data)
    -- 1. 解析参数
    local jumpSpeed = data.jumpSpeed
    local moveSpeed = data.moveSpeed
    local recoveryDelay = data.recoveryDelay or 60  -- 使用服务端传来的比赛时长，默认60秒
    local gravity = data.gravity -- 新增：接收重力参数

    -- 2. 保存原始属性
    self.originalJumpSpeed = actor.JumpBaseSpeed
    self.originalMoveSpeed = actor.Movespeed
    self.originalGravity = actor.Gravity -- 新增：保存原始重力
    actor.Gravity =0  -- 应用新的重力值
    gg.log("启动了客户的动画222",actor:GetCurMoveState() )
    gg.log("启动了客户的动画222")
    actor.Movespeed = moveSpeed
    actor.Animator:Play("Base Layer.fei", 0, 0)

    -- 4. 启动"持续前推"定时器，实现向前滑行效果
    self.pushTimer = ScheduledTask.AddInterval(1, "RaceGameAction_PushForward", function()
        -- if actor:GetCurMoveState() == Enum.BehaviorState.Fly then
            -- 使用 Move 指令让角色相对于相机稳定前移
        actor.Animator:Play("Base Layer.fei", 0, 0)
        actor:Move(Vector3.new(0, 0, 1), true)
        -- actor.Animator:Play("Base Layer.fei", 0, 0)

        -- actor.Animator:Play("Base Layer.fei", 0, 0)w
    
    end)
    
    -- -- 5. 1秒后停止跳跃并设置JumpBaseSpeed为0，进入滑翔状态
    -- self.stopJumpTimer = ScheduledTask.AddDelay(0.2, "RaceGameAction_StopJump", function()
    --     if actor then
    --         -- actor:Jump(false)  -- 停止跳跃
    --         actor.JumpBaseSpeed = 10 -- 设置跳跃力为0，防止后续跳跃
    --     end
    -- end)
    
    -- 6. 启动"恢复状态"的延迟调用（主要的比赛时长控制）
    self.recoveryTimer = ScheduledTask.AddDelay(recoveryDelay, "RaceGameAction_Recovery", function()
        self:OnEnd()
    end)
    

    local forceGravityDelay = math.min(recoveryDelay ,70) -- 80%的时间后或45秒后恢复重力
    self.forceGravityTimer = ScheduledTask.AddDelay(forceGravityDelay, "RaceGameAction_ForceGravity", function()
        if actor and not self.isEnding then
            actor.Gravity = -50 -- 恢复正常重力，确保玩家能落地
        end
    end)

end


--- 当模块结束时调用，负责所有清理和状态恢复工作
function RaceGameAction:OnEnd()
    ---@type Actor
    local actor = gg.getClientLocalPlayer()
    gg.log("客户的游戏结束")
    if self.isEnding then
        actor.Animator:Play("Base Layer.Idle", 0, 0)

        return -- 如果已经在结束流程中，则直接返回，防止重复执行
    end
    self.isEnding = true -- 设置标记，表示开始执行结束流程



    -- 核心修复：立即停止跳跃状态，防止因定时器竞态导致的状态残留
    actor:Jump(false)
    actor.Animator:Play("Base Layer.Idle", 0, 0)

    -- 恢复属性
    actor:StopMove()
    actor.JumpBaseSpeed = self.originalJumpSpeed
    actor.Movespeed = self.originalMoveSpeed
    actor.Gravity = self.originalGravity 

    -- 发送结束通知到服务端
    if gg.network_channel then
        local eventName = EventPlayerConfig.REQUEST.PLAYER_LANDED
        local currentState = actor:GetCurMoveState()
        gg.network_channel:fireServer({ 
            cmd = eventName,
            isLanded = (currentState ~= Enum.BehaviorState.Fly), -- 是否真的落地
            finalState = tostring(currentState) -- 最终状态
        })
    end


    -- 清理所有定时器
    if self.pushTimer then ScheduledTask.Remove(self.pushTimer) self.pushTimer = nil end
    if self.recoveryTimer then ScheduledTask.Remove(self.recoveryTimer) self.recoveryTimer = nil end
    if self.stopJumpTimer then ScheduledTask.Remove(self.stopJumpTimer) self.stopJumpTimer = nil end
    if self.forceGravityTimer then ScheduledTask.Remove(self.forceGravityTimer) self.forceGravityTimer = nil end

    -- 通知管理器，本模块已结束
    if self.handler then
        self.handler:OnModuleFinished(self)
    end
end

return RaceGameAction