--- 宠物事件配置
---@class PetEventConfig
local PetEventConfig = {}

-- 客户端请求事件
PetEventConfig.REQUEST = {
    GET_PET_LIST = "GetPetList",               -- 获取宠物列表
    SET_ACTIVE_PET = "SetActivePet",           -- 设置激活宠物
    LEVEL_UP_PET = "LevelUpPet",               -- 宠物升级
    ADD_PET_EXP = "AddPetExp",                 -- 宠物获得经验
    UPGRADE_PET_STAR = "UpgradePetStar",       -- 宠物升星
    LEARN_PET_SKILL = "LearnPetSkill",         -- 宠物学习技能
    FEED_PET = "FeedPet",                      -- 喂养宠物
    RENAME_PET = "RenamePet"                   -- 重命名宠物
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