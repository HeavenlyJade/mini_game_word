-- EventAchievement.lua
-- 成就事件配置文件
-- 包含成就系统相关的事件名称和业务枚举定义

---@class AchievementEventConfig
local AchievementEventConfig = {}

--[[
===================================
网络事件定义
===================================
]]

-- 客户端请求事件
AchievementEventConfig.REQUEST = {
    GET_LIST = "AchievementRequest_GetList",                    -- 获取成就列表
    GET_DETAIL = "AchievementRequest_GetDetail",                -- 获取成就详情
    UPGRADE_TALENT = "AchievementRequest_UpgradeTalent",        -- 升级天赋成就
    GET_UPGRADE_PREVIEW = "AchievementRequest_GetUpgradePreview", -- 获取升级预览
    SYNC_DATA = "AchievementRequest_SyncData",                  -- 请求同步数据
    GET_TALENT_LEVEL = "AchievementRequest_GetTalentLevel",       -- 获取天赋等级
    PERFORM_TALENT_ACTION = "AchievementRequest_PerformTalentAction", -- 执行天赋动作
    PERFORM_MAX_TALENT_ACTION = "AchievementRequest_PerformMaxTalentAction", -- 执行最大化天赋动作
    -- 新增：重生专用事件
    PERFORM_REBIRTH = "AchievementRequest_PerformRebirth",      -- 执行单次重生
    PERFORM_MAX_REBIRTH = "AchievementRequest_PerformMaxRebirth", -- 执行最大重生
}

-- 服务器响应事件
AchievementEventConfig.RESPONSE = {
    LIST_RESPONSE = "AchievementResponse_List",                 -- 成就列表响应
    DETAIL_RESPONSE = "AchievementResponse_Detail",             -- 成就详情响应
    UPGRADE_RESPONSE = "AchievementResponse_Upgrade",           -- 升级响应
    PREVIEW_RESPONSE = "AchievementResponse_Preview",           -- 升级预览响应
    SYNC_RESPONSE = "AchievementResponse_Sync",                 -- 同步响应
    GET_TALENT_LEVEL_RESPONSE = "AchievementResponse_GetTalentLevel", -- 获取天赋等级响应
    GET_REBIRTH_LEVEL_RESPONSE = "AchievementResponse_GetRebirthLevel", -- 获取重生等级响应
    PERFORM_TALENT_ACTION_RESPONSE = "AchievementResponse_PerformTalentAction", -- 执行天赋动作响应
    ERROR = "AchievementResponse_Error",                        -- 错误响应
}

-- 服务器通知事件
AchievementEventConfig.NOTIFY = {
    ACHIEVEMENT_UNLOCKED = "AchievementNotify_Unlocked",        -- 成就解锁通知
    TALENT_UPGRADED = "AchievementNotify_TalentUpgraded",       -- 天赋升级通知
    EFFECTS_APPLIED = "AchievementNotify_EffectsApplied",       -- 效果应用通知
    DATA_SYNC = "AchievementNotify_DataSync",                   -- 数据同步通知
}

--[[
===================================
业务枚举定义
===================================
]]

-- 成就类型枚举
AchievementEventConfig.ACHIEVEMENT_TYPE = {
    NORMAL = "普通成就",            -- 普通成就
    TALENT = "天赋成就",            -- 天赋成就
}

-- 效果类型枚举
AchievementEventConfig.EFFECT_TYPE = {
    PLAYER_VARIABLE = "玩家变量",   -- 作用于VariableSystem
    PLAYER_ATTRIBUTE = "玩家属性",  -- 作用于StatSystem
}

-- 变量前缀类型
AchievementEventConfig.VARIABLE_PREFIX = {
    BOOST = "加成_",               -- 加成类变量
    UNLOCK = "解锁_",              -- 解锁类变量
    CONFIG = "配置_",              -- 配置类变量
    COUNT = "计数_",               -- 计数类变量
    STATUS = "状态_",              -- 状态类变量
}

-- 操作类型定义
AchievementEventConfig.OPERATION_TYPE = {
    UNLOCK = "unlock",              -- 解锁成就
    UPGRADE = "upgrade",            -- 升级天赋
    APPLY_EFFECTS = "apply_effects", -- 应用效果
    PREVIEW = "preview",            -- 预览效果
}

--[[
===================================
错误码定义
===================================
]]

-- 错误码定义
AchievementEventConfig.ERROR_CODES = {
    SUCCESS = 0,                        -- 操作成功
    PLAYER_NOT_FOUND = 1001,            -- 玩家不存在
    ACHIEVEMENT_NOT_FOUND = 1002,       -- 成就不存在
    ACHIEVEMENT_ALREADY_UNLOCKED = 1003, -- 成就已解锁
    TALENT_ALREADY_MAX_LEVEL = 1005,    -- 天赋已达最大等级
    TALENT_CANNOT_UPGRADE = 1006,       -- 天赋无法升级
    INSUFFICIENT_MATERIALS = 1007,       -- 材料不足
    NORMAL_ACHIEVEMENT_CANNOT_UPGRADE = 1008, -- 普通成就无法升级
    INVALID_PARAMETERS = 1011,          -- 参数无效
    SYSTEM_ERROR = 1999,                -- 系统错误
}

-- 错误消息映射
AchievementEventConfig.ERROR_MESSAGES = {
    [AchievementEventConfig.ERROR_CODES.SUCCESS] = "操作成功",
    [AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND] = "玩家不存在",
    [AchievementEventConfig.ERROR_CODES.ACHIEVEMENT_NOT_FOUND] = "成就不存在",
    [AchievementEventConfig.ERROR_CODES.ACHIEVEMENT_ALREADY_UNLOCKED] = "成就已解锁",
    [AchievementEventConfig.ERROR_CODES.TALENT_ALREADY_MAX_LEVEL] = "天赋已达最大等级",
    [AchievementEventConfig.ERROR_CODES.TALENT_CANNOT_UPGRADE] = "天赋无法升级",
    [AchievementEventConfig.ERROR_CODES.INSUFFICIENT_MATERIALS] = "材料不足",
    [AchievementEventConfig.ERROR_CODES.NORMAL_ACHIEVEMENT_CANNOT_UPGRADE] = "普通成就无法升级",
    [AchievementEventConfig.ERROR_CODES.INVALID_PARAMETERS] = "参数无效",
    [AchievementEventConfig.ERROR_CODES.SYSTEM_ERROR] = "系统错误",
}

--[[
===================================
辅助函数
===================================
]]

--- 获取错误消息
---@param errorCode number 错误码
---@return string 错误消息
function AchievementEventConfig.GetErrorMessage(errorCode)
    return AchievementEventConfig.ERROR_MESSAGES[errorCode] or "未知错误"
end

return AchievementEventConfig