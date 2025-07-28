-- CompanionInstance.lua
-- 通用伙伴实例类（宠物/伙伴通用）
-- 负责单个伙伴的数据封装、属性计算和状态管理

local game = game
local math = math
local table = table
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class CompanionInstance:Class
---@field companionData table 伙伴数据（PetData 或 PartnerData）
---@field companionTypeConfig table 伙伴配置数据（PetType 或 PartnerType）
---@field companionType string 伙伴类型（"宠物" 或 "伙伴"）
---@field slotIndex number 在背包中的槽位索引
---@field attributeCache table<string, number> 属性计算缓存
---@field tempBuffs table<string, table> 临时效果列表
local CompanionInstance = ClassMgr.Class("CompanionInstance")

function CompanionInstance:OnInit(companionData, companionType, slotIndex)
    self.companionData = companionData or {}
    self.companionType = companionType 
    self.slotIndex = slotIndex or 0
    self.attributeCache = {}
    self.tempBuffs = {}
    
    -- 根据伙伴类型加载配置
    self:LoadCompanionConfig()
    
    -- 初始化时刷新属性缓存
    self:RefreshAttributeCache()
    
end

---根据伙伴类型加载配置
function CompanionInstance:LoadCompanionConfig()
    local configName = self:GetConfigName()
    if not configName or configName == "" then
        gg.log("警告：伙伴配置名称为空", self.companionType, self.slotIndex)
        return
    end
    
    if self.companionType == "宠物" then
        self.companionTypeConfig = ConfigLoader.GetPet(configName)
    elseif self.companionType == "伙伴" then
        self.companionTypeConfig = ConfigLoader.GetPartner(configName)
    end
    
    if not self.companionTypeConfig then
        gg.log("警告：找不到伙伴配置", self.companionType, configName)
    end
end

---获取伙伴类型
---@return string 伙伴类型
function CompanionInstance:GetCompanionType()
    return self.companionType
end

---获取伙伴显示名称
---@return string 伙伴名称
function CompanionInstance:GetName()
    local customName = self.companionData.customName or ""
    if customName ~= "" then
        return customName
    end
    
    if self.companionTypeConfig and self.companionTypeConfig.name then
        return self.companionTypeConfig.name
    end
    
    return self:GetConfigName()
end

---获取伙伴配置名称
---@return string 配置名称
function CompanionInstance:GetConfigName()
    if self.companionType == "宠物" then
        return self.companionData.petName or ""
    elseif self.companionType == "伙伴" then
        return self.companionData.partnerName or ""
    end
    return ""
end

---获取当前等级
---@return number 当前等级
function CompanionInstance:GetLevel()
    return self.companionData.level or 1
end

---获取当前经验值
---@return number 当前经验值
function CompanionInstance:GetExp()
    return self.companionData.exp or 0
end

---获取当前星级
---@return number 当前星级
function CompanionInstance:GetStarLevel()
    return self.companionData.starLevel or 1
end

---获取心情值
---@return number 心情值 (0-100)
function CompanionInstance:GetMood()
    return self.companionData.mood or 100
end

--- 【新增】是否已锁定
---@return boolean
function CompanionInstance:IsLocked()
    return self.companionData.isLocked or false
end

---是否为激活伙伴
---@return boolean 是否激活
function CompanionInstance:IsActive()
    return self.companionData.isActive or false
end

---获取完整信息
---@return table 伙伴完整信息
function CompanionInstance:GetFullInfo()
    local configName = self:GetConfigName()
    return {
        companionName = configName,
        companionType = self.companionType,
        customName = self.companionData.customName or "",
        level = self:GetLevel(),
        exp = self:GetExp(),
        starLevel = self:GetStarLevel(),
        learnedSkills = self.companionData.learnedSkills or {},
        equipments = self.companionData.equipments or {},
        isActive = self:IsActive(),
        mood = self:GetMood(),
        slotIndex = self.slotIndex,
        isLocked = self:IsLocked(), -- 【新增】
        -- 计算后的属性
        finalAttributes = self:GetAllFinalAttributes()
    }
end

---获取所有最终属性
---@return table<string, number> 所有最终属性
function CompanionInstance:GetAllFinalAttributes()
    local attributes = {}
    if self.companionTypeConfig and self.companionTypeConfig.baseAttributes then
        for _, attr in ipairs(self.companionTypeConfig.baseAttributes) do
            local attrName = attr["属性名称"]
            if attrName then
                attributes[attrName] = self:GetFinalAttribute(attrName)
            end
        end
    end
    return attributes
end

