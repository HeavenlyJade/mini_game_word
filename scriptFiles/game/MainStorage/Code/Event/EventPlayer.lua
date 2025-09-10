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
---@field gameMode string

---@class NavigateToPositionParams
---@field position Vector3 目标位置
---@field message string 可选的消息


--[[
===================================
网络事件定义
===================================
]]

-- 客户端请求事件 (C2S)
EventPlayerConfig.REQUEST = {
    -- e.g., REQUEST_JUMP = "PlayerRequest_Jump"
    PLAYER_LANDED = "cmd_player_landed", -- 新增：玩家落地事件
    AUTO_RACE_TOGGLE = "AutoRaceToggle", -- 自动比赛开关
    AUTO_PLAY_TOGGLE = "AutoPlayToggle", -- 自动挂机开关
    UNSTUCK_PLAYER = "UnstuckPlayer", -- 脱离卡死
    REQUEST_LEAVE_IDLE = "RequestLeaveIdle", -- 新增：请求离开挂机
    LEVEL_REWARD_NODE_TRIGGERED = "LevelRewardNodeTriggered", -- 关卡奖励节点触发

}


-- 服务器通知事件 (S2C)
-- 这些是由服务器主动发起的，用于指令客户端对玩家进行操作的事件
EventPlayerConfig.NOTIFY = {
    LAUNCH_PLAYER = "S2C_LaunchPlayer",
    PLAYER_ANIMATION_CONTROL = "S2C_PlayerAnimationControl",
    PLAYER_DATA_SYNC_VARIABLE = "PlayerDataSync_Variable", -- 同步变量
    PLAYER_DATA_SYNC_QUEST = "PlayerDataSync_Quest", -- 同步任务
    PLAYER_DATA_LOADED = "PlayerDataLoaded", -- 玩家数据加载完成
    NAVIGATE_TO_POSITION = "NavigateToPosition", -- 导航到指定位置
    PLAYER_DATA_SYNC_LEVEL_EXP = "PlayerDataSync_LevelExp", -- 同步玩家等级和经验
    RACE_CONTEST_UPDATE = "RaceContestUpdate", -- 比赛数据更新
    RACE_CONTEST_SHOW = "RaceContestShow", -- 显示比赛界面
    RACE_CONTEST_HIDE = "RaceContestHide", -- 隐藏比赛界面
    RACE_PREPARE_COUNTDOWN = "RacePrepareCountdown", -- 比赛准备倒计时
    RACE_PREPARE_COUNTDOWN_STOP = "RacePrepareCountdownStop", -- 停止比赛准备倒计时
    AUTO_RACE_STOPPED = "AutoRaceStopped", -- 新增：自动比赛被停止
    ITEM_ACQUIRED_NOTIFY = "ItemAcquiredNotify", -- 获得物品通知
    AUTO_RACE_RESPONSE = "AutoRaceResponse", -- 新增：自动比赛请求的响应
    STOP_NAVIGATION = "StopNavigation", -- 新增：停止导航
    AUTO_RACE_STARTED = "AutoRaceStarted", -- 新增：自动比赛已开始
    AUTO_PLAY_STARTED = "AutoPlayStarted", -- 新增：自动挂机已开始
    AUTO_PLAY_STOPPED = "AutoPlayStopped", -- 新增：自动挂机已停止
    PLAYER_LAUNCH_END = "sPlayerLaunchEnd", -- 玩家发射结束
    -- 【新增】玩家切换地图通知
    PLAYER_MAP_CHANGED = "sPlayerMapChanged", -- 玩家地图切换
    LEAVE_IDLE_SUCCESS = "LeaveIdleSuccess", -- 新增：离开挂机成功通知
    PLAYER_STAT_SYNC = "cmd_sync_player_stat", -- 新增：玩家属性同步
    -- 【新增】广播：当前房间所有玩家（用于客户端刷新好友/房间加成等）
    ROOM_PLAYERS_BROADCAST = "RoomPlayersBroadcast",
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
        jumpSpeed = 200,     -- 发射高度
        moveSpeed = 400,      -- 速度（修改为100）
        recoveryDelay = 0.0,  -- 恢复延迟
        jumpDuration = 0.5,   -- Jump(true)的持续时间
        gameMode = ""         -- 游戏模式（调用方可覆盖）
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

-- 游戏模式枚举
EventPlayerConfig.GAME_MODES = {
    NONE = nil, -- 无特殊模式
    RACE_GAME = "飞车挑战赛" -- 飞车挑战赛
}

-- 物品类型枚举
EventPlayerConfig.ITEM_TYPES = {
    ITEM = "物品",           -- 背包物品
    PET = "宠物",            -- 宠物
    PARTNER = "伙伴",        -- 伙伴
    WING = "翅膀",           -- 翅膀
    TRAIL = "尾迹",          -- 尾迹
}

-- 物品通知数据结构
---@class ItemAcquiredReward
---@field itemType string 物品类型（使用ITEM_TYPES中的值）
---@field itemName string 物品名称（配置名称）
---@field amount number 物品数量

---@class ItemAcquiredNotifyData
---@field rewards ItemAcquiredReward[] 获得的物品列表
---@field source string 来源描述（如"抽奖获得"、"在线奖励"等）
---@field message string 通知消息（如"恭喜获得以下物品！"）

EventPlayerConfig.PLAYER_ACTION = {
    PLAYER_ANIMATION = "PLAYER_ANIMATION",
}

return EventPlayerConfig