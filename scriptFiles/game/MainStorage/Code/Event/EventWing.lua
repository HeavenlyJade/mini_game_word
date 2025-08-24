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
    },
    RESPONSE = {
        ERROR = "Wing:Error",
        WING_BATCH_UPGRADE = "Wing:BatchUpgradeResponse",
        WING_STATS = "Wing:StatsResponse",
        WING_STAR_UPGRADED = "Wing:StarUpgradedResponse",
    },
    NOTIFY = {
        WING_LIST_UPDATE = "Wing:NotifyListUpdate",
        WING_UPDATE = "Wing:NotifyUpdate",
        WING_OBTAINED = "Wing:NotifyObtained",
        WING_REMOVED = "Wing:NotifyRemoved",
    },
}

return WingEventConfig 