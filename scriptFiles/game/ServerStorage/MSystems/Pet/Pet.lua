-- Pet.lua
-- 玩家宠物管理器
-- 负责管理单个玩家的所有宠物数据和业务逻辑

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
local PetInstance = require(ServerStorage.MSystems.Pet.PetInstance) ---@type PetInstance

---@class Pet:Class 玩家宠物管理器
---@field uin number 玩家ID
---@field petInstances table<number, PetInstance> 宠物实例列表 {slotIndex = PetInstance}
---@field activePetSlot number 当前激活的宠物槽位 (0表示无激活)
---@field maxSlots number 最大槽位数
local Pet = ClassMgr.Class("Pet")

function Pet:OnInit(uin, playerPetData)
    self.uin = uin or 0
    self.petInstances = {}
    self.activePetSlot = 0
    self.maxSlots = 50
    
    -- 从玩家宠物数据初始化
    if playerPetData then
        self:LoadFromData(playerPetData)
    end
    
    gg.log("Pet管理器创建", uin, "宠物数量", self:GetPetCount())
end

---从数据加载宠物实例
---@param playerPetData PlayerPetData 玩家宠物数据
function Pet:LoadFromData(playerPetData)
    -- 设置激活槽位
    self.activePetSlot = playerPetData.activePetSlot or 0
    self.maxSlots = playerPetData.petSlots or 50
    
    -- 创建宠物实例
    for slotIndex, petData in pairs(playerPetData.petList or {}) do
        local petInstance = self:CreatePetInstance(petData, slotIndex)
        if petInstance then
            self.petInstances[slotIndex] = petInstance
        end
    end
    
    gg.log("从数据加载宠物", self.uin, "槽位数", self.maxSlots, "宠物数", self:GetPetCount())
end

---创建宠物实例
---@param petData PetData 宠物数据
---@param slotIndex number 槽位索引
---@return PetInstance|nil 宠物实例
function Pet:CreatePetInstance(petData, slotIndex)
    if not petData or not petData.petName then
        gg.log("警告：宠物数据无效", slotIndex)
        return nil
    end
    
    -- 获取宠物配置
    local petType = ConfigLoader.GetPet(petData.petName)
    if not petType then
        gg.log("警告：宠物配置不存在", petData.petName)
        return nil
    end
    
    return PetInstance.New(petData, petType, slotIndex)
end

---获取保存数据
---@return PlayerPetData 玩家宠物数据
function Pet:GetSaveData()
    local playerPetData = {
        activePetSlot = self.activePetSlot,
        petList = {},
        petSlots = self.maxSlots
    }
    
    -- 提取所有宠物的数据
    for slotIndex, petInstance in pairs(self.petInstances) do
        playerPetData.petList[slotIndex] = petInstance.petData
    end
    
    return playerPetData
end

---获取宠物数量
---@return number 宠物数量
function Pet:GetPetCount()
    local count = 0
    for _ in pairs(self.petInstances) do
        count = count + 1
    end
    return count
end

---获取指定槽位的宠物实例
---@param slotIndex number 槽位索引
---@return PetInstance|nil 宠物实例
function Pet:GetPetBySlot(slotIndex)
    return self.petInstances[slotIndex]
end

---获取激活的宠物实例
---@return PetInstance|nil 激活的宠物实例
---@return number|nil 槽位索引
function Pet:GetActivePet()
    if self.activePetSlot == 0 then
        return nil, nil
    end
    
    local petInstance = self.petInstances[self.activePetSlot]
    return petInstance, self.activePetSlot
end

---获取所有宠物信息
---@return table 宠物列表信息
function Pet:GetPlayerPetList()
    local petList = {}
    local activePetId = ""
    
    for slotIndex, petInstance in pairs(self.petInstances) do
        petList[slotIndex] = petInstance:GetFullInfo()
        if slotIndex == self.activePetSlot then
            activePetId = petInstance:GetConfigName()
        end
    end
    
    return {
        petList = petList,
        activePetId = activePetId,
        petSlots = self.maxSlots
    }
end

---查找空闲槽位
---@return number|nil 空闲槽位索引
function Pet:FindEmptySlot()
    for i = 1, self.maxSlots do
        if not self.petInstances[i] then
            return i
        end
    end
    return nil
end

---添加宠物到指定槽位
---@param petName string 宠物配置名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function Pet:AddPet(petName, slotIndex)
    -- 检查宠物配置是否存在
    local petType = ConfigLoader.GetPet(petName)
    if not petType then
        return false, "宠物配置不存在", nil
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
    if self.petInstances[slotIndex] then
        return false, "槽位已被占用", nil
    end
    
    -- 创建新的宠物数据
    local newPetData = {
        petName = petName,
        customName = "",
        level = petType.minLevel,
        exp = 0,
        starLevel = 1,
        learnedSkills = {},
        equipments = {},
        isActive = false,
        mood = 100
    }
    
    -- 创建宠物实例并添加到槽位
    local petInstance = self:CreatePetInstance(newPetData, slotIndex)
    if petInstance then
        self.petInstances[slotIndex] = petInstance
        gg.log("添加宠物成功", self.uin, petName, "槽位", slotIndex)
        return true, nil, slotIndex
    else
        return false, "创建宠物实例失败", nil
    end
