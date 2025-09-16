--- 宠物事件配置
---@class PetEventConfig
local PetEventConfig = {}

-- 【新】装备系统配置
PetEventConfig.EQUIP_CONFIG = {
    PARTNER_SLOTS = { "Partner1", "Partner2",  },
    PET_SLOTS = { "Pet1", "Pet2", "Pet3", "Pet4", "Pet5", "Pet6", },
    WING_SLOTS = { "Wings1" }
}

-- 客户端请求事件
PetEventConfig.REQUEST = {
    GET_PET_LIST = "GetPetList",               -- 获取宠物列表
    EQUIP_PET = "EquipPet",                    -- 【新增】装备宠物
    UNEQUIP_PET = "UnequipPet",                -- 【新增】卸下宠物
    SET_ACTIVE_PET = "SetActivePet",           -- 设置激活宠物
    LEVEL_UP_PET = "LevelUpPet",               -- 宠物升级
    ADD_PET_EXP = "AddPetExp",                 -- 宠物获得经验
    UPGRADE_PET_STAR = "UpgradePetStar",       -- 宠物升星
    LEARN_PET_SKILL = "LearnPetSkill",         -- 宠物学习技能
    FEED_PET = "FeedPet",                      -- 喂养宠物
    RENAME_PET = "RenamePet",                   -- 重命名宠物
    DELETE_PET = "DeletePet",                  -- 【新增】删除宠物
    TOGGLE_PET_LOCK = "TogglePetLock",          -- 【新增】切换宠物锁定状态
    UPGRADE_ALL_PETS = "UpgradeAllPets",        -- 【新增】一键升星
    AUTO_EQUIP_BEST_PET = "AutoEquipBestPet",           -- 【新增】自动装备最优宠物
    AUTO_EQUIP_ALL_BEST_PETS = "AutoEquipAllBestPets", -- 【新增】自动装备所有最优宠物
    GET_PET_EFFECT_RANKING = "GetPetEffectRanking",     -- 【新增】获取宠物效果排行
    GET_STRONGEST_BONUS_PET_NAME = "GetStrongestBonusPetName" -- 【新增】获取最强加成宠物名称
}

-- 服务器响应事件
PetEventConfig.RESPONSE = {
    SYNC_PET_LIST = "SyncPetList",             -- 同步宠物列表
    PET_ACTIVATED = "PetActivated",            -- 宠物激活结果
    PET_LEVEL_UP = "PetLevelUp",               -- 宠物升级结果
    PET_EXP_ADDED = "PetExpAdded",             -- 宠物经验获得结果
    PET_STAR_UPGRADED = "PetStarUpgraded",     -- 宠物升星结果
    PET_SKILL_LEARNED = "PetSkillLearned",     -- 宠物学习技能结果
    PET_FED = "PetFed",                        -- 宠物喂养结果
    PET_RENAMED = "PetRenamed",                -- 宠物重命名结果
    PET_STATS = "PetStats",                    -- 宠物统计结果
    PET_BATCH_UPGRADE = "PetBatchUpgrade",     -- 批量升级结果
    PET_EFFECT_RANKING = "PetEffectRanking",   -- 【新增】宠物效果排行响应
    STRONGEST_BONUS_PET_NAME = "StrongestBonusPetName", -- 【新增】最强加成宠物名称响应
    ERROR = "PetError"                         -- 错误响应
}

-- 服务器通知事件
PetEventConfig.NOTIFY = {
    PET_LIST_UPDATE = "PetListUpdate",         -- 宠物列表更新通知
    PET_UPDATE = "PetUpdate",                  -- 单个宠物更新通知
    PET_OBTAINED = "PetObtained",              -- 获得宠物通知
    PET_REMOVED = "PetRemoved"                 -- 宠物移除通知
}

return PetEventConfig
