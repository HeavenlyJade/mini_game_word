-- PetInstance.lua
-- 单个宠物实例类
-- 负责单个宠物的数据封装、属性计算和状态管理

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

---@class PetInstance:Class
---@field petData PetData 宠物数据
---@field petType PetType 宠物配置数据
---@field slotIndex number 在背包中的槽位索引
---@field attributeCache table<string, number> 属性计算缓存
---@field tempBuffs table<string, table> 临时效果列表
local PetInstance = ClassMgr.Class("PetInstance")

function PetInstance:OnInit(petData, petType, slotIndex)
    self.petData = petData or {}
    self.petType = petType
    self.slotIndex = slotIndex or 0
    self.attributeCache = {}
    self.tempBuffs = {}
    
    -- 初始化时刷新属性缓存
    self:RefreshAttributeCache()
    
    gg.log("PetInstance实例创建", self.petData.petName, "槽位", slotIndex)
end



---获取宠物名称
---@return string 宠物名称
function PetInstance:GetName()
    return self.petData.customName ~= "" and self.petData.customName or (self.petType and self.petType.name or self.petData.petName)
end

---获取宠物配置名称
---@return string 配置名称
function PetInstance:GetConfigName()
    return self.petData.petName
end

---获取当前等级
---@return number 当前等级
function PetInstance:GetLevel()
    return self.petData.level or 1
end

---获取当前经验值
---@return number 当前经验值
function PetInstance:GetExp()
    return self.petData.exp or 0
end

---获取当前星级
---@return number 当前星级
function PetInstance:GetStarLevel()
    return self.petData.starLevel or 1
end

---获取心情值
---@return number 心情值 (0-100)
function PetInstance:GetMood()
    return self.petData.mood or 100
end

---是否为激活宠物
---@return boolean 是否激活
function PetInstance:IsActive()
    return self.petData.isActive or false
end

---获取完整信息
---@return table 宠物完整信息
function PetInstance:GetFullInfo()
    return {
        petName = self:GetConfigName(),
        customName = self.petData.customName or "",
        level = self:GetLevel(),
        exp = self:GetExp(),
        starLevel = self:GetStarLevel(),
        learnedSkills = self.petData.learnedSkills or {},
        equipments = self.petData.equipments or {},
        isActive = self:IsActive(),
        mood = self:GetMood(),
        slotIndex = self.slotIndex,
        -- 计算后的属性
        finalAttributes = self:GetAllFinalAttributes()
    }
end

---获取所有最终属性
---@return table<string, number> 所有最终属性
function PetInstance:GetAllFinalAttributes()
    local attributes = {}
    if self.petType and self.petType.baseAttributes then
        for _, attr in ipairs(self.petType.baseAttributes) do
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
function PetInstance:GetFinalAttribute(attrName)
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
function PetInstance:CalculateAttribute(attrName)
    if not self.petType then
        gg.log("警告：宠物配置不存在", self.petData.petName)
        return 0
    end
    
    local finalValue = 0
    
    -- 1. 基础属性
    local baseValue = self.petType:GetBaseAttribute(attrName)
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
function PetInstance:CalculateGrowthAttribute(attrName)
    if not self.petType then return 0 end
    
    local formula = self.petType:GetGrowthFormula(attrName)
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
function PetInstance:CalculateStarAttribute(attrName)
    if not self.petType then return 0 end
    
    local starLevel = self:GetStarLevel()
    local effects = self.petType:GetCarryingEffectsByStarLevel(starLevel)
    
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
function PetInstance:CalculateEquipmentAttribute(attrName)
    -- TODO: 实现装备属性加成计算
    -- 需要根据装备配置表计算装备提供的属性加成
    return 0
end

---计算临时buff加成属性
---@param attrName string 属性名称
---@return number buff加成值
function PetInstance:CalculateBuffAttribute(attrName)
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
function PetInstance:EvaluateExpression(expression)
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
function PetInstance:RefreshAttributeCache()
    self.attributeCache = {}
    gg.log("宠物属性缓存已刷新", self.petData.petName)
end

---获取升级所需经验
---@return number 升级所需经验
function PetInstance:GetRequiredExpForNextLevel()
    local currentLevel = self:GetLevel()
    if not self.petType or currentLevel >= self.petType.maxLevel then
        return 0
    end
    
    -- 简单的经验计算公式
    return currentLevel * 100 + 200
end

---是否可以升级
---@return boolean 是否可以升级
function PetInstance:CanLevelUp()
    if not self.petType then return false end
    
    local currentLevel = self:GetLevel()
    local currentExp = self:GetExp()
    local requiredExp = self:GetRequiredExpForNextLevel()
    
    return currentLevel < self.petType.maxLevel and currentExp >= requiredExp
end

---添加经验
---@param expAmount number 经验值
---@return boolean 是否升级了
function PetInstance:AddExp(expAmount)
    if not expAmount or expAmount <= 0 then
        return false
    end
    
    local leveledUp = false
    local currentExp = self:GetExp()
    local newExp = currentExp + expAmount
    
    self.petData.exp = newExp
    
    -- 检查是否升级
    while self:CanLevelUp() do
        self:DoLevelUp()
        leveledUp = true
    end
    
    
    gg.log("宠物获得经验", self.petData.petName, "经验", expAmount, "当前经验", self.petData.exp, "是否升级", leveledUp)
    return leveledUp
end

