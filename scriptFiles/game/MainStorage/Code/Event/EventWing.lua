-- EventWing.lua
-- 定义翅膀系统相关的客户端-服务器事件名称

---@class WingEventConfig
local WingEventConfig = {
    REQUEST = {
        GET_WING_LIST = "Wing:GetList",
        EQUIP_WING = "Wing:Equip", -- 装备翅膀
        UNEQUIP_WING = "Wing:Unequip", -- 卸下翅膀
        LEVEL_UP_WING = "Wing:LevelUp",
        ADD_WING_EXP = "Wing:AddExp",
        UPGRADE_WING_STAR = "Wing:UpgradeStar",
        LEARN_WING_SKILL = "Wing:LearnSkill",
        RENAME_WING = "Wing:Rename",
        UPGRADE_ALL_WINGS = "Wing:UpgradeAll",
        DELETE_WING = "Wing:Delete", -- 【新增】删除翅膀
        TOGGLE_WING_LOCK = "Wing:ToggleLock", -- 【新增】切换锁定状态
        AUTO_EQUIP_BEST_WING = "Wing:AutoEquipBest", -- 【新增】自动装备最佳翅膀
        AUTO_EQUIP_ALL_BEST_WINGS = "Wing:AutoEquipAllBest", -- 【新增】自动装备所有最佳翅膀
        GET_WING_EFFECT_RANKING = "Wing:GetEffectRanking", -- 【新增】获取翅膀效果排行
    },
    RESPONSE = {
        ERROR = "Wing:Error",
        WING_BATCH_UPGRADE = "Wing:BatchUpgradeResponse",
        WING_STATS = "Wing:StatsResponse",
        WING_STAR_UPGRADED = "Wing:StarUpgradedResponse",
        WING_EFFECT_RANKING = "Wing:EffectRanking", -- 【新增】翅膀效果排行响应
    },
    NOTIFY = {
        WING_LIST_UPDATE = "Wing:NotifyListUpdate",
        WING_UPDATE = "Wing:NotifyUpdate",
        WING_OBTAINED = "Wing:NotifyObtained",
        WING_REMOVED = "Wing:NotifyRemoved",
    },
}

return WingEventConfig 