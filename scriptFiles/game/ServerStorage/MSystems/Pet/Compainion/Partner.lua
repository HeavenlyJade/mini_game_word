-- Partner.lua
-- 伙伴管理器（继承BaseCompanion）
-- 负责管理单个玩家的所有伙伴数据和业务逻辑

local game = game
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local BaseCompanion = require(ServerStorage.MSystems.Pet.Compainion.BaseCompanion) ---@type BaseCompanion


---@class Partner:BaseCompanion 伙伴管理器
local Partner = ClassMgr.Class("Partner", BaseCompanion)

function Partner:OnInit(uin, playerPartnerData)
    -- 调用父类初始化
    BaseCompanion.OnInit(self, uin, "伙伴", 30)
    
    -- 从伙伴数据初始化
   
    self:LoadFromPartnerData(playerPartnerData)
    
    
    gg.log("Partner管理器创建", uin, "伙伴数量", self:GetCompanionCount())
end

-- =================================
-- 实现基类的抽象方法
-- =================================

---加载伙伴配置
---@param companionName string 伙伴名称
---@return table|nil 伙伴配置
function Partner:LoadConfigByName(companionName)
    return ConfigLoader.GetPartner(companionName)
end

---创建伙伴数据
---@param companionName string 伙伴名称
---@param companionTypeConfig table 伙伴配置
---@return table 伙伴数据
function Partner:CreateCompanionData(companionName, companionTypeConfig)
    return {
        partnerName = companionName,
        customName = "",
        level = companionTypeConfig.minLevel,
        exp = 0,
        starLevel = 1,
        learnedSkills = {},
        equipments = {},
        isActive = false,
        mood = 100
    }
end

---获取保存数据
---@return PlayerPartnerData 伙伴保存数据
function Partner:GetSaveData()
    local playerPartnerData = {
        activePartnerSlot = self.activeCompanionSlot,
        partnerList = {},
        partnerSlots = self.maxSlots
    }
    
    -- 提取所有伙伴的数据
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        playerPartnerData.partnerList[slotIndex] = companionInstance.companionData
    end
    
    return playerPartnerData
end

-- =================================
-- 伙伴专用方法
-- =================================

---从伙伴数据加载
---@param playerPartnerData PlayerPartnerData 伙伴数据
function Partner:LoadFromPartnerData(playerPartnerData)
    -- 设置激活槽位和最大槽位
    self.activeCompanionSlot = playerPartnerData.activePartnerSlot or 0
    self.maxSlots = playerPartnerData.partnerSlots or 30
    
    -- 创建伙伴实例
    for slotIndex, partnerData in pairs(playerPartnerData.partnerList or {}) do
        local companionInstance = self:CreateCompanionInstance(partnerData, slotIndex)
        if companionInstance then
            self.companionInstances[slotIndex] = companionInstance
        end
    end
    
    gg.log("从伙伴数据加载", self.uin, "激活槽位", self.activeCompanionSlot, "伙伴数", self:GetCompanionCount())
end

---获取伙伴列表信息
---@return table 伙伴列表信息
function Partner:GetPlayerPartnerList()
    local companionList = self:GetCompanionList()
    
    -- 转换为伙伴格式
    return {
        partnerList = companionList.companionList,
        activePartnerId = companionList.activeCompanionId,
        partnerSlots = companionList.companionSlots
    }
end

-- =================================
-- 伙伴操作接口
-- =================================

---获取指定槽位的伙伴实例
---@param slotIndex number 槽位索引
---@return CompanionInstance|nil 伙伴实例
function Partner:GetPartnerBySlot(slotIndex)
    return self:GetCompanionBySlot(slotIndex)
end

---获取激活的伙伴
---@return CompanionInstance|nil 激活的伙伴实例
---@return number|nil 槽位索引
function Partner:GetActivePartner()
    return self:GetActiveCompanion()
end

---添加伙伴
---@param partnerName string 伙伴名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function Partner:AddPartner(partnerName, slotIndex)
    return self:AddCompanion(partnerName, slotIndex)
end

---移除伙伴
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function Partner:RemovePartner(slotIndex)
    return self:RemoveCompanion(slotIndex)
end

---设置激活伙伴
---@param slotIndex number 槽位索引（0表示取消激活）
---@return boolean 是否成功
---@return string|nil 错误信息
function Partner:SetActivePartner(slotIndex)
    return self:SetActiveCompanion(slotIndex)
end

---伙伴升级
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级，nil表示升1级
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否真的升级了
function Partner:LevelUpPartner(slotIndex, targetLevel)
    return self:LevelUpCompanion(slotIndex, targetLevel)
end

---伙伴获得经验
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否升级了
function Partner:AddPartnerExp(slotIndex, expAmount)
    return self:AddCompanionExp(slotIndex, expAmount)
end

---伙伴升星
---@param slotIndex number 要升星的伙伴槽位
---@return boolean 是否成功
---@return string|nil 错误信息
function Partner:UpgradePartnerStar(slotIndex)
    return self:UpgradeCompanionStar(slotIndex)
end

---伙伴学习技能
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function Partner:LearnPartnerSkill(slotIndex, skillId)
    return self:LearnCompanionSkill(slotIndex, skillId)
end