---获取最终属性值
---@param attrName string 属性名称
---@return number 最终属性值
function CompanionInstance:GetFinalAttribute(attrName)
    -- 先从缓存获取
    if self.attributeCache[attrName] then
        return self.attributeCache[attrName]
    end
    
    -- 计算最终属性
    local finalValue = self:CalculateAttribute(attrName)
    
    -- 缓存结果
    self.attributeCache[attrName] = finalValue
    
    return finalValue
end

---计算指定属性的最终数值
---@param attrName string 属性名称
---@return number 计算后的属性值
function CompanionInstance:CalculateAttribute(attrName)
    if not self.companionTypeConfig then
        gg.log("警告：伙伴配置不存在", self.companionType, self:GetConfigName())
        return 0
    end
    
    local finalValue = 0
    
    -- 1. 基础属性
    local baseValue = self.companionTypeConfig:GetBaseAttribute(attrName)
    finalValue = finalValue + baseValue
    
    -- 2. 等级成长
    local growthValue = self:CalculateGrowthAttribute(attrName)
    finalValue = finalValue + growthValue
    
    -- 3. 星级加成
    local starValue = self:CalculateStarAttribute(attrName)
    finalValue = finalValue + starValue
    
    -- 4. 装备加成
    local equipValue = self:CalculateEquipmentAttribute(attrName)
    finalValue = finalValue + equipValue
    
    -- 5. 临时buff加成
    local buffValue = self:CalculateBuffAttribute(attrName)
    finalValue = finalValue + buffValue
    
    return math.max(0, math.floor(finalValue))
end

---计算等级成长属性
---@param attrName string 属性名称
---@return number 成长属性值
function CompanionInstance:CalculateGrowthAttribute(attrName)
    if not self.companionTypeConfig then return 0 end
    
    local formula = self.companionTypeConfig:GetGrowthFormula(attrName)
    if not formula or formula == "" then
        return 0
    end
    
    -- 简单的公式解析，支持 LVL*系数 格式
    local level = self:GetLevel()
    
    -- 替换LVL为实际等级值
    local expression = string.gsub(formula, "LVL", tostring(level))
    
    -- 简单的数学表达式计算（仅支持基本运算）
    local result = self:EvaluateExpression(expression)
    
    return result or 0
end

---计算星级加成属性
---@param attrName string 属性名称
---@return number 星级加成值
function CompanionInstance:CalculateStarAttribute(attrName)
    if not self.companionTypeConfig then return 0 end
    
    local starLevel = self:GetStarLevel()
    local effects = self.companionTypeConfig:GetCarryingEffectsByStarLevel(starLevel)
    
    local totalBonus = 0
    for _, effect in ipairs(effects) do
        if effect["触发条件列表"] then
            for _, condition in ipairs(effect["触发条件列表"]) do
                if condition["变量名称"] and string.find(condition["变量名称"], attrName) then
                    totalBonus = totalBonus + (condition["效果数值"] or 0)
                end
            end
        end
    end
    
    return totalBonus
end

---计算装备加成属性
---@param attrName string 属性名称
---@return number 装备加成值
function CompanionInstance:CalculateEquipmentAttribute(attrName)
    -- TODO: 实现装备属性加成计算
    -- 需要根据装备配置表计算装备提供的属性加成
    return 0
end

---计算临时buff加成属性
---@param attrName string 属性名称
---@return number buff加成值
function CompanionInstance:CalculateBuffAttribute(attrName)
    local totalBonus = 0
    for buffId, buffData in pairs(self.tempBuffs) do
        if buffData.attributes and buffData.attributes[attrName] then
            totalBonus = totalBonus + buffData.attributes[attrName]
        end
    end
    return totalBonus
end

---简单的数学表达式求值
---@param expression string 数学表达式
---@return number|nil 计算结果
function CompanionInstance:EvaluateExpression(expression)
    -- 简单的四则运算解析
    -- 仅支持基本格式：数字*数字、数字+数字等
    local patterns = {
        "(%d+)%*(%d+)",
        "(%d+)%/(%d+)",
        "(%d+)%+(%d+)",
        "(%d+)%-(%d+)"
    }
    
    for _, pattern in ipairs(patterns) do
        local a, b = string.match(expression, pattern)
        if a and b then
            a, b = tonumber(a), tonumber(b)
            if pattern:find("%*") then
                return a * b
            elseif pattern:find("%/") then
                return b ~= 0 and a / b or 0
            elseif pattern:find("%+") then
                return a + b
            elseif pattern:find("%-") then
                return a - b
            end
        end
    end
    
    -- 如果是纯数字
    return tonumber(expression)
end

---刷新属性缓存
function CompanionInstance:RefreshAttributeCache()
    self.attributeCache = {}
    gg.log("伙伴属性缓存已刷新", self.companionType, self:GetConfigName())
end