end

---移除指定槽位的宠物
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:RemovePet(slotIndex)
    local petInstance = self.petInstances[slotIndex]
    if not petInstance then
        return false, "槽位为空"
    end
    
    -- 如果是激活宠物，取消激活
    if self.activePetSlot == slotIndex then
        self.activePetSlot = 0
    end
    
    -- 移除宠物实例
    self.petInstances[slotIndex] = nil
    
    gg.log("移除宠物成功", self.uin, petInstance:GetConfigName(), "槽位", slotIndex)
    return true, nil
end

---设置激活宠物
---@param slotIndex number 槽位索引（0表示取消激活）
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:SetActivePet(slotIndex)
    -- 取消激活
    if slotIndex == 0 then
        -- 将之前的激活宠物设为非激活状态
        if self.activePetSlot ~= 0 then
            local oldActivePet = self.petInstances[self.activePetSlot]
            if oldActivePet then
                oldActivePet:SetActive(false)
            end
        end
        self.activePetSlot = 0
        gg.log("取消激活宠物", self.uin)
        return true, nil
    end
    
    -- 检查槽位是否有效
    if slotIndex < 1 or slotIndex > self.maxSlots then
        return false, "无效的槽位索引"
    end
    
    -- 检查宠物是否存在
    local newActivePet = self.petInstances[slotIndex]
    if not newActivePet then
        return false, "槽位为空"
    end
    
    -- 取消之前的激活宠物
    if self.activePetSlot ~= 0 then
        local oldActivePet = self.petInstances[self.activePetSlot]
        if oldActivePet then
            oldActivePet:SetActive(false)
        end
    end
    
    -- 设置新的激活宠物
    self.activePetSlot = slotIndex
    newActivePet:SetActive(true)
    
    gg.log("设置激活宠物", self.uin, newActivePet:GetConfigName(), "槽位", slotIndex)
    return true, nil
end

---宠物升级
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级，nil表示升1级
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否真的升级了
function Pet:LevelUpPet(slotIndex, targetLevel)
    local petInstance = self.petInstances[slotIndex]
    if not petInstance then
        return false, "宠物不存在", false
    end
    
    if targetLevel then
        -- 直接设置到目标等级
        local success = petInstance:SetLevel(targetLevel)
        return success, success and nil or "设置等级失败", success
    else
        -- 升1级
        if petInstance:CanLevelUp() then
            petInstance:DoLevelUp()
            return true, nil, true
        else
            return true, nil, false -- 成功但没升级
        end
    end
end

---宠物获得经验
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否升级了
function Pet:AddPetExp(slotIndex, expAmount)
    local petInstance = self.petInstances[slotIndex]
    if not petInstance then
        return false, "宠物不存在", false
    end
    
    local leveledUp = petInstance:AddExp(expAmount)
    return true, nil, leveledUp
end

---查找符合条件的宠物
---@param petName string 宠物名称
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位
---@return table<number> 符合条件的槽位列表
function Pet:FindPetsByCondition(petName, requiredStar, excludeSlot)
    local candidates = {}
    
    for slotIndex, petInstance in pairs(self.petInstances) do
        if slotIndex ~= excludeSlot and
           petInstance:GetConfigName() == petName and
           petInstance:GetStarLevel() >= requiredStar then
            table.insert(candidates, slotIndex)
        end
    end
    
    return candidates
end

