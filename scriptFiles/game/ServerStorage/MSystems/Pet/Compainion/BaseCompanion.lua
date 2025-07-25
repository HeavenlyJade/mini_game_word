-- BaseCompanion.lua
-- 伙伴管理器基类
-- 提供宠物和伙伴共用的核心业务逻辑

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
local CompanionInstance = require(ServerStorage.MSystems.Pet.CompanionInstance) ---@type CompanionInstance

---@class BaseCompanion:Class 伙伴管理器基类
---@field uin number 玩家ID
---@field companionInstances table<number, CompanionInstance> 伙伴实例列表 {slotIndex = CompanionInstance}
---@field activeCompanionSlot number 当前激活的伙伴槽位 (0表示无激活)
---@field maxSlots number 最大槽位数
---@field companionType string 伙伴类型（"宠物" 或 "伙伴"）
local BaseCompanion = ClassMgr.Class("BaseCompanion")

function BaseCompanion:OnInit(uin, companionType, maxSlots)
    self.uin = uin or 0
    self.companionInstances = {}
    self.activeCompanionSlot = 0
    self.maxSlots = maxSlots or 50
    self.companionType = companionType or "未知"
    
    gg.log("BaseCompanion基类初始化", uin, "类型", companionType, "最大槽位", maxSlots)
end

-- =================================
-- 抽象方法（子类必须实现）
-- =================================

---加载配置（子类必须实现）
---@param companionName string 伙伴名称
---@return table|nil 配置数据
function BaseCompanion:LoadConfigByName(companionName)
    error("子类必须实现LoadConfigByName方法")
end

---创建伙伴数据（子类必须实现）
---@param companionName string 伙伴名称
---@param companionTypeConfig table 伙伴配置
---@return table 伙伴数据
function BaseCompanion:CreateCompanionData(companionName, companionTypeConfig)
    error("子类必须实现CreateCompanionData方法")
end

---获取保存数据（子类必须实现）
---@return table 保存数据
function BaseCompanion:GetSaveData()
    error("子类必须实现GetSaveData方法")
end

-- =================================
-- 通用方法实现
-- =================================

---创建伙伴实例
---@param companionData table 伙伴数据
---@param slotIndex number 槽位索引
---@return CompanionInstance|nil 伙伴实例
function BaseCompanion:CreateCompanionInstance(companionData, slotIndex)
    if not companionData then
        gg.log("警告：伙伴数据无效", self.companionType, slotIndex)
        return nil
    end
    
    return CompanionInstance.New(companionData, self.companionType, slotIndex)
end

---获取伙伴数量
---@return number 伙伴数量
function BaseCompanion:GetCompanionCount()
    local count = 0
    for _ in pairs(self.companionInstances) do
        count = count + 1
    end
    return count
end

---获取指定槽位的伙伴实例
---@param slotIndex number 槽位索引
---@return CompanionInstance|nil 伙伴实例
function BaseCompanion:GetCompanionBySlot(slotIndex)
    return self.companionInstances[slotIndex]
end

---获取激活的伙伴实例
---@return CompanionInstance|nil 激活的伙伴实例
---@return number|nil 槽位索引
function BaseCompanion:GetActiveCompanion()
    if self.activeCompanionSlot == 0 then
        return nil, nil
    end
    
    local companionInstance = self.companionInstances[self.activeCompanionSlot]
    return companionInstance, self.activeCompanionSlot
end

---获取所有伙伴信息
---@return table 伙伴列表信息
function BaseCompanion:GetCompanionList()
    local companionList = {}
    local activeCompanionId = ""
    
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        companionList[slotIndex] = companionInstance:GetFullInfo()
        if slotIndex == self.activeCompanionSlot then
            activeCompanionId = companionInstance:GetConfigName()
        end
    end
    
    return {
        companionList = companionList,
        activeCompanionId = activeCompanionId,
        companionSlots = self.maxSlots,
        companionType = self.companionType
    }
