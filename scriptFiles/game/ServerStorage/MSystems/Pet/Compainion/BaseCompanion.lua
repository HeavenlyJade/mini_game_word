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
---@field activeCompanionSlots table<string, number> 激活的伙伴槽位映射 {[装备栏ID] = 背包槽位ID}
---@field equipSlotIds table<string> 所有可用的装备栏ID
---@field unlockedEquipSlots number 玩家当前已解锁的装备栏数量
---@field companionType string 伙伴类型（"宠物" 或 "伙伴"）
local BaseCompanion = ClassMgr.Class("BaseCompanion")

function BaseCompanion:OnInit(uin, companionType, equipSlotIds)
    self.uin = uin or 0
    self.companionInstances = {}
    self.activeCompanionSlots = {}
    self.equipSlotIds = equipSlotIds or {} -- 从子类传入配置的栏位ID
    self.unlockedEquipSlots = 1 -- 默认值，将在LoadData时被覆盖
    self.companionType = companionType or "未知"

    --gg.log("BaseCompanion基类初始化", uin, "类型", self.companionType, "可用装备栏", table.concat(self.equipSlotIds, ", "))
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

---【新增】删除伙伴
---@param slotIndex number 槽位索引
---@return boolean, string|nil
function BaseCompanion:DeleteCompanion(slotIndex)
    local companionInstance = self:GetCompanionBySlot(slotIndex)
    if not companionInstance then
        return false, "该槽位上没有伙伴"
    end

    if companionInstance:IsLocked() then
        return false, "伙伴已锁定，无法删除"
    end

    if companionInstance:IsActive() then
        return false, "伙伴正在装备中，无法删除"
    end

    self.companionInstances[slotIndex] = nil
    --gg.log("删除伙伴成功", self.uin, self.companionType, slotIndex)
    return true, nil
end

---【新增】切换伙伴锁定状态
---@param slotIndex number 槽位索引
---@return boolean, string|nil, boolean|nil
function BaseCompanion:ToggleCompanionLock(slotIndex)
    local companionInstance = self:GetCompanionBySlot(slotIndex)
    if not companionInstance then
        return false, "该槽位上没有伙伴", nil
    end

    local currentStatus = companionInstance:IsLocked()
    companionInstance:SetLocked(not currentStatus)

    return true, nil, not currentStatus
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
        --gg.log("警告：伙伴数据无效", self.companionType, slotIndex)
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

---【重构】获取所有激活的伙伴实例
---@return table<CompanionInstance> 激活的伙伴实例列表
function BaseCompanion:GetActiveCompanions()
    local activeCompanions = {}
    for equipSlotId, companionSlotId in pairs(self.activeCompanionSlots) do
        if companionSlotId and companionSlotId > 0 then
            local instance = self:GetCompanionBySlot(companionSlotId)
            if instance then
                table.insert(activeCompanions, instance)
            end
        end
    end
    return activeCompanions
end