---执行升级
function PetInstance:DoLevelUp()
    local requiredExp = self:GetRequiredExpForNextLevel()
    self.petData.level = (self.petData.level or 1) + 1
    self.petData.exp = (self.petData.exp or 0) - requiredExp
    
    self:RefreshAttributeCache()
    
    gg.log("宠物升级", self.petData.petName, "新等级", self.petData.level)
end

---设置等级
---@param newLevel number 新等级
---@return boolean 是否设置成功
function PetInstance:SetLevel(newLevel)
    if not self.petType then return false end
    
    if newLevel < 1 or newLevel > self.petType.maxLevel then
        gg.log("等级设置超出范围", newLevel, "最大等级", self.petType.maxLevel)
        return false
    end
    
    self.petData.level = newLevel
    self.petData.exp = 0 -- 重置经验值
    
    self:RefreshAttributeCache()
    
    gg.log("宠物等级设置", self.petData.petName, "新等级", newLevel)
    return true
end

---执行升星
---@return boolean 是否升星成功
---@return string|nil 错误信息
function PetInstance:DoUpgradeStar()
    self.petData.starLevel = (self.petData.starLevel or 1) + 1
    
    self:RefreshAttributeCache()
    
    gg.log("宠物升星成功", self.petData.petName, "新星级", self.petData.starLevel)
    return true, nil
end

---是否已学会指定技能
---@param skillId string 技能ID
---@return boolean 是否已学会
function PetInstance:HasSkill(skillId)
    if not self.petData.learnedSkills then
        return false
    end
    return self.petData.learnedSkills[skillId] == true
end

---学习技能
---@param skillId string 技能ID
---@return boolean 是否学习成功
---@return string|nil 错误信息
function PetInstance:LearnSkill(skillId)
    if not skillId or skillId == "" then
        return false, "技能ID无效"
    end
    
    if self:HasSkill(skillId) then
        return false, "已经学会该技能"
    end
    
    -- TODO: 检查学习条件（等级、前置技能等）
    
    if not self.petData.learnedSkills then
        self.petData.learnedSkills = {}
    end
    
    self.petData.learnedSkills[skillId] = true
    
    
    gg.log("宠物学会技能", self.petData.petName, "技能", skillId)
    return true, nil
end

---装备物品
---@param slot number 装备槽位
---@param itemId string 物品ID
---@return boolean 是否装备成功
---@return string|nil 错误信息
function PetInstance:EquipItem(slot, itemId)
    if not slot or slot <= 0 then
        return false, "装备槽位无效"
    end
    
    if not self.petData.equipments then
        self.petData.equipments = {}
    end
    
    local oldItemId = self.petData.equipments[slot]
    self.petData.equipments[slot] = itemId
    
    self:RefreshAttributeCache()
    
    gg.log("宠物装备物品", self.petData.petName, "槽位", slot, "物品", itemId, "替换", oldItemId)
    return true, nil
end

---卸下装备
---@param slot number 装备槽位
---@return string|nil 被卸下的物品ID
function PetInstance:UnequipItem(slot)
    if not self.petData.equipments then
        return nil
    end
    
    local itemId = self.petData.equipments[slot]
    if itemId then
        self.petData.equipments[slot] = nil
        
        self:RefreshAttributeCache()
        
        gg.log("宠物卸下装备", self.petData.petName, "槽位", slot, "物品", itemId)
    end
    
    return itemId
end

---设置心情值
---@param mood number 心情值 (0-100)
function PetInstance:SetMood(mood)
    mood = math.max(0, math.min(100, mood))
    self.petData.mood = mood
    
    
    gg.log("宠物心情值设置", self.petData.petName, "心情", mood)
end

---设置激活状态
---@param active boolean 是否激活
function PetInstance:SetActive(active)
    self.petData.isActive = active
    
    
    gg.log("宠物激活状态", self.petData.petName, "激活", active)
end

---设置自定义名称
---@param customName string 自定义名称
function PetInstance:SetCustomName(customName)
    self.petData.customName = customName or ""
    
    
    gg.log("宠物自定义名称", self.petData.petName, "新名称", customName)
end

---添加临时buff
---@param buffId string buff ID
---@param duration number 持续时间（秒）
---@param attributes table<string, number> 属性加成
function PetInstance:AddTempBuff(buffId, duration, attributes)
    self.tempBuffs[buffId] = {
        duration = duration,
        startTime = os.time(),
        attributes = attributes or {}
    }
    
    self:RefreshAttributeCache()
    
    gg.log("宠物添加临时buff", self.petData.petName, "buff", buffId, "持续时间", duration)
end

---移除临时buff
---@param buffId string buff ID
function PetInstance:RemoveTempBuff(buffId)
    if self.tempBuffs[buffId] then
        self.tempBuffs[buffId] = nil
        self:RefreshAttributeCache()
        
        gg.log("宠物移除临时buff", self.petData.petName, "buff", buffId)
    end
end

---更新临时buff（移除过期的）
function PetInstance:UpdateTempBuffs()
    local currentTime = os.time()
    local needRefresh = false
    
    for buffId, buffData in pairs(self.tempBuffs) do
        if currentTime >= buffData.startTime + buffData.duration then
            self.tempBuffs[buffId] = nil
            needRefresh = true
            gg.log("宠物buff过期", self.petData.petName, "buff", buffId)
        end
    end
    
    if needRefresh then
        self:RefreshAttributeCache()
    end
end

return PetInstance