end

---查找空闲槽位
---@return number|nil 空闲槽位索引
function BaseCompanion:FindEmptySlot()
    for i = 1, self.maxSlots do
        if not self.companionInstances[i] then
            return i
        end
    end
    return nil
end

---添加伙伴到指定槽位
---@param companionName string 伙伴配置名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function BaseCompanion:AddCompanion(companionName, slotIndex)
    -- 检查伙伴配置是否存在
    local companionTypeConfig = self:LoadConfigByName(companionName)
    if not companionTypeConfig then
        return false, "伙伴配置不存在", nil
    end
    
    -- 自动分配槽位
    if not slotIndex then
        slotIndex = self:FindEmptySlot()
        if not slotIndex then
            return false, "背包已满", nil
        end
    end
    
    -- 检查槽位是否有效
    if slotIndex < 1 or slotIndex > self.maxSlots then
        return false, "无效的槽位索引", nil
    end
    
    -- 检查槽位是否被占用
    if self.companionInstances[slotIndex] then
        return false, "槽位已被占用", nil
    end
    
    -- 创建新的伙伴数据
    local newCompanionData = self:CreateCompanionData(companionName, companionTypeConfig)
    
    -- 创建伙伴实例并添加到槽位
    local companionInstance = self:CreateCompanionInstance(newCompanionData, slotIndex)
    if companionInstance then
        self.companionInstances[slotIndex] = companionInstance
        gg.log("添加伙伴成功", self.uin, self.companionType, companionName, "槽位", slotIndex)
        return true, nil, slotIndex
    else
        return false, "创建伙伴实例失败", nil
    end
end

---移除指定槽位的伙伴
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function BaseCompanion:RemoveCompanion(slotIndex)
    local companionInstance = self.companionInstances[slotIndex]
    if not companionInstance then
        return false, "槽位为空"
    end
    
    -- 如果是激活伙伴，取消激活
    if self.activeCompanionSlot == slotIndex then
        self.activeCompanionSlot = 0
    end
    
    -- 移除伙伴实例
    self.companionInstances[slotIndex] = nil
    
    gg.log("移除伙伴成功", self.uin, self.companionType, companionInstance:GetConfigName(), "槽位", slotIndex)
    return true, nil
end

---设置激活伙伴
---@param slotIndex number 槽位索引（0表示取消激活）
---@return boolean 是否成功
---@return string|nil 错误信息
function BaseCompanion:SetActiveCompanion(slotIndex)
    -- 取消激活
    if slotIndex == 0 then
        -- 将之前的激活伙伴设为非激活状态
        if self.activeCompanionSlot ~= 0 then
            local oldActiveCompanion = self.companionInstances[self.activeCompanionSlot]
            if oldActiveCompanion then
                oldActiveCompanion:SetActive(false)
            end
        end
        self.activeCompanionSlot = 0
        gg.log("取消激活伙伴", self.uin, self.companionType)
        return true, nil
    end
    
    -- 检查槽位是否有效
    if slotIndex < 1 or slotIndex > self.maxSlots then
        return false, "无效的槽位索引"
    end
    
    -- 检查伙伴是否存在
    local newActiveCompanion = self.companionInstances[slotIndex]
    if not newActiveCompanion then
        return false, "槽位为空"
    end
    
    -- 取消之前的激活伙伴
    if self.activeCompanionSlot ~= 0 then
        local oldActiveCompanion = self.companionInstances[self.activeCompanionSlot]
        if oldActiveCompanion then
            oldActiveCompanion:SetActive(false)
        end
    end
    
    -- 设置新的激活伙伴
    self.activeCompanionSlot = slotIndex
    newActiveCompanion:SetActive(true)
    
    gg.log("设置激活伙伴", self.uin, self.companionType, newActiveCompanion:GetConfigName(), "槽位", slotIndex)
    return true, nil
end

