-- Pet.lua
-- 宠物数据类
-- 负责整合宠物配置和玩家数据，提供宠物相关的所有计算和状态管理功能

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

---@class Pet:Class
---@field petData PetData 宠物数据引用（来自PetMgr）
---@field petType PetType 宠物配置数据
---@field slotIndex number 在背包中的槽位索引
---@field isDirty boolean 数据是否已修改
---@field attributeCache table<string, number> 属性计算缓存
---@field tempBuffs table<string, table> 临时效果列表
---@field onDirtyCallback function 脏数据回调函数
local Pet = ClassMgr.Class("Pet")

function Pet:OnInit(petData, petType, slotIndex, onDirtyCallback)
    self.petData = petData or {}
    self.petType = petType
    self.slotIndex = slotIndex or 0
    self.isDirty = false
    self.attributeCache = {}
    self.tempBuffs = {}
    self.onDirtyCallback = onDirtyCallback
    
    -- 初始化时刷新属性缓存
    self:RefreshAttributeCache()
    
    gg.log("Pet实例创建", self.petData.petName, "槽位", slotIndex)
end

---标记数据已修改
function Pet:MarkDirty()
    if not self.isDirty then
        self.isDirty = true
        if self.onDirtyCallback then
            self.onDirtyCallback(self.slotIndex)
        end
        gg.log("宠物数据标记为脏", self.petData.petName, "槽位", self.slotIndex)
    end
end

---获取宠物名称
---@return string 宠物名称
function Pet:GetName()
    return self.petData.customName ~= "" and self.petData.customName or (self.petType and self.petType.name or self.petData.petName)
end

---获取宠物配置名称
---@return string 配置名称
function Pet:GetConfigName()
    return self.petData.petName
end

---获取当前等级
---@return number 当前等级
function Pet:GetLevel()
    return self.petData.level or 1
end

---获取当前经验值
---@return number 当前经验值
function Pet:GetExp()
    return self.petData.exp or 0
end

---获取当前星级
---@return number 当前星级
function Pet:GetStarLevel()
    return self.petData.starLevel or 1
end

---获取心情值
---@return number 心情值 (0-100)
function Pet:GetMood()
    return self.petData.mood or 100
end

---是否为激活宠物
---@return boolean 是否激活
function Pet:IsActive()
    return self.petData.isActive or false
end

---获取最终属性值
---@param attrName string 属性名称
---@return number 最终属性值
function Pet:GetFinalAttribute(attrName)
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
function Pet:CalculateAttribute(attrName)
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
function Pet:CalculateGrowthAttribute(attrName)
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
function Pet:CalculateStarAttribute(attrName)
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
function Pet:CalculateEquipmentAttribute(attrName)
    -- TODO: 实现装备属性加成计算
    -- 需要根据装备配置表计算装备提供的属性加成
    return 0
end

---计算临时buff加成属性
---@param attrName string 属性名称
---@return number buff加成值
function Pet:CalculateBuffAttribute(attrName)
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
function Pet:EvaluateExpression(expression)
    -- 安全的数学表达式求值（仅支持基本运算）
    local safeExpression = string.gsub(expression, "[^0-9+%-*/().%s]", "")
    
    local success, result = pcall(function()
        return load("return " .. safeExpression)()
    end)
    
    if success and type(result) == "number" then
        return result
    end
    
    gg.log("表达式计算失败", expression)
    return 0
end

---刷新属性缓存
function Pet:RefreshAttributeCache()
    self.attributeCache = {}
    gg.log("刷新宠物属性缓存", self.petData.petName)
end

---获取升级所需经验
---@return number 升级所需经验值
function Pet:GetNextLevelExp()
    if not self.petType then return 0 end
    
    local currentLevel = self:GetLevel()
    if currentLevel >= self.petType.maxLevel then
        return 0 -- 已满级
    end
    
    -- 简单的经验公式：level * 100
    return currentLevel * 100
end

