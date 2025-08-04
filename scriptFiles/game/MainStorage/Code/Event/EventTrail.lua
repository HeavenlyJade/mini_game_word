-- EventTrail.lua
-- 尾迹系统事件配置
-- 定义所有尾迹相关的客户端-服务器事件名称

---@class TrailEventConfig
local TrailEventConfig = {
    -- 客户端请求事件（客户端 -> 服务器）
    REQUEST = {
        GET_TRAIL_LIST = "Trail:GetTrailList",           -- 获取尾迹列表
        EQUIP_TRAIL = "Trail:EquipTrail",                -- 装备尾迹
        UNEQUIP_TRAIL = "Trail:UnequipTrail",            -- 卸下尾迹
        DELETE_TRAIL = "Trail:DeleteTrail",              -- 删除尾迹
        TOGGLE_TRAIL_LOCK = "Trail:ToggleTrailLock",     -- 切换尾迹锁定状态
        RENAME_TRAIL = "Trail:RenameTrail",              -- 重命名尾迹
    },

    -- 服务器响应事件（服务器 -> 客户端）
    RESPONSE = {
        TRAIL_LIST_RESPONSE = "Trail:TrailListResponse",  -- 尾迹列表响应
        EQUIP_TRAIL_RESPONSE = "Trail:EquipTrailResponse", -- 装备尾迹响应
        UNEQUIP_TRAIL_RESPONSE = "Trail:UnequipTrailResponse", -- 卸下尾迹响应
        DELETE_TRAIL_RESPONSE = "Trail:DeleteTrailResponse", -- 删除尾迹响应
        TOGGLE_LOCK_RESPONSE = "Trail:ToggleLockResponse", -- 切换锁定响应
        RENAME_TRAIL_RESPONSE = "Trail:RenameTrailResponse", -- 重命名响应
        ERROR_RESPONSE = "Trail:ErrorResponse",           -- 错误响应
    },

    -- 服务器通知事件（服务器 -> 客户端）
    NOTIFY = {
        TRAIL_LIST_UPDATE = "Trail:NotifyListUpdate",     -- 尾迹列表更新通知
        TRAIL_UPDATE = "Trail:NotifyUpdate",              -- 单个尾迹更新通知
        TRAIL_OBTAINED = "Trail:NotifyObtained",          -- 获得尾迹通知
        TRAIL_REMOVED = "Trail:NotifyRemoved",            -- 移除尾迹通知
        TRAIL_EQUIPPED = "Trail:NotifyEquipped",          -- 装备尾迹通知
        TRAIL_UNEQUIPPED = "Trail:NotifyUnequipped",      -- 卸下尾迹通知
        ERROR_NOTIFY = "Trail:NotifyError",               -- 错误通知
    },

    -- 装备槽配置
    EQUIP_CONFIG = {
        TRAIL_SLOTS = { "尾迹" }  -- 尾迹装备槽，只有一个槽位
    }
}

return TrailEventConfig 