---伙伴升级
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级，nil表示升1级
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否真的升级了
function BaseCompanion:LevelUpCompanion(slotIndex, targetLevel)
    local companionInstance = self.companionInstances[slotIndex]
    if not companionInstance then
        return false, "伙伴不存在", false
    end
    
    if targetLevel then
        -- 直接设置到目标等级
        local success = companionInstance:SetLevel(targetLevel)
        return success, success and nil or "设置等级失败", success
    else
        -- 升1级
        if companionInstance:CanLevelUp() then
            companionInstance:DoLevelUp()
            return true, nil, true
        else
            return true, nil, false -- 成功但没升级
        end
    end
end

---伙伴获得经验
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否升级了
function BaseCompanion:AddCompanionExp(slotIndex, expAmount)
    local companionInstance = self.companionInstances[slotIndex]
    if not companionInstance then
        return false, "伙伴不存在", false
    end
    
    local leveledUp = companionInstance:AddExp(expAmount)
    return true, nil, leveledUp
end

---查找符合条件的伙伴
---@param companionName string 伙伴名称
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位
---@return table<number> 符合条件的槽位列表
function BaseCompanion:FindCompanionsByCondition(companionName, requiredStar, excludeSlot)
    local candidates = {}
    
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        if slotIndex ~= excludeSlot and
           companionInstance:GetConfigName() == companionName and
           companionInstance:GetStarLevel() >= requiredStar then
            table.insert(candidates, slotIndex)
        end
    end
    
    return candidates
end