---消耗指定宠物
---@param petName string 宠物名称
---@param count number 需要数量
---@param requiredStar number 要求星级
---@param excludeSlot number|nil 排除的槽位（如正在升星的宠物）
---@return boolean 是否成功消耗
function Pet:ConsumePets(petName, count, requiredStar, excludeSlot)
    -- 找到符合条件的宠物
    local candidates = self:FindPetsByCondition(petName, requiredStar, excludeSlot)
    
    if #candidates < count then
        gg.log("宠物材料不足", self.uin, petName, "需要", count, "找到", #candidates)
        return false
    end
    
    -- 消耗宠物（删除实例）
    for i = 1, count do
        local slotToRemove = candidates[i]
        self:RemovePet(slotToRemove)
        gg.log("消耗宠物", self.uin, petName, "槽位", slotToRemove)
    end
    
    return true
end

---宠物升星
---@param slotIndex number 要升星的宠物槽位
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:UpgradePetStar(slotIndex)
    local petInstance = self.petInstances[slotIndex]
    if not petInstance then
        return false, "宠物不存在"
    end
    
    local petType = petInstance.petType
    if not petType then
        return false, "宠物配置不存在"
    end
    
    local currentStar = petInstance:GetStarLevel()
    local upgradeCost = petType:GetStarUpgradeCost(currentStar + 1)
    if not upgradeCost then
        return false, "已达到最大星级或缺少升星配置"
    end
    
    -- 检查并消耗材料
    for _, material in ipairs(upgradeCost["消耗材料"] or {}) do
        if material["消耗类型"] == "宠物" then
            local petName = material["消耗宠物"]
            local needCount = material["需要数量"] or 1
            local needStar = material["宠物星级"] or 1
            
            -- 检查材料是否充足（排除当前升星的宠物）
            local candidates = self:FindPetsByCondition(petName, needStar, slotIndex)
            if #candidates < needCount then
                return false, string.format("宠物材料不足：需要%d个%d星%s", needCount, needStar, petName)
            end
            
            -- 消耗材料
            local success = self:ConsumePets(petName, needCount, needStar, slotIndex)
            if not success then
                return false, "消耗宠物材料失败"
            end
        elseif material["消耗类型"] == "物品" then
            -- TODO: 实现物品消耗逻辑
            gg.log("升星需要物品材料", material["材料物品"], material["需要数量"])
        end
    end
    
    -- 执行升星
    local success, errorMsg = petInstance:DoUpgradeStar()
    if success then
        gg.log("宠物升星成功", self.uin, petInstance:GetConfigName(), "新星级", petInstance:GetStarLevel())
    end
    
    return success, errorMsg
end

---宠物学习技能
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:LearnPetSkill(slotIndex, skillId)
    local petInstance = self.petInstances[slotIndex]
    if not petInstance then
        return false, "宠物不存在"
    end
    
    return petInstance:LearnSkill(skillId)
end

---获取宠物的最终属性
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function Pet:GetPetFinalAttribute(slotIndex, attrName)
    local petInstance = self.petInstances[slotIndex]
    if not petInstance then
        return nil
    end
    
    return petInstance:GetFinalAttribute(attrName)
end

---检查宠物是否可以升级
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function Pet:CanPetLevelUp(slotIndex)
    local petInstance = self.petInstances[slotIndex]
    if not petInstance then
        return false
    end
    
    return petInstance:CanLevelUp()
end

---检查宠物是否可以升星
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function Pet:CanPetUpgradeStar(slotIndex)
    local petInstance = self.petInstances[slotIndex]
    if not petInstance then
        return false, "宠物不存在"
    end
    
    local petType = petInstance.petType
    if not petType then
        return false, "宠物配置不存在"
    end
    
    local currentStar = petInstance:GetStarLevel()
    local upgradeCost = petType:GetStarUpgradeCost(currentStar + 1)
    if not upgradeCost then
        return false, "已达到最大星级"
    end
    
    -- 检查材料是否充足
    for _, material in ipairs(upgradeCost["消耗材料"] or {}) do
        if material["消耗类型"] == "宠物" then
            local petName = material["消耗宠物"]
            local needCount = material["需要数量"] or 1
            local needStar = material["宠物星级"] or 1
            
            local candidates = self:FindPetsByCondition(petName, needStar, slotIndex)
            if #candidates < needCount then
                return false, string.format("宠物材料不足：需要%d个%d星%s", needCount, needStar, petName)
            end
        end
    end
    
    return true, nil
end

---更新所有宠物的临时buff
function Pet:UpdateAllPetBuffs()
    for _, petInstance in pairs(self.petInstances) do
        petInstance:UpdateTempBuffs()
    end
end

---获取指定类型的宠物数量
---@param petName string 宠物名称
---@param minStar number|nil 最小星级要求
---@return number 宠物数量
function Pet:GetPetCountByType(petName, minStar)
    local count = 0
    minStar = minStar or 1
    
    for _, petInstance in pairs(self.petInstances) do
        if petInstance:GetConfigName() == petName and 
           petInstance:GetStarLevel() >= minStar then
            count = count + 1
        end
    end
    
    return count
end

---批量操作：一键升级所有可升级宠物
---@return number 升级的宠物数量
function Pet:UpgradeAllPossiblePets()
    local upgradedCount = 0
    
    for slotIndex, petInstance in pairs(self.petInstances) do
        while petInstance:CanLevelUp() do
            petInstance:DoLevelUp()
            upgradedCount = upgradedCount + 1
        end
    end
    
    if upgradedCount > 0 then
        gg.log("批量升级宠物", self.uin, "升级次数", upgradedCount)
    end
    
    return upgradedCount
end

return Pet