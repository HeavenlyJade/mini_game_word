--- 玩家事件配置文件
--- 包含所有与玩家通用操作相关的事件名称、参数和错误码
--- V109 miniw-haima

---@class EventPlayerConfig
local EventPlayerConfig = {}

---@class LaunchPlayerParams
---@field jumpSpeed number
---@field moveSpeed number
---@field recoveryDelay number
---@field jumpDuration number

--[[
===================================
网络事件定义
===================================
]]

-- 客户端请求事件 (C2S)
EventPlayerConfig.REQUEST = {
    -- e.g., REQUEST_JUMP = "PlayerRequest_Jump"
}

-- 服务器响应事件 (S2C)
EventPlayerConfig.RESPONSE = {
    -- e.g., JUMP_RESPONSE = "PlayerResponse_Jump"
}

-- 服务器通知事件 (S2C)
-- 这些是由服务器主动发起的，用于指令客户端对玩家进行操作的事件
EventPlayerConfig.NOTIFY = {
    LAUNCH_PLAYER = "S2C_LaunchPlayer",
}

--[[
===================================
动作参数定义
===================================
--]]

-- 定义了与服务器通知事件相关联的具体参数
---@type table<string, LaunchPlayerParams>
EventPlayerConfig.ACTION_PARAMS = {
    -- 使用事件名作为键，方便查找
    [EventPlayerConfig.NOTIFY.LAUNCH_PLAYER] = {
        jumpSpeed = 4000,     -- 发射高度
        moveSpeed = 1000,     -- 发射远度
        recoveryDelay = 1.5,  -- 恢复所有状态的延迟
        jumpDuration = 0.5    -- Jump(true)的持续时间
    }
}

--[[
===================================
错误码和错误消息定义
===================================
]]

-- 错误码定义
EventPlayerConfig.ERROR_CODES = {
    SUCCESS = 0,
    PLAYER_IS_DEAD = 1,         -- 玩家已死亡
    PLAYER_IS_STUNNED = 2,      -- 玩家处于眩晕状态
    PLAYER_IN_CUTSCENE = 3,     -- 玩家在过场动画中
}

-- 错误消息映射
EventPlayerConfig.ERROR_MESSAGES = {
    [EventPlayerConfig.ERROR_CODES.SUCCESS] = "操作成功",
    [EventPlayerConfig.ERROR_CODES.PLAYER_IS_DEAD] = "玩家已死亡，无法执行该操作",
    [EventPlayerConfig.ERROR_CODES.PLAYER_IS_STUNNED] = "玩家处于眩晕状态，无法执行该操作",
    [EventPlayerConfig.ERROR_CODES.PLAYER_IN_CUTSCENE] = "玩家正在过场动画中，无法执行该操作",
}

--[[
===================================
配置辅助函数
===================================
]]

--- 获取错误消息
---@param errorCode number 错误码
---@return string 错误消息
function EventPlayerConfig.GetErrorMessage(errorCode)
    return EventPlayerConfig.ERROR_MESSAGES[errorCode] or "未知错误"
end

--- 获取动作参数
---@param eventName string 事件名称
---@return table|nil 参数表
function EventPlayerConfig.GetActionParams(eventName)
    return EventPlayerConfig.ACTION_PARAMS[eventName]
end

return EventPlayerConfig