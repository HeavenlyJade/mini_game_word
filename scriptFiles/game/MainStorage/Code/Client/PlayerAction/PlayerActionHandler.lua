local Enum = Enum
local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

-- 【重构】行为模块注册表
local ActionModules = {
    [EventPlayerConfig.GAME_MODES.RACE_GAME] = require(MainStorage.Code.Client.PlayerAction.ActionModules.RaceGameAction),
    [EventPlayerConfig.PLAYER_ACTION.PLAYER_ANIMATION] = require(MainStorage.Code.Client.PlayerAction.ActionModules.PlayerAnimationAction),
    -- 未来新增其他模式的模块，在此处注册即可
}


---@class PlayerActionHandler : Class
-- 客户端玩家行为的"管理器"，负责加载和管理不同游戏模式下的具体行为模块。
local PlayerActionHandler = ClassMgr.Class("PlayerActionHandler")

function PlayerActionHandler:OnInit()
    -- --gg.log("PlayerActionHandler 初始化...")
    self:SubscribeServerEvents()
    self:ListenToPlayerEvents()
    self.activeModule = nil -- 当前激活的行为模块
    self.gameMode = nil
end

--- 监听本地玩家核心事件（如移动状态变化），并将事件转发给激活的模块
function PlayerActionHandler:ListenToPlayerEvents()
    ---@type Actor
    local actor = gg.getClientLocalPlayer()
    if not actor then
        return
    end


    -- 监听移动状态变化，并转发给当前模块
    -- actor.MoveStateChange:Connect(function(before, after)
    --     if self.activeModule and self.activeModule.OnMoveStateChange then
    --         self.activeModule:OnMoveStateChange(before, after)
    --     end
    -- end)

    -- 新增：监听飞行状态变化，并转发给当前模块
    -- actor.Flying:Connect(function(isFlying)
    --     -- EventPlayerConfig.PLAYER_ACTION.PLAYER_ANIMATION
    --     if isFlying and self.gameMode == EventPlayerConfig.PLAYER_ACTION.PLAYER_ANIMATION then
    --         actor.Animator:Play("Base Layer.fei", 0, 0)
    --     end
        
    -- end)
end

--- 当具体的行为模块完成其生命周期后，会调用此函数
---@param module table 已经结束的模块实例
function PlayerActionHandler:OnModuleFinished(module)
    -- 确认是当前模块请求的结束
    if self.activeModule == module then
        --gg.log("PlayerActionHandler: 已收到模块结束通知，正在清理。")
        self.activeModule = nil
        self.gameMode = nil
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
    
    -- 订阅导航事件
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.NAVIGATE_TO_POSITION, function(data)
        self:OnNavigateToPosition(data)
    end)

    -- 订阅停止导航事件
    ClientEventManager.Subscribe("STOP_NAVIGATION", function(data)
        self:OnStopNavigation(data)
    end)

    

    -- 新增：比赛界面隐藏事件强制结束当前行为模块
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_CONTEST_HIDE, function(_)
        if self.activeModule and self.activeModule.OnEnd then
            self.activeModule:OnEnd()
            self.activeModule = nil
            self.gameMode = nil
        end
    end)
end

--- 处理来自服务端的通用"发射"或"开始特殊模式"指令
---@param data LaunchPlayerParams
function PlayerActionHandler:OnReceiveLaunchCommand(data)
    -- --gg.log("PlayerActionHandler: 接收到启动指令, 数据: ", gg.table2str(data))

    -- 1. 如果有旧模块在运行，先调用其 OnEnd() 强制结束
    if self.activeModule and self.activeModule.OnEnd then
        --gg.log("PlayerActionHandler: 检测到旧模块仍在运行，将强制结束它。")
        self.activeModule:OnEnd()
        self.activeModule = nil -- 立即清除引用
        self.gameMode =nil
    end

    -- 2. 根据 gameMode 查找对应的模块类
    local gameMode = data.gameMode
    local ModuleClass = ActionModules[gameMode]
    self.gameMode = gameMode

    if not ModuleClass then
        --gg.log("PlayerActionHandler: 未找到与游戏模式 '" .. tostring(gameMode) .. "' 对应的行为模块。")
        return
    end

    -- 3. 创建模块实例，并开始其生命周期
    --gg.log("PlayerActionHandler: 正在创建并启动模块: " .. tostring(gameMode))
    self.activeModule = ModuleClass.New(self) -- 将自身作为 handler 传入
    if self.activeModule.OnStart then
        self.activeModule:OnStart(data)
    end
    
    -- 4. 检查是否需要根据飞行状态执行动画
    self:CheckAndExecuteFlyingAnimation(data)
end

--- 根据指令参数和飞行状态检查是否需要执行飞行动画
---@param data LaunchPlayerParams
function PlayerActionHandler:CheckAndExecuteFlyingAnimation(data)
    local actor = gg.getClientLocalPlayer()
    if not actor then
        return
    end
    
    -- 检查是否为动画控制模式
    if data.gameMode ~= "PLAYER_ANIMATION" then
        return
    end
    
    -- 检查是否为挂机场景或飞行比赛场景
    local isIdleScene = data.isIdleScene == true
    local isRaceScene = data.sceneType == "飞行比赛场景"
    local operationType = data.operationType
    
    -- 获取当前飞行状态
    local isFlying = actor.Flying.Value
    
    -- --gg.log("PlayerActionHandler: 检查飞行动画执行条件", {
    --     isIdleScene = isIdleScene,
    --     isRaceScene = isRaceScene,
    --     isFlying = isFlying,
    --     operationType = data.operationType
    -- })
    if operationType =="取消飞行" then
        self.gameMode =nil

    end

end

--- 处理导航到指定位置的请求
---@param data NavigateToPositionParams 导航数据
function PlayerActionHandler:OnNavigateToPosition(data)
    --gg.log("PlayerActionHandler: 接收到导航请求, 数据: ", --gg.log(data))
    if not data or not data.position then
        --gg.log("PlayerActionHandler: 导航请求缺少位置信息")
        return
    end
    
    local actor = gg.getClientLocalPlayer()
    self:OnStopNavigation(data)
    -- 从表中重建 Vector3
    local positionData = data.position
    local targetPosition = Vector3.New(positionData.x, positionData.y, positionData.z)
    
    -- 执行导航
    actor:MoveTo(targetPosition)

    actor:NavigateTo(targetPosition)
    
    gg.log("PlayerActionHandler: 已开始导航到位置: " .. tostring(targetPosition),actor.uin)

end

--- 处理停止导航请求
---@param data table 停止导航数据
function PlayerActionHandler:OnStopNavigation(data)
    local actor = gg.getClientLocalPlayer()
    if not actor then
        return
    end
    
    -- 停止当前导航
    actor:StopNavigate()
    actor:StopMove()
end

--- 客户端导航方法 - 供其他模块调用
---@param targetPosition Vector3 目标位置
---@param message string 可选的消息
function PlayerActionHandler:NavigateToPosition(targetPosition, message)
    if not targetPosition then
        --gg.log("PlayerActionHandler: 导航目标位置为空")
        return
    end
    
    local actor = gg.getClientLocalPlayer()
    if not actor then
        --gg.log("PlayerActionHandler: 无法获取本地玩家Actor")
        return
    end
    
    -- 直接执行导航
    actor:NavigateTo(targetPosition)
    
    if message then
        --gg.log("PlayerActionHandler: " .. message)
    else
        --gg.log("PlayerActionHandler: 已开始导航到位置: " .. tostring(targetPosition))
    end
end

return PlayerActionHandler