---获取升级所需经验
---@return number 升级所需经验
function CompanionInstance:GetRequiredExpForNextLevel()
    local currentLevel = self:GetLevel()
    if not self.companionTypeConfig or currentLevel >= self.companionTypeConfig.maxLevel then
        return 0
    end
    
    -- 简单的经验计算公式
    return currentLevel * 100 + 200
end

---是否可以升级
---@return boolean 是否可以升级
function CompanionInstance:CanLevelUp()
    if not self.companionTypeConfig then return false end
    
    local currentLevel = self:GetLevel()
    local currentExp = self:GetExp()
    local requiredExp = self:GetRequiredExpForNextLevel()
    
    return currentLevel < self.companionTypeConfig.maxLevel and currentExp >= requiredExp
end

---添加经验
---@param expAmount number 经验值
---@return boolean 是否升级了
function CompanionInstance:AddExp(expAmount)
    if not expAmount or expAmount <= 0 then
        return false
    end
    
    local leveledUp = false
    local currentExp = self:GetExp()
    local newExp = currentExp + expAmount
    
    self.companionData.exp = newExp
    
    -- 检查是否升级
    while self:CanLevelUp() do
        self:DoLevelUp()
        leveledUp = true
    end
    
    gg.log("伙伴获得经验", self.companionType, self:GetConfigName(), "经验", expAmount, "当前经验", self.companionData.exp, "是否升级", leveledUp)
    return leveledUp
end

---执行升级
function CompanionInstance:DoLevelUp()
    local requiredExp = self:GetRequiredExpForNextLevel()
    self.companionData.level = (self.companionData.level or 1) + 1
    self.companionData.exp = (self.companionData.exp or 0) - requiredExp
    
    self:RefreshAttributeCache()
    
    gg.log("伙伴升级", self.companionType, self:GetConfigName(), "新等级", self.companionData.level)
end

---设置等级
---@param newLevel number 新等级
---@return boolean 是否设置成功
function CompanionInstance:SetLevel(newLevel)
    if not self.companionTypeConfig then return false end
    
    if newLevel < 1 or newLevel > self.companionTypeConfig.maxLevel then
        gg.log("等级设置超出范围", newLevel, "最大等级", self.companionTypeConfig.maxLevel)
        return false
    end
    
    self.companionData.level = newLevel
    self.companionData.exp = 0 -- 重置经验值
    
    self:RefreshAttributeCache()
    
    gg.log("伙伴等级设置", self.companionType, self:GetConfigName(), "新等级", newLevel)
    return true
end

---执行升星
---@return boolean 是否升星成功
---@return string|nil 错误信息
function CompanionInstance:DoUpgradeStar()
    self.companionData.starLevel = (self.companionData.starLevel or 1) + 1
    
    self:RefreshAttributeCache()
    
    gg.log("伙伴升星成功", self.companionType, self:GetConfigName(), "新星级", self.companionData.starLevel)
    return true, nil
end

---是否已学会指定技能
---@param skillId string 技能ID
---@return boolean 是否已学会
function CompanionInstance:HasSkill(skillId)
    if not self.companionData.learnedSkills then
        return false
    end
    return self.companionData.learnedSkills[skillId] == true
end

---学习技能
---@param skillId string 技能ID
---@return boolean 是否学习成功
---@return string|nil 错误信息
function CompanionInstance:LearnSkill(skillId)
    if not skillId or skillId == "" then
        return false, "技能ID无效"
    end
    
    if self:HasSkill(skillId) then
        return false, "已经学会该技能"
    end
    
    -- TODO: 检查学习条件（等级、前置技能等）
    
    if not self.companionData.learnedSkills then
        self.companionData.learnedSkills = {}
    end
    
    self.companionData.learnedSkills[skillId] = true
    
    gg.log("伙伴学会技能", self.companionType, self:GetConfigName(), "技能", skillId)
    return true, nil
end

---装备物品
---@param slot number 装备槽位
---@param itemId string 物品ID
---@return boolean 是否装备成功
---@return string|nil 错误信息
function CompanionInstance:EquipItem(slot, itemId)
    if not slot or slot <= 0 then
        return false, "装备槽位无效"
    end
    
    if not self.companionData.equipments then
        self.companionData.equipments = {}
    end
    
    local oldItemId = self.companionData.equipments[slot]
    self.companionData.equipments[slot] = itemId
    
    self:RefreshAttributeCache()
    
    gg.log("伙伴装备物品", self.companionType, self:GetConfigName(), "槽位", slot, "物品", itemId, "替换", oldItemId)
    return true, nil
end