---获取伙伴的最终属性
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function Partner:GetPartnerFinalAttribute(slotIndex, attrName)
    return self:GetCompanionFinalAttribute(slotIndex, attrName)
end

---检查伙伴是否可以升级
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function Partner:CanPartnerLevelUp(slotIndex)
    return self:CanCompanionLevelUp(slotIndex)
end

---检查伙伴是否可以升星
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function Partner:CanPartnerUpgradeStar(slotIndex)
    return self:CanCompanionUpgradeStar(slotIndex)
end

---更新所有伙伴的临时buff
function Partner:UpdateAllPartnerBuffs()
    self:UpdateAllCompanionBuffs()
end

---获取指定类型的伙伴数量
---@param partnerName string 伙伴名称
---@param minStar number|nil 最小星级要求
---@return number 伙伴数量
function Partner:GetPartnerCountByType(partnerName, minStar)
    return self:GetCompanionCountByType(partnerName, minStar)
end

---批量操作：一键升级所有可升级伙伴
---@return number 升级的伙伴数量
function Partner:UpgradeAllPossiblePartners()
    return self:UpgradeAllPossibleCompanions()
end

---消耗指定伙伴
---@param partnerName string 伙伴名称
---@param count number 需要数量
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位（如正在升星的伙伴）
---@return boolean 是否成功消耗
function Partner:ConsumePartners(partnerName, count, requiredStar, excludeSlot)
    return self:ConsumeCompanions(partnerName, count, requiredStar, excludeSlot)
end

---查找符合条件的伙伴
---@param partnerName string 伙伴名称
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位
---@return table<number> 符合条件的槽位列表
function Partner:FindPartnersByCondition(partnerName, requiredStar, excludeSlot)
    return self:FindCompanionsByCondition(partnerName, requiredStar, excludeSlot)
end

---获取伙伴数量
---@return number 伙伴数量
function Partner:GetPartnerCount()
    return self:GetCompanionCount()
end

-- =================================
-- 伙伴专用扩展方法
-- =================================

---获取伙伴实例（通过伙伴名称查找）
---@param partnerName string 伙伴名称
---@return table<number> 匹配的槽位列表
function Partner:FindPartnerSlotsByName(partnerName)
    local slots = {}
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        if companionInstance:GetConfigName() == partnerName then
            table.insert(slots, slotIndex)
        end
    end
    return slots
end

---获取所有不同类型伙伴的统计
---@return table<string, number> 伙伴类型统计 {partnerName = count}
function Partner:GetPartnerTypeStatistics()
    local statistics = {}
    for _, companionInstance in pairs(self.companionInstances) do
        local partnerName = companionInstance:GetConfigName()
        statistics[partnerName] = (statistics[partnerName] or 0) + 1
    end
    return statistics
end

---获取可用于升星的伙伴材料统计
---@param targetPartnerName string 目标伙伴名称
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位
---@return table 材料统计信息
function Partner:GetUpgradeMaterialStats(targetPartnerName, requiredStar, excludeSlot)
    local candidates = self:FindCompanionsByCondition(targetPartnerName, requiredStar, excludeSlot)
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

---伙伴专用：获取战斗力评估
---@return number 总战斗力
function Partner:GetTotalCombatPower()
    local totalPower = 0
    for _, companionInstance in pairs(self.companionInstances) do
        -- 简单的战斗力计算（可根据实际需求调整）
        local level = companionInstance:GetLevel()
        local star = companionInstance:GetStarLevel()
        local attackPower = companionInstance:GetFinalAttribute("攻击") or 0
        local defensePower = companionInstance:GetFinalAttribute("防御") or 0
        
        local companionPower = (attackPower + defensePower) * level * star
        totalPower = totalPower + companionPower
    end
    return totalPower
end

---伙伴专用：获取推荐出战伙伴
---@param maxCount number 最大推荐数量
---@return table<number> 推荐的槽位列表
function Partner:GetRecommendedBattlePartners(maxCount)
    maxCount = maxCount or 3
    
    -- 按战斗力排序
    local partnerPowers = {}
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        local level = companionInstance:GetLevel()
        local star = companionInstance:GetStarLevel()
        local attackPower = companionInstance:GetFinalAttribute("攻击") or 0
        local defensePower = companionInstance:GetFinalAttribute("防御") or 0
        
        local power = (attackPower + defensePower) * level * star
        table.insert(partnerPowers, {slotIndex = slotIndex, power = power})
    end
    
    -- 排序（战斗力从高到低）
    table.sort(partnerPowers, function(a, b) return a.power > b.power end)
    
    -- 取前maxCount个
    local recommended = {}
    for i = 1, math.min(maxCount, #partnerPowers) do
        table.insert(recommended, partnerPowers[i].slotIndex)
    end
    
    return recommended
end

---伙伴专用：批量设置心情值
---@param mood number 心情值 (0-100)
function Partner:SetAllPartnersMood(mood)
    for _, companionInstance in pairs(self.companionInstances) do
        companionInstance:SetMood(mood)
    end
    gg.log("批量设置伙伴心情值", self.uin, "心情", mood, "伙伴数", self:GetPartnerCount())
end

---伙伴专用：获取心情值统计
---@return table 心情值统计信息
function Partner:GetMoodStatistics()
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

return Partner