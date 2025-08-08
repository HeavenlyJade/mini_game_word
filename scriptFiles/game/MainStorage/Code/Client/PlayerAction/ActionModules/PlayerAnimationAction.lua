--- 客户端玩家动画控制模块
--- 放置位置：scriptFiles/game/MainStorage/Code/Client/PlayerAction/ActionModules/PlayerAnimationAction.lua

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class PlayerAnimationAction : Class
-- 玩家动画控制模块，处理各种动画和状态控制
local PlayerAnimationAction = ClassMgr.Class("PlayerAnimationAction")

--- 当模块被 PlayerActionHandler 创建时调用
---@param handler PlayerActionHandler 对管理器的引用，用于回调
function PlayerAnimationAction:OnInit(handler)
    self.handler = handler
    self.isActive = false -- 是否处于激活状态
    
    -- 保存原始状态
    self.originalMoveSpeed = 0
    self.originalJumpSpeed = 0
    self.originalGravity = 0
    self.originalEnableMove = nil
    
    -- 定时器
    self.animationTimer = nil
    self.recoveryTimer = nil
end

--- 启动动画控制模式
---@param data table 服务端发来的动画控制数据
function PlayerAnimationAction:OnStart(data)
    --gg.log("PlayerAnimationAction: 开始启动动画控制模块，数据:", gg.table2str(data))
    
    ---@type Actor
    local actor = gg.getClientLocalPlayer()
    if not actor then
        --gg.log("PlayerAnimationAction: 无法获取 Actor，模块启动失败")
        self:OnEnd()
        return
    end
    
    --gg.log("PlayerAnimationAction: 启动动画控制", data)
    
    -- 保存服务端发送的原始状态值（如果有的话）
    if data.originalGravity then
        self.serverOriginalGravity = data.originalGravity
        --gg.log("PlayerAnimationAction: 接收到服务端原始重力值:", data.originalGravity)
    end
    if data.originalMoveSpeed then
        self.serverOriginalMoveSpeed = data.originalMoveSpeed
    end
    if data.originalJumpSpeed then
        self.serverOriginalJumpSpeed = data.originalJumpSpeed
    end
    
    -- 保存原始状态
    self:SaveOriginalState(actor)
    
    local operationType = data.operationType or "启动飞行"
    
    if operationType == "启动飞行" then
        self:StartFlyAnimation(data, actor)
    elseif operationType == "设置动画" then
        self:SetAnimation(data, actor)
    elseif operationType == "设置重力" then
        self:SetGravity(data, actor)
    elseif operationType == "设置移动速度" then
        self:SetMoveSpeed(data, actor)
    elseif operationType == "取消飞行" then
        self:StopFlyAnimation(actor)
    elseif operationType == "强制停止" then
        self:ForceStop(actor)
    else
        --gg.log("PlayerAnimationAction: 未知的操作类型:", operationType)
        self:OnEnd()
    end
end

--- 保存玩家原始状态
---@param actor Actor
function PlayerAnimationAction:SaveOriginalState(actor)
    if self.isActive then return end -- 避免重复保存
    
    self.originalMoveSpeed = actor.Movespeed
    self.originalJumpSpeed = actor.JumpBaseSpeed
    self.originalGravity = actor.Gravity
    
    -- 保存移动控制状态
    local Controller = require(MainStorage.Code.Client.MController) ---@type Controller
    self.originalEnableMove = Controller.m_enableMove
    
    self.isActive = true

end

--- 启动飞行动画
---@param data table 数据参数
---@param actor Actor 玩家Actor
function PlayerAnimationAction:StartFlyAnimation(data, actor)
    local animationName = data.animationName or "Base Layer.fei"
    local gravityValue = data.gravityValue or 0
    local disableMovement = data.disableMovement ~= false -- 默认为true
    local duration = data.duration -- 可选的持续时间
    local isIdleScene = data.isIdleScene or false -- 是否为挂机场景
    local sceneType = data.sceneType or "普通场景"
    

    -- 设置飞行状态
    actor.Gravity = gravityValue
    actor.Animator:Play(animationName, 0, 0)
    
    
    -- 禁用移动控制
    if disableMovement then
        local Controller = require(MainStorage.Code.Client.MController) ---@type Controller
        Controller.m_enableMove = false
    end
    
    -- 保存挂机场景信息
    self.isIdleScene = isIdleScene
    self.sceneType = sceneType
    

    -- 如果指定了持续时间，设置自动恢复
    if duration and duration > 0 then
        self.recoveryTimer = ScheduledTask.AddDelay(duration, "PlayerAnimation_AutoRecover", function()
            self:StopFlyAnimation(actor)
        end)
    end
end