---卸下装备
---@param slot number 装备槽位
---@return string|nil 被卸下的物品ID
function CompanionInstance:UnequipItem(slot)
    if not self.companionData.equipments then
        return nil
    end
    
    local itemId = self.companionData.equipments[slot]
    if itemId then
        self.companionData.equipments[slot] = nil
        
        self:RefreshAttributeCache()
        
        gg.log("伙伴卸下装备", self.companionType, self:GetConfigName(), "槽位", slot, "物品", itemId)
    end
    
    return itemId
end

---设置心情值
---@param mood number 心情值 (0-100)
function CompanionInstance:SetMood(mood)
    mood = math.max(0, math.min(100, mood))
    self.companionData.mood = mood
    
    gg.log("伙伴心情值设置", self.companionType, self:GetConfigName(), "心情", mood)
end

--- 【新增】设置锁定状态
---@param locked boolean
function CompanionInstance:SetLocked(locked)
    self.companionData.isLocked = locked
    gg.log("伙伴锁定状态设置", self.companionType, self:GetConfigName(), "锁定", locked)
end

---设置激活状态
---@param active boolean 是否激活
function CompanionInstance:SetActive(active)
    self.companionData.isActive = active
    
    gg.log("伙伴激活状态", self.companionType, self:GetConfigName(), "激活", active)
end

---设置自定义名称
---@param customName string 自定义名称
function CompanionInstance:SetCustomName(customName)
    self.companionData.customName = customName or ""
    
    gg.log("伙伴自定义名称", self.companionType, self:GetConfigName(), "新名称", customName)
end

---添加临时buff
---@param buffId string buff ID
---@param duration number 持续时间（秒）
---@param attributes table<string, number> 属性加成
function CompanionInstance:AddTempBuff(buffId, duration, attributes)
    self.tempBuffs[buffId] = {
        duration = duration,
        startTime = os.time(),
        attributes = attributes or {}
    }
    
    self:RefreshAttributeCache()
    
    gg.log("伙伴添加临时buff", self.companionType, self:GetConfigName(), "buff", buffId, "持续时间", duration)
end

---移除临时buff
---@param buffId string buff ID
function CompanionInstance:RemoveTempBuff(buffId)
    if self.tempBuffs[buffId] then
        self.tempBuffs[buffId] = nil
        self:RefreshAttributeCache()
        
        gg.log("伙伴移除临时buff", self.companionType, self:GetConfigName(), "buff", buffId)
    end
end

---更新临时buff（移除过期的）
function CompanionInstance:UpdateTempBuffs()
    local currentTime = os.time()
    local needRefresh = false
    
    for buffId, buffData in pairs(self.tempBuffs) do
        if currentTime >= buffData.startTime + buffData.duration then
            self.tempBuffs[buffId] = nil
            needRefresh = true
            gg.log("伙伴buff过期", self.companionType, self:GetConfigName(), "buff", buffId)
        end
    end
    
    if needRefresh then
        self:RefreshAttributeCache()
    end
end

--- 获取物品加成效果
---@return table<string, table> 物品加成 {[物品目标] = {fixed = number, percentage = number}}
function CompanionInstance:GetItemBonuses()
    local starLevel = self:GetStarLevel()
    if not self.companionTypeConfig or not self.companionTypeConfig.CalculateCarryingEffectsByStarLevel then
        return {}
    end
    
    local allEffects = self.companionTypeConfig:CalculateCarryingEffectsByStarLevel(starLevel)
    
    -- 【日志1】打印从类型配置中收到的所有计算后的效果
    gg.log(string.format("[CompanionInstance] GetItemBonuses for %s (Slot %d, Star %d) - Received effects:", self:GetName(), self.slotIndex, starLevel))
    gg.log(allEffects)
    
    local itemBonuses = {}
    
    for variableName, effectData in pairs(allEffects) do
        -- 筛选出物品加成类型
        if effectData.bonusType == "物品" and effectData.itemTarget then
            local bonusValue = effectData.value or 0
            local itemName = effectData.itemTarget

            if not itemBonuses[itemName] then
                itemBonuses[itemName] = { fixed = 0, percentage = 0 }
            end

            -- 【修复】根据 isPercentage 标志将加成分配到不同字段
            if effectData.isPercentage then
                itemBonuses[itemName].percentage = (itemBonuses[itemName].percentage or 0) + (bonusValue * 100)
            else
                itemBonuses[itemName].fixed = (itemBonuses[itemName].fixed or 0) + bonusValue
            end
        end
    end
    
    -- 【日志2】打印最终筛选出的、准备返回给上层的物品加成
    gg.log(string.format("[CompanionInstance] GetItemBonuses for %s (Slot %d) - Final item bonuses:", self:GetName(), self.slotIndex))
    gg.log(itemBonuses)
    
    return itemBonuses
end

return CompanionInstance