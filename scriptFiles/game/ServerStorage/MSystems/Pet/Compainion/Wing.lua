-- Wing.lua
-- 翅膀管理器（继承BaseCompanion）
-- 负责管理单个玩家的所有翅膀数据和业务逻辑

local game = game
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local BaseCompanion = require(ServerStorage.MSystems.Pet.Compainion.BaseCompanion) ---@type BaseCompanion
local PetEventConfig = require(MainStorage.Code.Event.EventPet) ---@type PetEventConfig

---@class Wing:BaseCompanion 翅膀管理器
local Wing = ClassMgr.Class("Wing", BaseCompanion)

function Wing:OnInit(uin, playerWingData)
    -- 【重构】从配置加载装备栏，并调用父类初始化
    local equipSlotIds = PetEventConfig.EQUIP_CONFIG.WING_SLOTS
    BaseCompanion.OnInit(self, uin, "翅膀", equipSlotIds)

    -- 从翅膀数据初始化
    self:LoadFromWingData(playerWingData)

    --gg.log("Wing管理器创建", uin, "翅膀数量", self:GetCompanionCount())
end

-- =================================
-- 实现基类的抽象方法
-- =================================

---加载翅膀配置
---@param companionName string 翅膀名称
---@return table|nil 翅膀配置
function Wing:LoadConfigByName(companionName)
    return ConfigLoader.GetWing(companionName)
end

---创建翅膀数据
---@param companionName string 翅膀名称
---@param companionTypeConfig table 翅膀配置
---@return table 翅膀数据
function Wing:CreateCompanionData(companionName, companionTypeConfig)
    return {
        wingName = companionName,
        customName = "",
        level = companionTypeConfig.minLevel,
        exp = 0,
        starLevel = 1,
        learnedSkills = {},
        equipments = {},
        isActive = false,
        mood = 100,
        isLocked = false -- 【新增】
    }
end

---获取保存数据
---@return PlayerWingData 翅膀保存数据
function Wing:GetSaveData()
    local playerWingData = {
        activeSlots = self.activeCompanionSlots, -- 【修改】保存新的激活数据结构
        wingList = {},
        wingSlots = self.maxSlots, -- 保留背包容量字段
        unlockedEquipSlots = self.unlockedEquipSlots -- 【新增】保存已解锁栏位数
    }

    -- 提取所有翅膀的数据
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        playerWingData.wingList[slotIndex] = companionInstance.companionData
    end

    return playerWingData
end

-- =================================
-- 翅膀专用方法
-- =================================

