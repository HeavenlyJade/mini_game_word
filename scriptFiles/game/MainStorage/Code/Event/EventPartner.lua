-- EventPartner.lua
-- 定义伙伴系统相关的客户端-服务器事件名称

---@class PartnerEventConfig
local PartnerEventConfig = {
    REQUEST = {
        GET_PARTNER_LIST = "Partner:GetList",
        SET_ACTIVE_PARTNER = "Partner:SetActive",
        LEVEL_UP_PARTNER = "Partner:LevelUp",
        ADD_PARTNER_EXP = "Partner:AddExp",
        UPGRADE_PARTNER_STAR = "Partner:UpgradeStar",
        LEARN_PARTNER_SKILL = "Partner:LearnSkill",
        RENAME_PARTNER = "Partner:Rename",
        UPGRADE_ALL_PARTNERS = "Partner:UpgradeAll",
    },
    RESPONSE = {
        ERROR = "Partner:Error",
        PARTNER_BATCH_UPGRADE = "Partner:BatchUpgradeResponse",
        PARTNER_STATS = "Partner:StatsResponse",
        PARTNER_STAR_UPGRADED = "Partner:StarUpgradedResponse",
    },
    NOTIFY = {
        PARTNER_LIST_UPDATE = "Partner:NotifyListUpdate",
        PARTNER_UPDATE = "Partner:NotifyUpdate",
        PARTNER_OBTAINED = "Partner:NotifyObtained",
        PARTNER_REMOVED = "Partner:NotifyRemoved",
    },
}

return PartnerEventConfig 