---【新增】获取所有激活伙伴的物品加成
---@return table<string, table> 物品加成 {[物品目标] = {fixed = number, percentage = number}}
function BaseCompanion:GetActiveItemBonuses()
    local totalBonuses = {}
    local BonusManager = require(ServerStorage.BonusManager.BonusManager) -- 懒加载以避免循环依赖

    local activeCompanions = self:GetActiveCompanions()
    --gg.log(string.format("[BaseCompanion调试] GetActiveItemBonuses: 找到 %d 个激活的 %s", #activeCompanions, self.companionType))
    
    for _, companionInstance in ipairs(activeCompanions) do

        
        local singleBonus = companionInstance:GetItemBonuses()
        --gg.log(string.format("[BaseCompanion调试] %s 单个加成数据:", self.companionType), singleBonus)
        
        BonusManager.MergeBonuses(totalBonuses, singleBonus)
    end

    --gg.log(string.format("[BaseCompanion调试] GetActiveItemBonuses: 最终合并的 %s 加成数据:", self.companionType), totalBonuses)
    return totalBonuses
end


---获取所有伙伴信息
---@return table 伙伴列表信息
function BaseCompanion:GetCompanionList()
    local companionList = {}

    for slotIndex, companionInstance in pairs(self.companionInstances) do
        companionList[slotIndex] = companionInstance:GetFullInfo()
    end

    -- 【新增】计算当前玩家实际可用的装备栏
    local availableEquipSlots = {}
    for i = 1, self.unlockedEquipSlots do
        if self.equipSlotIds[i] then
            table.insert(availableEquipSlots, self.equipSlotIds[i])
        end
    end

    return {
        companionList = companionList,
        activeSlots = self.activeCompanionSlots, -- 【修改】返回新的激活数据结构
        equipSlotIds = availableEquipSlots, -- 【修改】只返回玩家当前可用的装备栏
        unlockedEquipSlots = self.unlockedEquipSlots, -- 【新增】返回已解锁栏位数
        maxEquipSlots = #self.equipSlotIds, -- 【新增】返回系统最大栏位数
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
        --gg.log("添加伙伴成功", self.uin, self.companionType, companionName, "槽位", slotIndex)
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

    -- 【重构】如果被移除的伙伴正在装备中，则将其从所有装备栏卸下
    for equipSlotId, equippedCompanionSlotId in pairs(self.activeCompanionSlots) do
        if equippedCompanionSlotId == slotIndex then
            self:UnequipCompanion(equipSlotId)
        end
    end

    -- 移除伙伴实例
    self.companionInstances[slotIndex] = nil

    --gg.log("移除伙伴成功", self.uin, self.companionType, companionInstance:GetConfigName(), "槽位", slotIndex)
    return true, nil
end

---【重构】装备伙伴到指定装备栏
---@param companionSlotId number 要装备的伙伴背包槽位ID
---@param equipSlotId string 目标装备栏ID (如 "Partner1")
---@return boolean 是否成功
---@return string|nil 错误信息
function BaseCompanion:EquipCompanion(companionSlotId, equipSlotId)
    -- 1. 验证装备栏ID是否在玩家当前可用的栏位中
    local isUnlockEquipSlot = false
    for i = 1, self.unlockedEquipSlots do
        if self.equipSlotIds[i] == equipSlotId then
            isUnlockEquipSlot = true
            break
        end
    end
    if not isUnlockEquipSlot then
        return false, "该装备栏尚未解锁: " .. tostring(equipSlotId)
    end

    -- 2. 验证要装备的伙伴是否存在
    local companionToEquip = self:GetCompanionBySlot(companionSlotId)
    if not companionToEquip then
        return false, "背包槽位 " .. tostring(companionSlotId) .. " 上没有伙伴"
    end

    -- 3. 如果该伙伴已装备在其他栏位，先从旧栏位卸下
    for oldEquipSlot, equippedCid in pairs(self.activeCompanionSlots) do
        if equippedCid == companionSlotId then
            self:UnequipCompanion(oldEquipSlot)
            break
        end
    end

    -- 4. 如果目标装备栏已有其他伙伴，先卸下旧的
    local oldCompanionSlotId = self.activeCompanionSlots[equipSlotId]
    if oldCompanionSlotId and oldCompanionSlotId > 0 then
        local oldCompanionInstance = self:GetCompanionBySlot(oldCompanionSlotId)
        if oldCompanionInstance then
            oldCompanionInstance:SetActive(false)
        end
    end

    -- 5. 执行装备
    self.activeCompanionSlots[equipSlotId] = companionSlotId
    companionToEquip:SetActive(true)

    --gg.log(string.format("装备伙伴成功: 玩家 %d, 类型 %s, 背包槽位 %d -> 装备栏 %s", self.uin, self.companionType, companionSlotId, equipSlotId))
    return true, nil
end

---【新增】从指定装备栏卸下伙伴
---@param equipSlotId string 目标装备栏ID
---@return boolean
function BaseCompanion:UnequipCompanion(equipSlotId)
    local companionSlotId = self.activeCompanionSlots[equipSlotId]

    if companionSlotId and companionSlotId > 0 then
        local companionInstance = self:GetCompanionBySlot(companionSlotId)
        if companionInstance then
            companionInstance:SetActive(false)
        end
        self.activeCompanionSlots[equipSlotId] = nil
        --gg.log(string.format("卸下伙伴成功: 玩家 %d, 类型 %s, 从装备栏 %s (原背包槽位 %d)", self.uin, self.companionType, equipSlotId, companionSlotId))
        return true
    end
    return false
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
           companionInstance:GetStarLevel() == requiredStar then
            table.insert(candidates, slotIndex)
        end
    end

    -- 由于现在只查找特定星级，不再需要按星级排序
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
        --gg.log("伙伴材料不足", self.uin, self.companionType, companionName, "需要", count, "找到", #candidates)
        return false
    end

    -- 消耗伙伴（删除实例）
    for i = 1, count do
        local slotToRemove = candidates[i]
        self:RemoveCompanion(slotToRemove)
        --gg.log("消耗伙伴", self.uin, self.companionType, companionName, "槽位", slotToRemove)
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
        if material["消耗类型"] == "宠物" or material["消耗类型"] == "伙伴" or material["消耗类型"] == "翅膀" then
            local companionName = material["消耗名称"]
            local needCount = material["需要数量"] or 1
            local needStar = material["消耗星级"] or 1

            -- 【修复】判断本体是否可以作为材料之一
            local actualNeedCount = needCount
            if companionInstance:GetConfigName() == companionName and companionInstance:GetStarLevel() >= needStar then
                actualNeedCount = needCount - 1
            end

            if actualNeedCount > 0 then
                -- 检查材料是否充足（排除当前升星的伙伴）
                local candidates = self:FindCompanionsByCondition(companionName, needStar, slotIndex)
                if #candidates < actualNeedCount then
                    return false, string.format("伙伴材料不足：需要%d个%d星%s", actualNeedCount, needStar, companionName)
                end

                -- 消耗材料
                local success = self:ConsumeCompanions(companionName, actualNeedCount, needStar, slotIndex)
                if not success then
                    return false, "消耗伙伴材料失败"
                end
            end
        elseif material["消耗类型"] == "物品" then
            -- TODO: 实现物品消耗逻辑
            --gg.log("升星需要物品材料", material["材料物品"], material["需要数量"])
        end
    end

    -- 执行升星
    local success, errorMsg = companionInstance:DoUpgradeStar()
    if success then
        --gg.log("伙伴升星成功", self.uin, self.companionType, companionInstance:GetConfigName(), "新星级", companionInstance:GetStarLevel())
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
            local companionName = material["消耗名称"]
            local needCount = material["需要数量"] or 1
            local needStar = material["消耗星级"] or 1

            -- 【修复】判断本体是否可以作为材料之一
            local actualNeedCount = needCount
            if companionInstance:GetConfigName() == companionName and companionInstance:GetStarLevel() >= needStar then
                actualNeedCount = needCount - 1
            end

            if actualNeedCount > 0 then
                local candidates = self:FindCompanionsByCondition(companionName, needStar, slotIndex)
                if #candidates < actualNeedCount then
                    return false, string.format("伙伴材料不足：需要%d个%d星%s", actualNeedCount, needStar, companionName)
                end
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
    local totalUpgradedCount = 0
    local hasUpgradedInLoop = true

    -- 持续循环，直到在一轮完整的遍历中没有任何伙伴可以升星
    while hasUpgradedInLoop do
        hasUpgradedInLoop = false

        -- 创建一个槽位索引的列表，以确保遍历顺序稳定
        local slotsToCheck = {}
        for slotIndex, _ in pairs(self.companionInstances) do
            table.insert(slotsToCheck, slotIndex)
        end
        table.sort(slotsToCheck)

        for _, slotIndex in ipairs(slotsToCheck) do
            -- 检查实例是否在循环中被消耗掉了
            local companionInstance = self.companionInstances[slotIndex]
            if companionInstance then
                local canUpgrade, reason = self:CanCompanionUpgradeStar(slotIndex)
                if canUpgrade then
                    local success, errorMsg = self:UpgradeCompanionStar(slotIndex)
                    if success then
                        totalUpgradedCount = totalUpgradedCount + 1
                        hasUpgradedInLoop = true -- 标记本轮有升星发生，需要再来一轮
                        --gg.log(string.format("一键升星: 玩家 %d 的 %s (槽位 %d) 升星成功", self.uin, self.companionType, slotIndex))
                        -- 因为升星消耗了其他伙伴，所以从外层循环重新开始检查是更安全的做法
                        break
                    else
                        --gg.log(string.format("一键升星: 尝试为 %s (槽位 %d) 升星失败: %s", self.companionType, slotIndex, errorMsg or "未知错误"))
                    end
                end
            end
        end
    end

    if totalUpgradedCount > 0 then
        --gg.log(string.format("一键升星完成: 玩家 %d 的 %s 总共升星 %d 次", self.uin, self.companionType, totalUpgradedCount))
    else
        --gg.log(string.format("一键升星: 玩家 %d 的 %s 没有可升星的伙伴", self.uin, self.companionType))
    end

    return totalUpgradedCount
end

return BaseCompanion