---从翅膀数据加载
---@param playerWingData PlayerWingData 翅膀数据
function Wing:LoadFromWingData(playerWingData)
    if not playerWingData then return end

    -- 【重构】加载新的激活数据结构
    self.activeCompanionSlots = playerWingData.activeSlots or {}
    self.maxSlots = playerWingData.wingSlots or 1-- 兼容旧数据

    -- 【新增】加载已解锁的装备栏数量，确保不超过系统配置的最大值
    local maxEquipped = #self.equipSlotIds
    self.unlockedEquipSlots = math.min(playerWingData.unlockedEquipSlots or 1, maxEquipped)

    -- 创建翅膀实例
    for slotIndex, wingData in pairs(playerWingData.wingList or {}) do
        local companionInstance = self:CreateCompanionInstance(wingData, slotIndex)
        if companionInstance then
            self.companionInstances[slotIndex] = companionInstance
        end
    end

    --gg.log("从翅膀数据加载", self.uin, "激活槽位数量", #(self.activeCompanionSlots or {}), "翅膀数", self:GetCompanionCount())
end

---获取翅膀列表信息
---@return table 翅膀列表信息
function Wing:GetPlayerWingList()
    return self:GetCompanionList()
end

-- =================================
-- 翅膀操作接口
-- =================================

---获取指定槽位的翅膀实例
---@param slotIndex number 槽位索引
---@return CompanionInstance|nil 翅膀实例
function Wing:GetWingBySlot(slotIndex)
    return self:GetCompanionBySlot(slotIndex)
end

---添加翅膀
---@param wingName string 翅膀名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function Wing:AddWing(wingName, slotIndex)
    return self:AddCompanion(wingName, slotIndex)
end

---移除翅膀
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function Wing:RemoveWing(slotIndex)
    return self:RemoveCompanion(slotIndex)
end

---【新增】删除翅膀（兼容接口）
---@param slotIndex number
---@return boolean, string|nil
function Wing:DeleteWing(slotIndex)
    return self:DeleteCompanion(slotIndex)
end

---【新增】切换翅膀锁定状态（兼容接口）
---@param slotIndex number
---@return boolean, string|nil, boolean|nil
function Wing:ToggleWingLock(slotIndex)
    return self:ToggleCompanionLock(slotIndex)
end

---【重构】设置激活翅膀接口 -> 装备/卸下
---@param companionSlotId number 翅膀背包槽位
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function Wing:EquipWing(companionSlotId, equipSlotId)
    return self:EquipCompanion(companionSlotId, equipSlotId)
end

---@param equipSlotId string 目标装备栏ID
---@return boolean
function Wing:UnequipWing(equipSlotId)
    return self:UnequipCompanion(equipSlotId)
end

---【废弃】旧的单一激活接口
function Wing:SetActiveWing(slotIndex)
    --gg.log("警告: SetActiveWing 是一个废弃的接口，请使用 EquipWing 或 UnequipWing。")
    return false, "接口已废弃"
end

---翅膀升级
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级，nil表示升1级
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否真的升级了
function Wing:LevelUpWing(slotIndex, targetLevel)
    return self:LevelUpCompanion(slotIndex, targetLevel)
end

---翅膀获得经验
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否升级了
function Wing:AddWingExp(slotIndex, expAmount)
    return self:AddCompanionExp(slotIndex, expAmount)
end

---翅膀升星
---@param slotIndex number 要升星的翅膀槽位
---@return boolean 是否成功
---@return string|nil 错误信息
function Wing:UpgradeWingStar(slotIndex)
    return self:UpgradeCompanionStar(slotIndex)
end

---翅膀学习技能
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function Wing:LearnWingSkill(slotIndex, skillId)
    return self:LearnCompanionSkill(slotIndex, skillId)
end

---获取翅膀的最终属性
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function Wing:GetWingFinalAttribute(slotIndex, attrName)
    return self:GetCompanionFinalAttribute(slotIndex, attrName)
end

---检查翅膀是否可以升级
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function Wing:CanWingLevelUp(slotIndex)
    return self:CanCompanionLevelUp(slotIndex)
end

---检查翅膀是否可以升星
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function Wing:CanWingUpgradeStar(slotIndex)
    return self:CanCompanionUpgradeStar(slotIndex)
end

---更新所有翅膀的临时buff
function Wing:UpdateAllWingBuffs()
    self:UpdateAllCompanionBuffs()
end

---获取指定类型的翅膀数量
---@param wingName string 翅膀名称
---@param minStar number|nil 最小星级要求
---@return number 翅膀数量
function Wing:GetWingCountByType(wingName, minStar)
    return self:GetCompanionCountByType(wingName, minStar)
end

---批量操作：一键升级所有可升级翅膀
---@return number 升级的翅膀数量
function Wing:UpgradeAllPossibleWings()
    return self:UpgradeAllPossibleCompanions()
end

---消耗指定翅膀
---@param wingName string 翅膀名称
---@param count number 需要数量
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位（如正在升星的翅膀）
---@return boolean 是否成功消耗
function Wing:ConsumeWings(wingName, count, requiredStar, excludeSlot)
    return self:ConsumeCompanions(wingName, count, requiredStar, excludeSlot)
end

---查找符合条件的翅膀
---@param wingName string 翅膀名称
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位
---@return table<number> 符合条件的槽位列表
function Wing:FindWingsByCondition(wingName, requiredStar, excludeSlot)
    return self:FindCompanionsByCondition(wingName, requiredStar, excludeSlot)
end

---获取翅膀数量
---@return number 翅膀数量
function Wing:GetWingCount()
    return self:GetCompanionCount()
end

-- =================================
-- 翅膀专用扩展方法
-- =================================

---获取翅膀实例（通过翅膀名称查找）
---@param wingName string 翅膀名称
---@return table<number> 匹配的槽位列表
function Wing:FindWingSlotsByName(wingName)
    local slots = {}
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        if companionInstance:GetConfigName() == wingName then
            table.insert(slots, slotIndex)
        end
    end
    return slots
end

---获取所有不同类型翅膀的统计
---@return table<string, number> 翅膀类型统计 {wingName = count}
function Wing:GetWingTypeStatistics()
    local statistics = {}
    for _, companionInstance in pairs(self.companionInstances) do
        local wingName = companionInstance:GetConfigName()
        statistics[wingName] = (statistics[wingName] or 0) + 1
    end
    return statistics
end

---获取可用于升星的翅膀材料统计
---@param targetWingName string 目标翅膀名称
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位
---@return table 材料统计信息
function Wing:GetUpgradeMaterialStats(targetWingName, requiredStar, excludeSlot)
    local candidates = self:FindCompanionsByCondition(targetWingName, requiredStar, excludeSlot)
    local starStats = {}

    for _, slotIndex in ipairs(candidates) do
        local companionInstance = self.companionInstances[slotIndex]
        local starLevel = companionInstance:GetStarLevel()
        starStats[starLevel] = (starStats[starLevel] or 0) + 1
    end

    return {
        totalCount = #candidates,
        starDistribution = starStats,
        availableSlots = candidates
    }
end

---翅膀专用：获取战斗力评估
---@return number 总战斗力
function Wing:GetTotalCombatPower()
    local totalPower = 0
    for _, companionInstance in pairs(self.companionInstances) do
        -- 简单的战斗力计算（可根据实际需求调整）
        local level = companionInstance:GetLevel()
        local star = companionInstance:GetStarLevel()
        local attackPower = companionInstance:GetFinalAttribute("攻击") or 0
        local defensePower = companionInstance:GetFinalAttribute("防御") or 0

        local wingPower = (attackPower + defensePower) * level * star
        totalPower = totalPower + wingPower
    end
    return totalPower
end

---翅膀专用：获取推荐出战翅膀
---@param maxCount number 最大推荐数量
---@return table<number> 推荐的槽位列表
function Wing:GetRecommendedBattleWings(maxCount)
    maxCount = maxCount or 3

    -- 按战斗力排序
    local wingPowers = {}
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        local level = companionInstance:GetLevel()
        local star = companionInstance:GetStarLevel()
        local attackPower = companionInstance:GetFinalAttribute("攻击") or 0
        local defensePower = companionInstance:GetFinalAttribute("防御") or 0

        local power = (attackPower + defensePower) * level * star
        table.insert(wingPowers, {slotIndex = slotIndex, power = power})
    end

    -- 排序（战斗力从高到低）
    table.sort(wingPowers, function(a, b) return a.power > b.power end)

    -- 取前maxCount个
    local recommended = {}
    for i = 1, math.min(maxCount, #wingPowers) do
        table.insert(recommended, wingPowers[i].slotIndex)
    end

    return recommended
end

---翅膀专用：批量设置心情值
---@param mood number 心情值 (0-100)
function Wing:SetAllWingsMood(mood)
    for _, companionInstance in pairs(self.companionInstances) do
        companionInstance:SetMood(mood)
    end
    --gg.log("批量设置翅膀心情值", self.uin, "心情", mood, "翅膀数", self:GetWingCount())
end

---翅膀专用：获取心情值统计
---@return table 心情值统计信息
function Wing:GetMoodStatistics()
    local moodStats = {
        totalCount = 0,
        averageMood = 0,
        lowMoodCount = 0,  -- 心情低于50的数量
        highMoodCount = 0  -- 心情高于80的数量
    }

    local totalMood = 0
    for _, companionInstance in pairs(self.companionInstances) do
        local mood = companionInstance:GetMood()
        totalMood = totalMood + mood
        moodStats.totalCount = moodStats.totalCount + 1

        if mood < 50 then
            moodStats.lowMoodCount = moodStats.lowMoodCount + 1
        elseif mood > 80 then
            moodStats.highMoodCount = moodStats.highMoodCount + 1
        end
    end

    if moodStats.totalCount > 0 then
        moodStats.averageMood = totalMood / moodStats.totalCount
    end

    return moodStats
end

--- 设置可携带栏位数量
---@param count number
function Wing:SetUnlockedEquipSlots(count)
    if count and count > 0 then
        local maxEquipped = #self.equipSlotIds
        self.unlockedEquipSlots = math.min(count, maxEquipped)
        --gg.log("玩家", self.uin, "可携带翅膀栏位数量已设置为", self.unlockedEquipSlots)
    end
end

--- 设置翅膀背包容量
---@param capacity number
function Wing:SetWingBagCapacity(capacity)
    if capacity and capacity > 0 then
        self.maxSlots = capacity
        --gg.log("玩家", self.uin, "翅膀背包容量已设置为", self.maxSlots)
    end
end

-- =================================
-- 自动装备最优翅膀便捷方法
-- =================================

---自动装备效果数值最高的翅膀（翅膀专用接口）
---@param equipSlotId string 装备栏ID
---@param excludeEquipped boolean|nil 是否排除已装备的翅膀
---@return boolean, string|nil, number|nil
function Wing:AutoEquipBestWing(equipSlotId, excludeEquipped)
    return self:AutoEquipBestEffectCompanion(equipSlotId, excludeEquipped)
end

---自动装备所有装备栏的最优翅膀（翅膀专用接口）
---@param excludeEquipped boolean|nil 是否排除已装备的翅膀
---@return table
function Wing:AutoEquipAllBestWings(excludeEquipped)
    return self:AutoEquipAllBestEffectCompanions(excludeEquipped)
end

---获取翅膀效果数值排行（翅膀专用接口）
---@param limit number|nil 返回数量限制
---@return table
function Wing:GetWingEffectRanking(limit)
    return self:GetEffectValueRanking(limit)
end

return Wing 