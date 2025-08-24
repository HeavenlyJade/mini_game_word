-- EventPartner.lua
-- 定义伙伴系统相关的客户端-服务器事件名称

---@class PartnerEventConfig
local PartnerEventConfig = {
    REQUEST = {
        GET_PARTNER_LIST = "Partner:GetList",
        EQUIP_PARTNER = "Partner:Equip", -- 【新增】装备伙伴
        UNEQUIP_PARTNER = "Partner:Unequip", -- 【新增】卸下伙伴
        LEVEL_UP_PARTNER = "Partner:LevelUp",
        ADD_PARTNER_EXP = "Partner:AddExp",
        UPGRADE_PARTNER_STAR = "Partner:UpgradeStar",
        LEARN_PARTNER_SKILL = "Partner:LearnSkill",
        RENAME_PARTNER = "Partner:Rename",
        UPGRADE_ALL_PARTNERS = "Partner:UpgradeAll",
        DELETE_PARTNER = "Partner:Delete", -- 【新增】删除伙伴
        TOGGLE_PARTNER_LOCK = "Partner:ToggleLock", -- 【新增】切换锁定状态
        AUTO_EQUIP_BEST_PARTNER = "Partner:AutoEquipBest", -- 【新增】自动装备最佳伙伴
        AUTO_EQUIP_ALL_BEST_PARTNERS = "Partner:AutoEquipAllBest", -- 【新增】自动装备所有最佳伙伴
        GET_PARTNER_EFFECT_RANKING = "Partner:GetEffectRanking", -- 【新增】获取伙伴效果排行
    },
    RESPONSE = {
        ERROR = "Partner:Error",
        PARTNER_BATCH_UPGRADE = "Partner:BatchUpgradeResponse",
        PARTNER_STATS = "Partner:StatsResponse",
        PARTNER_STAR_UPGRADED = "Partner:StarUpgradedResponse",
        PARTNER_EFFECT_RANKING = "Partner:EffectRanking", -- 【新增】伙伴效果排行响应
    },
    NOTIFY = {
        PARTNER_LIST_UPDATE = "Partner:NotifyListUpdate",
        PARTNER_UPDATE = "Partner:NotifyUpdate",
        PARTNER_OBTAINED = "Partner:NotifyObtained",
        PARTNER_REMOVED = "Partner:NotifyRemoved",
    },
}

return PartnerEventConfig 