---是否可以升级
---@return boolean 是否可以升级
function Pet:CanLevelUp()
    if not self.petType then return false end
    
    local currentLevel = self:GetLevel()
    local currentExp = self:GetExp()
    local requiredExp = self:GetNextLevelExp()
    
    return currentLevel < self.petType.maxLevel and currentExp >= requiredExp
end

---是否达到最大等级
---@return boolean 是否满级
function Pet:IsMaxLevel()
    if not self.petType then return true end
    return self:GetLevel() >= self.petType.maxLevel
end

---增加经验值
---@param amount number 经验值数量
---@return boolean 是否升级了
function Pet:AddExp(amount)
    if not amount or amount <= 0 then return false end
    
    local oldLevel = self:GetLevel()
    self.petData.exp = (self.petData.exp or 0) + amount
    
    -- 检查升级
    local leveledUp = false
    while self:CanLevelUp() do
        local requiredExp = self:GetNextLevelExp()
        self.petData.exp = self.petData.exp - requiredExp
        self.petData.level = (self.petData.level or 1) + 1
        leveledUp = true
        
        gg.log("宠物升级", self.petData.petName, "新等级", self.petData.level)
    end
    
    if leveledUp then
        self:RefreshAttributeCache()
    end
    
    self:MarkDirty()
    
    return leveledUp
end

---设置等级
---@param newLevel number 新等级
---@return boolean 是否设置成功
function Pet:SetLevel(newLevel)
    if not self.petType then return false end
    
    if newLevel < 1 or newLevel > self.petType.maxLevel then
        gg.log("等级设置超出范围", newLevel, "最大等级", self.petType.maxLevel)
        return false
    end
    
    self.petData.level = newLevel
    self.petData.exp = 0 -- 重置经验值
    
    self:RefreshAttributeCache()
    self:MarkDirty()
    
    gg.log("宠物等级设置", self.petData.petName, "新等级", newLevel)
    return true
end

---是否可以升星
---@return boolean 是否可以升星
---@return string|nil 错误信息
function Pet:CanUpgradeStar()
    if not self.petType then
        return false, "宠物配置不存在"
    end
    
    local currentStar = self:GetStarLevel()
    local maxStar = #self.petType.starUpgradeCosts + 1 -- 配置数组长度+1为最大星级
    
    if currentStar >= maxStar then
        return false, "已达到最大星级"
    end
    
    -- 检查升星材料（需要与背包系统集成）
    local upgradeCost = self.petType:GetStarUpgradeCost(currentStar + 1)
    if not upgradeCost then
        return false, "缺少升星配置"
    end
    
    -- TODO: 检查材料是否足够
    
    return true, nil
end

---升星
---@return boolean 是否升星成功
---@return string|nil 错误信息
function Pet:UpgradeStar()
    local canUpgrade, errorMsg = self:CanUpgradeStar()
    if not canUpgrade then
        return false, errorMsg
    end
    
    -- TODO: 消耗材料
    
    self.petData.starLevel = (self.petData.starLevel or 1) + 1
    
    self:RefreshAttributeCache()
    self:MarkDirty()
    
    gg.log("宠物升星成功", self.petData.petName, "新星级", self.petData.starLevel)
    return true, nil
end

---是否已学会指定技能
---@param skillId string 技能ID
---@return boolean 是否已学会
function Pet:HasSkill(skillId)
    if not self.petData.learnedSkills then
        return false
    end
    return self.petData.learnedSkills[skillId] == true
end

---学习技能
---@param skillId string 技能ID
---@return boolean 是否学习成功
---@return string|nil 错误信息
function Pet:LearnSkill(skillId)
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
    
    self:MarkDirty()
    
    gg.log("宠物学会技能", self.petData.petName, "技能", skillId)
    return true, nil
end

