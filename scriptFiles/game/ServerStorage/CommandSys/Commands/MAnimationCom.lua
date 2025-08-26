--- 玩家动画控制指令处理器（客户端-服务端协作版）

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class AnimationCommand
local AnimationCommand = {}

-- 子命令处理器
AnimationCommand.handlers = {}

-- 玩家状态缓存，仅用于服务端状态跟踪
local playerStates = {} ---@type table<number, table>

--- 私有方法：保存玩家状态记录（仅用于服务端跟踪）
---@param uin number 玩家uin
---@param player MPlayer 玩家对象
function AnimationCommand._savePlayerState(uin, player)
    if not player or not player.actor then
        return false
    end
    
    -- 保存玩家的原始状态，包括重力值
    playerStates[uin] = {
        isFlying = false, -- 标记是否处于飞行状态
        isControlled = false, -- 标记是否被动画系统控制
        originalGravity = player.actor.Gravity, -- 保存原始重力值
        originalMoveSpeed = player.actor.Movespeed, -- 保存原始移动速度
        originalJumpSpeed = player.actor.JumpBaseSpeed -- 保存原始跳跃速度
    }
    
    gg.log("已记录玩家动画状态", uin, "原始重力:", player.actor.Gravity)
    return true
end

--- 私有方法：清理玩家状态记录
---@param uin number 玩家uin
function AnimationCommand._clearPlayerState(uin)
    if playerStates[uin] then
        playerStates[uin] = nil
        gg.log("已清理玩家动画状态记录", uin)
    end
end

--- 启动飞行动画
---@param params table 命令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function AnimationCommand.handlers.startFly(params, player)
    local uin = player.uin
    
    -- 检查玩家是否已在飞行状态
    if playerStates[uin] and playerStates[uin].isFlying then
        player:SendHoverText("玩家已处于飞行状态")
        return false
    end
    
    -- 保存玩家状态记录（用于服务端跟踪）
    AnimationCommand._savePlayerState(uin, player)
    local launchEventName = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER
    
    -- 检查场景类型
    local isIdleScene = params["挂机场景"] == true
    local isRaceScene = params["飞行比赛场景"] == true
    local sceneType = "普通场景"
    
    if isIdleScene then
        sceneType = "挂机场景"
    elseif isRaceScene then
        sceneType = "飞行比赛场景"
    end
    
    -- 准备发送给客户端的数据
    local clientData = {
        cmd = launchEventName, -- 添加事件名称
        gameMode = EventPlayerConfig.PLAYER_ACTION.PLAYER_ANIMATION, -- 定义一个新的游戏模式
        operationType = "启动飞行",
        animationName = params["动画名称"] or "Base Layer.fei",
        gravityValue = params["重力值"] or 0,
        disableMovement = params["禁用移动"] ~= false, -- 默认为true
        duration = params["持续时间"], -- 可选的持续时间
        isIdleScene = isIdleScene, -- 是否为挂机场景
        sceneType = sceneType -- 场景类型
    }
    
    -- 发送事件到客户端
    gg.network_channel:fireClient(player.uin, clientData)
    
    -- 标记为飞行状态
    if playerStates[uin] then
        playerStates[uin].isFlying = true
        playerStates[uin].isControlled = true
        playerStates[uin].isIdleScene = isIdleScene -- 保存挂机场景标记
    end
    
    local msg = string.format("玩家 %s 已启动飞行模式（%s），动画: %s，重力: %s", 
        player.name, sceneType, clientData.animationName, tostring(clientData.gravityValue))
    -- player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 取消飞行动画
---@param params table 命令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function AnimationCommand.handlers.stopFly(params, player)
    local uin = player.uin
    
    -- 检查玩家是否处于飞行状态
    if not playerStates[uin] or not playerStates[uin].isFlying then
        -- player:SendHoverText("玩家未处于飞行状态")
        return false
    end
    
    -- 获取服务端保存的原始状态
    local originalState = playerStates[uin]
    local launchEventName = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER
    -- 准备发送给客户端的数据
    local clientData = {
        cmd = launchEventName, -- 添加事件名称
        gameMode = EventPlayerConfig.PLAYER_ACTION.PLAYER_ANIMATION,
        operationType = "取消飞行",
        originalGravity = 980, -- 发送原始重力值
        originalMoveSpeed = 400, -- 发送原始移动速度
        originalJumpSpeed = 400 -- 发送原始跳跃速度
    }
    
    -- 发送事件到客户端
    gg.network_channel:fireClient(player.uin, clientData)
    
    -- 清理服务端状态记录
    AnimationCommand._clearPlayerState(uin)
    
    local msg = string.format("玩家 %s 已取消飞行模式，恢复重力: %s", player.name, tostring(originalState.originalGravity))
    -- player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 设置玩家动画（不影响物理状态）
---@param params table 命令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function AnimationCommand.handlers.setAnimation(params, player)
    local animationName = params["动画名称"]
    
    if not animationName then
        player:SendHoverText("缺少'动画名称'字段")
        return false
    end
    
    -- 准备发送给客户端的数据
    local clientData = {
        cmd = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER, -- 添加事件名称
        gameMode = "PLAYER_ANIMATION",
        operationType = "设置动画",
        animationName = animationName
    }
    
    -- 发送事件到客户端
    gg.network_channel:fireClient(player.uin, clientData)
    
    local msg = string.format("玩家 %s 动画已设置为: %s", player.name, animationName)
    -- player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 设置玩家重力
