-- Pet.lua
-- 宠物管理器（继承BaseCompanion）
-- 负责管理单个玩家的所有宠物数据和业务逻辑

local game = game
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local BaseCompanion = require(ServerStorage.MSystems.Pet.Compainion.BaseCompanion) ---@type BaseCompanion


---@class Pet:BaseCompanion 宠物管理器
local Pet = ClassMgr.Class("Pet", BaseCompanion)

function Pet:OnInit(uin, playerPetData)
    -- 调用父类初始化
    BaseCompanion.OnInit(self, uin, "宠物", 50)
    self:LoadFromPetData(playerPetData)
    gg.log("Pet管理器创建", uin, "宠物数量", self:GetCompanionCount())
end

-- =================================
-- 实现基类的抽象方法
-- =================================

---加载宠物配置
---@param companionName string 宠物名称
---@return table|nil 宠物配置
function Pet:LoadConfigByName(companionName)
    return ConfigLoader.GetPet(companionName)
end

---创建宠物数据
---@param companionName string 宠物名称
---@param companionTypeConfig table 宠物配置
---@return table 宠物数据
function Pet:CreateCompanionData(companionName, companionTypeConfig)
    return {
        petName = companionName,
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
---@return PlayerPetData 宠物保存数据
function Pet:GetSaveData()
    local playerPetData = {
        activePetSlot = self.activeCompanionSlot,
        petList = {},
        petSlots = self.maxSlots
    }
    
    -- 提取所有宠物的数据
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        playerPetData.petList[slotIndex] = companionInstance.companionData
    end
    
    return playerPetData
end

-- =================================
-- 宠物专用方法
-- =================================

---从宠物数据加载
---@param playerPetData PlayerPetData 宠物数据
function Pet:LoadFromPetData(playerPetData)
    -- 设置激活槽位和最大槽位
    self.activeCompanionSlot = playerPetData.activePetSlot or 0
    self.maxSlots = playerPetData.petSlots or 50
    
    -- 创建宠物实例
    for slotIndex, petData in pairs(playerPetData.petList or {}) do
        local companionInstance = self:CreateCompanionInstance(petData, slotIndex)
        if companionInstance then
            self.companionInstances[slotIndex] = companionInstance
        end
    end
    
    gg.log("从宠物数据加载", self.uin, "激活槽位", self.activeCompanionSlot, "宠物数", self:GetCompanionCount())
end

---获取宠物列表信息（兼容原接口）
---@return table 宠物列表信息
function Pet:GetPlayerPetList()
    local companionList = self:GetCompanionList()
    
    -- 转换为原有的宠物格式
    return {
        petList = companionList.companionList,
        activePetId = companionList.activeCompanionId,
        petSlots = companionList.companionSlots
    }
end

-- =================================
-- 兼容性接口（保持原有方法名）
-- =================================

---获取指定槽位的宠物实例（兼容接口）
---@param slotIndex number 槽位索引
---@return CompanionInstance|nil 宠物实例
function Pet:GetPetBySlot(slotIndex)
    return self:GetCompanionBySlot(slotIndex)
end

---获取激活的宠物（兼容接口）
---@return CompanionInstance|nil 激活的宠物实例
---@return number|nil 槽位索引
function Pet:GetActivePet()
    return self:GetActiveCompanion()
end

---添加宠物（兼容接口）
---@param petName string 宠物名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function Pet:AddPet(petName, slotIndex)
    return self:AddCompanion(petName, slotIndex)
end

---移除宠物（兼容接口）
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:RemovePet(slotIndex)
    return self:RemoveCompanion(slotIndex)
end

---设置激活宠物（兼容接口）
---@param slotIndex number 槽位索引（0表示取消激活）
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:SetActivePet(slotIndex)
    return self:SetActiveCompanion(slotIndex)
end

---宠物升级（兼容接口）
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级，nil表示升1级
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否真的升级了
function Pet:LevelUpPet(slotIndex, targetLevel)
    return self:LevelUpCompanion(slotIndex, targetLevel)
end

---宠物获得经验（兼容接口）
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否升级了
function Pet:AddPetExp(slotIndex, expAmount)
    return self:AddCompanionExp(slotIndex, expAmount)
end

---宠物升星（兼容接口）
---@param slotIndex number 要升星的宠物槽位
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:UpgradePetStar(slotIndex)
    return self:UpgradeCompanionStar(slotIndex)
end

---宠物学习技能（兼容接口）
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:LearnPetSkill(slotIndex, skillId)
    return self:LearnCompanionSkill(slotIndex, skillId)
end

---获取宠物的最终属性（兼容接口）
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function Pet:GetPetFinalAttribute(slotIndex, attrName)
    return self:GetCompanionFinalAttribute(slotIndex, attrName)
end

---检查宠物是否可以升级（兼容接口）
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function Pet:CanPetLevelUp(slotIndex)
    return self:CanCompanionLevelUp(slotIndex)
end

---检查宠物是否可以升星（兼容接口）
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function Pet:CanPetUpgradeStar(slotIndex)
    return self:CanCompanionUpgradeStar(slotIndex)
end

---更新所有宠物的临时buff（兼容接口）
function Pet:UpdateAllPetBuffs()
    self:UpdateAllCompanionBuffs()
end

---获取指定类型的宠物数量（兼容接口）
---@param petName string 宠物名称
---@param minStar number|nil 最小星级要求
---@return number 宠物数量
function Pet:GetPetCountByType(petName, minStar)
    return self:GetCompanionCountByType(petName, minStar)
end

---批量操作：一键升级所有可升级宠物（兼容接口）
---@return number 升级的宠物数量
function Pet:UpgradeAllPossiblePets()
    return self:UpgradeAllPossibleCompanions()
end

---消耗指定宠物（兼容接口）
---@param petName string 宠物名称
---@param count number 需要数量
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位（如正在升星的宠物）
---@return boolean 是否成功消耗
function Pet:ConsumePets(petName, count, requiredStar, excludeSlot)
    return self:ConsumeCompanions(petName, count, requiredStar, excludeSlot)
end

---查找符合条件的宠物（兼容接口）
---@param petName string 宠物名称
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位
---@return table<number> 符合条件的槽位列表
function Pet:FindPetsByCondition(petName, requiredStar, excludeSlot)
    return self:FindCompanionsByCondition(petName, requiredStar, excludeSlot)
end

---获取宠物数量（兼容接口）
---@return number 宠物数量
function Pet:GetPetCount()
    return self:GetCompanionCount()
end

-- =================================
-- 宠物专用扩展方法
-- =================================

---获取宠物实例（通过宠物名称查找）
---@param petName string 宠物名称
---@return table<number> 匹配的槽位列表
function Pet:FindPetSlotsByName(petName)
    local slots = {}
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        if companionInstance:GetConfigName() == petName then
            table.insert(slots, slotIndex)
        end
    end
    return slots
end

---获取所有不同类型宠物的统计
---@return table<string, number> 宠物类型统计 {petName = count}
function Pet:GetPetTypeStatistics()
    local statistics = {}
    for _, companionInstance in pairs(self.companionInstances) do
        local petName = companionInstance:GetConfigName()
        statistics[petName] = (statistics[petName] or 0) + 1
    end
    return statistics
end

---获取可用于升星的宠物材料统计
---@param targetPetName string 目标宠物名称
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位
---@return table 材料统计信息
function Pet:GetUpgradeMaterialStats(targetPetName, requiredStar, excludeSlot)
    local candidates = self:FindCompanionsByCondition(targetPetName, requiredStar, excludeSlot)
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

return Pet