---装备物品
---@param slot number 装备槽位
---@param itemId string 物品ID
---@return boolean 是否装备成功
---@return string|nil 错误信息
function Pet:EquipItem(slot, itemId)
    if not slot or slot <= 0 then
        return false, "装备槽位无效"
    end
    
    if not self.petData.equipments then
        self.petData.equipments = {}
    end
    
    local oldItemId = self.petData.equipments[slot]
    self.petData.equipments[slot] = itemId
    
    self:RefreshAttributeCache()
    self:MarkDirty()
    
    gg.log("宠物装备物品", self.petData.petName, "槽位", slot, "物品", itemId, "替换", oldItemId)
    return true, nil
end

---卸下装备
---@param slot number 装备槽位
---@return string|nil 被卸下的物品ID
function Pet:UnequipItem(slot)
    if not self.petData.equipments then
        return nil
    end
    
    local itemId = self.petData.equipments[slot]
    if itemId then
        self.petData.equipments[slot] = nil
        
        self:RefreshAttributeCache()
        self:MarkDirty()
        
        gg.log("宠物卸下装备", self.petData.petName, "槽位", slot, "物品", itemId)
    end
    
    return itemId
end

---设置心情值
---@param mood number 心情值 (0-100)
function Pet:SetMood(mood)
    mood = math.max(0, math.min(100, mood))
    self.petData.mood = mood
    
    self:MarkDirty()
    
    gg.log("宠物心情值设置", self.petData.petName, "心情", mood)
end

---设置激活状态
---@param active boolean 是否激活
function Pet:SetActive(active)
    self.petData.isActive = active
    
    self:MarkDirty()
    
    gg.log("宠物激活状态", self.petData.petName, "激活", active)
end

---设置自定义名称
---@param customName string 自定义名称
function Pet:SetCustomName(customName)
    self.petData.customName = customName or ""
    
    self:MarkDirty()
    
    gg.log("宠物自定义名称", self.petData.petName, "新名称", customName)
end

---添加临时buff
---@param buffId string buff ID
---@param duration number 持续时间（秒）
---@param attributes table 属性加成 {攻击 = 10, 防御 = 5}
function Pet:AddBuff(buffId, duration, attributes)
    if not buffId then return end
    
    self.tempBuffs[buffId] = {
        duration = duration,
        attributes = attributes or {},
        startTime = os.time()
    }
    
    self:RefreshAttributeCache()
    
    gg.log("宠物添加buff", self.petData.petName, "buff", buffId, "持续", duration)
end

---移除临时buff
---@param buffId string buff ID
function Pet:RemoveBuff(buffId)
    if self.tempBuffs[buffId] then
        self.tempBuffs[buffId] = nil
        self:RefreshAttributeCache()
        
        gg.log("宠物移除buff", self.petData.petName, "buff", buffId)
    end
end

---更新临时buff（清理过期的buff）
function Pet:UpdateBuffs()
    local currentTime = os.time()
    local removed = false
    
    for buffId, buffData in pairs(self.tempBuffs) do
        if buffData.startTime + buffData.duration <= currentTime then
            self.tempBuffs[buffId] = nil
            removed = true
            gg.log("宠物buff过期", self.petData.petName, "buff", buffId)
        end
    end
    
    if removed then
        self:RefreshAttributeCache()
    end
end

---获取宠物完整信息（用于客户端同步）
---@return table 宠物信息
function Pet:GetFullInfo()
    -- 更新buff状态
    self:UpdateBuffs()
    
    return {
        petName = self.petData.petName,
        customName = self.petData.customName,
        level = self:GetLevel(),
        exp = self:GetExp(),
        starLevel = self:GetStarLevel(),
        mood = self:GetMood(),
        isActive = self:IsActive(),
        learnedSkills = self.petData.learnedSkills or {},
        equipments = self.petData.equipments or {},
        slotIndex = self.slotIndex,
        -- 计算后的属性
        finalAttributes = {
            ["攻击"] = self:GetFinalAttribute("攻击"),
            ["防御"] = self:GetFinalAttribute("防御"),
            ["生命"] = self:GetFinalAttribute("生命"),
            ["速度"] = self:GetFinalAttribute("速度")
        }
    }
end

return Pet