---@param params table 命令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function AnimationCommand.handlers.setGravity(params, player)
    local gravityValue = params["重力值"]
    
    if not gravityValue then
        player:SendHoverText("缺少'重力值'字段")
        return false
    end
    
    -- 准备发送给客户端的数据
    local clientData = {
        cmd = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER, -- 添加事件名称
        gameMode = "PLAYER_ANIMATION",
        operationType = "设置重力",
        gravityValue = gravityValue
    }
    
    -- 发送事件到客户端
    gg.network_channel:fireClient(player.uin, clientData)
    
    local msg = string.format("玩家 %s 重力已设置为: %s", player.name, tostring(gravityValue))
    -- player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 设置玩家移动速度
---@param params table 命令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function AnimationCommand.handlers.setMoveSpeed(params, player)
    local moveSpeed = params["移动速度"]
    
    if not moveSpeed then
        player:SendHoverText("缺少'移动速度'字段")
        return false
    end
    
    -- 准备发送给客户端的数据
    local clientData = {
        cmd =   EventPlayerConfig.NOTIFY.LAUNCH_PLAYER, -- 添加事件名称
        gameMode = "PLAYER_ANIMATION",
        operationType = "设置移动速度",
        moveSpeed = moveSpeed
    }
    
    -- 发送事件到客户端
    gg.network_channel:fireClient(player.uin, clientData)
    
    local msg = string.format("玩家 %s 移动速度已设置为: %s", player.name, tostring(moveSpeed))
    -- player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 强制取消玩家动画控制状态（服务端调用）
---@param params table 命令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function AnimationCommand.handlers.forceStop(params, player)
    local uin = player.uin
    
    -- 准备发送给客户端的数据
    local clientData = {
        cmd = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER, -- 添加事件名称
        gameMode = "PLAYER_ANIMATION",
        operationType = "强制停止"
    }
    
    -- 发送事件到客户端
    gg.network_channel:fireClient(player.uin, clientData)
    
    -- 清理服务端状态记录
    AnimationCommand._clearPlayerState(uin)
    
    local msg = string.format("玩家 %s 的动画控制已被强制停止", player.name)
    -- player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 玩家离线时清理状态
---@param uin number 玩家uin
function AnimationCommand.OnPlayerLeave(uin)
    AnimationCommand._clearPlayerState(uin)
end

--- 检查玩家是否处于动画控制状态
---@param uin number 玩家uin
---@return boolean 是否被控制
function AnimationCommand.IsPlayerControlled(uin)
    return playerStates[uin] and playerStates[uin].isControlled or false
end

--- 检查玩家是否处于飞行状态
---@param uin number 玩家uin
---@return boolean 是否在飞行
function AnimationCommand.IsPlayerFlying(uin)
    return playerStates[uin] and playerStates[uin].isFlying or false
end

-- 中文到英文的映射
local operationMap = {
    ["启动飞行"] = "startFly",
    ["取消飞行"] = "stopFly",
    ["设置动画"] = "setAnimation",
    ["设置重力"] = "setGravity",
    ["设置移动速度"] = "setMoveSpeed",
    ["强制停止"] = "forceStop"
}

--- 动画控制指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function AnimationCommand.main(params, player)
    local operationType = params["操作类型"]
    
    if not operationType then
        player:SendHoverText("缺少'操作类型'字段。有效类型: '启动飞行', '取消飞行', '设置动画', '设置重力', '设置移动速度', '强制停止'")
        return false
    end
    
    -- 将中文指令映射到英文处理器
    local handlerName = operationMap[operationType]
    if not handlerName then
        player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '启动飞行', '取消飞行', '设置动画', '设置重力', '设置移动速度', '强制停止'")
        return false
    end
    
    local handler = AnimationCommand.handlers[handlerName]
    if handler then
        gg.log("动画控制指令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

--- 获取指令帮助信息
---@return string 帮助信息
function AnimationCommand.GetHelp()
    return [[
动画控制指令帮助：

基础指令：
- 启动飞行：启动玩家飞行动画
- 取消飞行：停止飞行动画并恢复原始状态
- 设置动画：设置玩家动画（不影响物理状态）
- 设置重力：设置玩家重力值
- 设置移动速度：设置玩家移动速度
- 强制停止：强制停止所有动画控制

场景支持：
- 挂机场景：挂机场景 = true/false
- 飞行比赛场景：飞行比赛场景 = true/false
- 当设置为特定场景时，系统会根据玩家的飞行状态自动调整动画
- 只有在特定场景下且玩家正在飞行时才会执行飞行动画

使用示例：
animation { 操作类型=启动飞行, 挂机场景=true, 重力值=0, 动画名称="Base Layer.fei" }
animation { 操作类型=启动飞行, 飞行比赛场景=true, 重力值=0, 动画名称="Base Layer.fei" }
animation { 操作类型=取消飞行 }
    ]]
end

return AnimationCommand