---消耗指定伙伴
---@param companionName string 伙伴名称
---@param count number 需要数量
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位（如正在升星的伙伴）
---@return boolean 是否成功消耗
function BaseCompanion:ConsumeCompanions(companionName, count, requiredStar, excludeSlot)
    -- 找到符合条件的伙伴
    local candidates = self:FindCompanionsByCondition(companionName, requiredStar, excludeSlot)
    
    if #candidates < count then
        gg.log("伙伴材料不足", self.uin, self.companionType, companionName, "需要", count, "找到", #candidates)
        return false
    end
    
    -- 消耗伙伴（删除实例）
    for i = 1, count do
        local slotToRemove = candidates[i]
        self:RemoveCompanion(slotToRemove)
        gg.log("消耗伙伴", self.uin, self.companionType, companionName, "槽位", slotToRemove)
    end
    
    return true
end

---伙伴升星
---@param slotIndex number 要升星的伙伴槽位
---@return boolean 是否成功
---@return string|nil 错误信息
function BaseCompanion:UpgradeCompanionStar(slotIndex)
    local companionInstance = self.companionInstances[slotIndex]
    if not companionInstance then
        return false, "伙伴不存在"
    end
    
    local companionTypeConfig = companionInstance.companionTypeConfig
    if not companionTypeConfig then
        return false, "伙伴配置不存在"
    end
    
    local currentStar = companionInstance:GetStarLevel()
    local upgradeCost = companionTypeConfig:GetStarUpgradeCost(currentStar + 1)
    if not upgradeCost then
        return false, "已达到最大星级或缺少升星配置"
    end
    
    -- 检查并消耗材料
    for _, material in ipairs(upgradeCost["消耗材料"] or {}) do
        if material["消耗类型"] == "宠物" or material["消耗类型"] == "伙伴" then
            local companionName = material["消耗宠物"] or material["消耗伙伴"]
            local needCount = material["需要数量"] or 1
            local needStar = material["宠物星级"] or material["伙伴星级"] or 1
            
            -- 检查材料是否充足（排除当前升星的伙伴）
            local candidates = self:FindCompanionsByCondition(companionName, needStar, slotIndex)
            if #candidates < needCount then
                return false, string.format("伙伴材料不足：需要%d个%d星%s", needCount, needStar, companionName)
            end
            
            -- 消耗材料
            local success = self:ConsumeCompanions(companionName, needCount, needStar, slotIndex)
            if not success then
                return false, "消耗伙伴材料失败"
            end
        elseif material["消耗类型"] == "物品" then
            -- TODO: 实现物品消耗逻辑
            gg.log("升星需要物品材料", material["材料物品"], material["需要数量"])
        end
    end
    
    -- 执行升星
    local success, errorMsg = companionInstance:DoUpgradeStar()
    if success then
        gg.log("伙伴升星成功", self.uin, self.companionType, companionInstance:GetConfigName(), "新星级", companionInstance:GetStarLevel())
    end
    
    return success, errorMsg
end

---伙伴学习技能
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function BaseCompanion:LearnCompanionSkill(slotIndex, skillId)
    local companionInstance = self.companionInstances[slotIndex]
    if not companionInstance then
        return false, "伙伴不存在"
    end
    
    return companionInstance:LearnSkill(skillId)
end

---获取伙伴的最终属性
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function BaseCompanion:GetCompanionFinalAttribute(slotIndex, attrName)
    local companionInstance = self.companionInstances[slotIndex]
    if not companionInstance then
        return nil
    end
    
    return companionInstance:GetFinalAttribute(attrName)
end

---检查伙伴是否可以升级
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function BaseCompanion:CanCompanionLevelUp(slotIndex)
    local companionInstance = self.companionInstances[slotIndex]
    if not companionInstance then
        return false
    end
    
    return companionInstance:CanLevelUp()
end

---检查伙伴是否可以升星
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function BaseCompanion:CanCompanionUpgradeStar(slotIndex)
    local companionInstance = self.companionInstances[slotIndex]
    if not companionInstance then
        return false, "伙伴不存在"
    end
    
    local companionTypeConfig = companionInstance.companionTypeConfig
    if not companionTypeConfig then
        return false, "伙伴配置不存在"
    end
    
    local currentStar = companionInstance:GetStarLevel()
    local upgradeCost = companionTypeConfig:GetStarUpgradeCost(currentStar + 1)
    if not upgradeCost then
        return false, "已达到最大星级"
    end
    
    -- 检查材料是否充足
    for _, material in ipairs(upgradeCost["消耗材料"] or {}) do
        if material["消耗类型"] == "宠物" or material["消耗类型"] == "伙伴" then
            local companionName = material["消耗宠物"] or material["消耗伙伴"]
            local needCount = material["需要数量"] or 1
            local needStar = material["宠物星级"] or material["伙伴星级"] or 1
            
            local candidates = self:FindCompanionsByCondition(companionName, needStar, slotIndex)
            if #candidates < needCount then
                return false, string.format("伙伴材料不足：需要%d个%d星%s", needCount, needStar, companionName)
            end
        end
    end
    
    return true, nil
end

---更新所有伙伴的临时buff
function BaseCompanion:UpdateAllCompanionBuffs()
    for _, companionInstance in pairs(self.companionInstances) do
        companionInstance:UpdateTempBuffs()
    end
end

---获取指定类型的伙伴数量
---@param companionName string 伙伴名称
---@param minStar number|nil 最小星级要求
---@return number 伙伴数量
function BaseCompanion:GetCompanionCountByType(companionName, minStar)
    local count = 0
    minStar = minStar or 1
    
    for _, companionInstance in pairs(self.companionInstances) do
        if companionInstance:GetConfigName() == companionName and 
           companionInstance:GetStarLevel() >= minStar then
            count = count + 1
        end
    end
    
    return count
end

---批量操作：一键升级所有可升级伙伴
---@return number 升级的伙伴数量
function BaseCompanion:UpgradeAllPossibleCompanions()
    local upgradedCount = 0
    
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        while companionInstance:CanLevelUp() do
            companionInstance:DoLevelUp()
            upgradedCount = upgradedCount + 1
        end
    end
    
    if upgradedCount > 0 then
        gg.log("批量升级伙伴", self.uin, self.companionType, "升级次数", upgradedCount)
    end
    
    return upgradedCount
end

return BaseCompanion