--- 停止飞行动画
---@param actor Actor 玩家Actor
function PlayerAnimationAction:StopFlyAnimation(actor)
    if not self.isActive then
        --gg.log("PlayerAnimationAction: 未处于激活状态，无需停止")
        return
    end
    
    -- 设置状态为未激活
    self.isActive = false
    self.gameMode = nil
    
    -- 记录恢复前的状态

    
    
    -- 使用服务端发送的原始状态值（如果有的话）
    local targetGravity = self.originalGravity
    local targetMoveSpeed = self.originalMoveSpeed
    local targetJumpSpeed = self.originalJumpSpeed
    
    -- 如果服务端发送了原始值，优先使用服务端的值
    if self.serverOriginalGravity then
        targetGravity = self.serverOriginalGravity
        --gg.log("PlayerAnimationAction: 使用服务端发送的原始重力值:", targetGravity)
    end
    if self.serverOriginalMoveSpeed then
        targetMoveSpeed = self.serverOriginalMoveSpeed
    end
    if self.serverOriginalJumpSpeed then
        targetJumpSpeed = self.serverOriginalJumpSpeed
    end
    
    -- 恢复物理状态
    actor.Gravity = targetGravity
    actor.Movespeed = targetMoveSpeed
    actor.JumpBaseSpeed = targetJumpSpeed
    
    -- 停止当前动作
    actor:StopMove()
    actor:Jump(false)
    
    -- 恢复移动控制
    if self.originalEnableMove ~= nil then
        local Controller = require(MainStorage.Code.Client.MController) ---@type Controller
        Controller.m_enableMove = self.originalEnableMove
    end
    
    -- 记录恢复后的状态

    
    --gg.log("PlayerAnimationAction: 已停止飞行动画并恢复原始状态")
    
    -- 结束模块
    self:OnEnd()
end

--- 设置动画（不影响物理状态）
---@param data table 数据参数
---@param actor Actor 玩家Actor
function PlayerAnimationAction:SetAnimation(data, actor)
    local animationName = data.animationName
    if not animationName then
        --gg.log("PlayerAnimationAction: 缺少动画名称")
        self:OnEnd()
        return
    end
    
    actor.Animator:Play(animationName, 0, 0)
    --gg.log("PlayerAnimationAction: 已设置动画", animationName)
    
    -- 设置动画后立即结束模块（因为不需要持续管理）
    self:OnEnd()
end

--- 设置重力
---@param data table 数据参数
---@param actor Actor 玩家Actor
function PlayerAnimationAction:SetGravity(data, actor)
    local gravityValue = data.gravityValue
    if not gravityValue then
        --gg.log("PlayerAnimationAction: 缺少重力值")
        self:OnEnd()
        return
    end
    
    actor.Gravity = gravityValue
    --gg.log("PlayerAnimationAction: 已设置重力", gravityValue)
    
    -- 设置重力后立即结束模块
    self:OnEnd()
end

--- 设置移动速度
---@param data table 数据参数
---@param actor Actor 玩家Actor
function PlayerAnimationAction:SetMoveSpeed(data, actor)
    local moveSpeed = data.moveSpeed
    if not moveSpeed then
        --gg.log("PlayerAnimationAction: 缺少移动速度值")
        self:OnEnd()
        return
    end
    
    actor.Movespeed = moveSpeed
    --gg.log("PlayerAnimationAction: 已设置移动速度", moveSpeed)
    
    -- 设置移动速度后立即结束模块
    self:OnEnd()
end

--- 强制停止所有动画控制
---@param actor Actor 玩家Actor
function PlayerAnimationAction:ForceStop(actor)
    if not self.isActive then
        --gg.log("PlayerAnimationAction: 未处于激活状态，无需强制停止")
        self:OnEnd()
        return
    end
    
    --gg.log("PlayerAnimationAction: 强制停止动画控制")
    
    -- 立即恢复所有状态
    actor.Animator:Play("Base Layer.Idle", 0, 0)
    actor.Gravity = self.originalGravity
    actor.Movespeed = self.originalMoveSpeed
    actor.JumpBaseSpeed = self.originalJumpSpeed
    
    -- 停止所有动作
    actor:StopMove()
    actor:Jump(false)
    
    -- 恢复移动控制
    if self.originalEnableMove ~= nil then
        local Controller = require(MainStorage.Code.Client.MController) ---@type Controller
        Controller.m_enableMove = self.originalEnableMove
    end
    
    --gg.log("PlayerAnimationAction: 强制停止完成")
    
    -- 结束模块
    self:OnEnd()
end



--- 当模块结束时调用，负责清理工作
function PlayerAnimationAction:OnEnd()
    if not self.isActive then
        return -- 已经结束过了
    end
    
    --gg.log("PlayerAnimationAction: 模块结束，正在清理")
    
    -- 清理定时器
    if self.animationTimer then
        ScheduledTask.Remove(self.animationTimer)
        self.animationTimer = nil
    end
    
    if self.recoveryTimer then
        ScheduledTask.Remove(self.recoveryTimer)
        self.recoveryTimer = nil
    end
    
    -- 重置状态
    self.isActive = false
    
    -- 通知管理器，本模块已结束
    if self.handler then
        self.handler:OnModuleFinished(self)
    end
end

return PlayerAnimationAction