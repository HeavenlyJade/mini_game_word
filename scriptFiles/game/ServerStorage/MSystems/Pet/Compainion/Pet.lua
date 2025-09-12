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
local PetEventConfig = require(MainStorage.Code.Event.EventPet) ---@type PetEventConfig

---@class Pet:BaseCompanion 宠物管理器
local Pet = ClassMgr.Class("Pet", BaseCompanion)

function Pet:OnInit(uin, playerPetData)
    -- 【重构】从配置加载装备栏，并调用父类初始化
    local equipSlotIds = PetEventConfig.EQUIP_CONFIG.PET_SLOTS
    BaseCompanion.OnInit(self, uin, "宠物", equipSlotIds)

    self:LoadFromPetData(playerPetData)
    --gg.log("Pet管理器创建", uin, "宠物数量", self:GetCompanionCount())
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
        mood = 100,
        isLocked = false -- 【新增】
    }
end

---获取保存数据
---@return PlayerPetData 宠物保存数据
function Pet:GetSaveData()
    local playerPetData = {
        activeSlots = self.activeCompanionSlots, -- 【修改】保存新的激活数据结构
        petList = {},
        petSlots = self.maxSlots, -- 保留背包容量字段，以备将来使用
        unlockedEquipSlots = self.unlockedEquipSlots -- 【新增】保存已解锁栏位数
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
    if not playerPetData then return end

    -- 【重构】加载新的激活数据结构
    self.activeCompanionSlots = playerPetData.activeSlots or {}
    self.maxSlots = playerPetData.petSlots or 50 -- 兼容旧数据

    -- 【新增】加载已解锁的装备栏数量，确保不超过系统配置的最大值
    local maxEquipped = #self.equipSlotIds
    self.unlockedEquipSlots = math.min(playerPetData.unlockedEquipSlots or 1, maxEquipped)

    -- 创建宠物实例
    for slotIndex, petData in pairs(playerPetData.petList or {}) do
        local companionInstance = self:CreateCompanionInstance(petData, slotIndex)
        if companionInstance then
            self.companionInstances[slotIndex] = companionInstance
        end
    end

    --gg.log("从宠物数据加载", self.uin, "激活槽位数量", #(self.activeCompanionSlots or {}), "宠物数", self:GetCompanionCount())
end

---获取宠物列表信息（兼容原接口）
---@return table 宠物列表信息
function Pet:GetPlayerPetList()
    return self:GetCompanionList()
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

---【移除】该方法已被基类中的GetActiveCompanions替代
-- function Pet:GetActivePet() ... end

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

---【新增】删除宠物（兼容接口）
---@param slotIndex number
---@return boolean, string|nil
function Pet:DeletePet(slotIndex)
    return self:DeleteCompanion(slotIndex)
end

---【新增】切换宠物锁定状态（兼容接口）
---@param slotIndex number
---@return boolean, string|nil, boolean|nil
function Pet:TogglePetLock(slotIndex)
    return self:ToggleCompanionLock(slotIndex)
end

--【重构】设置激活宠物接口 -> 装备/卸下（已在文件后部重写，此处旧实现移除）

---@param equipSlotId string 目标装备栏ID
---@return boolean
function Pet:UnequipPet(equipSlotId)
    return self:UnequipCompanion(equipSlotId)
end

---【废弃】旧的单一激活接口
function Pet:SetActivePet(slotIndex)
    --gg.log("警告: SetActivePet 是一个废弃的接口，请使用 EquipPet 或 UnequipPet。")
    return false, "接口已废弃"
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

---直接设置宠物星级（不消耗材料）
---@param slotIndex number 槽位索引
---@param targetStarLevel number 目标星级
---@return boolean 是否成功
---@return string|nil 错误信息
function Pet:SetPetStarLevel(slotIndex, targetStarLevel)
    return self:SetCompanionStarLevel(slotIndex, targetStarLevel)
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


--- 【新增】计算背包所有宠物加成并排序获取最强
---@return table|nil 最强宠物信息 {petName: string, starLevel: number, slotIndex: number, totalBonus: number, detailedBonuses: table}
function Pet:CalculateAllPetBonusesAndGetStrongest()
    local petBonusList = {}
    local ConfigLoader = require(game:GetService('MainStorage').Code.Common.ConfigLoader)
    
    gg.log("开始计算背包所有宠物的加成数据...")
    
    -- 遍历所有宠物
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        if companionInstance and companionInstance.companionData then
            local petData = companionInstance.companionData
            local petName = petData.petName
            local starLevel = petData.starLevel or 1
            
            -- 获取宠物配置
            local petConfig = ConfigLoader.GetPet(petName) ---@type PetType
            if petConfig then
                -- 排除最强加成类型的宠物
                if petConfig.specialBonus == "最强加成" then
                    gg.log(string.format("跳过最强加成宠物: %s", petName))
                else
                    -- 计算该宠物的详细加成
                    local detailedBonuses = self:CalculatePetDetailedBonuses(petConfig, starLevel)
                    local totalBonus = self:SumAllBonuses(detailedBonuses)
                    
                    table.insert(petBonusList, {
                        petName = petName,
                        starLevel = starLevel,
                        slotIndex = slotIndex,
                        totalBonus = totalBonus,
                        detailedBonuses = detailedBonuses,
                        companionInstance = companionInstance
                    })
                    
                    gg.log(string.format("宠物: %s (%d星) -> 总加成: %.2f", petName, starLevel, totalBonus))
                end
            end
        end
    end
    
    -- 按总加成降序排序
    table.sort(petBonusList, function(a, b)
        return a.totalBonus > b.totalBonus
    end)
    
    -- 返回最强的宠物
    if #petBonusList > 0 then
        local strongest = petBonusList[1]
        gg.log(string.format("最强宠物: %s (%d星, 总加成: %.2f)", strongest.petName, strongest.starLevel, strongest.totalBonus))
        return strongest
    else
        gg.log("背包中没有有效的宠物")
        return nil
    end
end

--- 【新增】计算单个宠物的详细加成
---@param petConfig PetType 宠物配置
---@param starLevel number 星级
---@return table 详细加成数据
function Pet:CalculatePetDetailedBonuses(petConfig, starLevel)
    local detailedBonuses = {}
    
    -- 获取公式计算器
    local RewardManager = require(game.MainStorage.Code.GameReward.RewardManager)
    local calculator = RewardManager.GetCalculator("宠物公式")
    if not calculator then
        gg.log("错误: 无法获取宠物公式计算器")
        return detailedBonuses
    end
    
    -- 遍历宠物的携带效果
    for _, effect in ipairs(petConfig.carryingEffects) do
        local variableName = effect["变量名称"] or ""
        local effectValue = effect["效果数值"] or ""
        local bonusType = effect["加成类型"]
        local itemTarget = effect["物品目标"]
        local targetVariable = effect["目标变量"]
        local actionType = effect["作用类型"]
        
        if variableName ~= "" and effectValue ~= "" then
            -- 计算效果数值
            local calculatedValue = calculator:CalculateEffectValue(effectValue, starLevel, 1, petConfig)
            
            if calculatedValue then
                detailedBonuses[variableName] = {
                    value = calculatedValue,
                    bonusType = bonusType,
                    itemTarget = itemTarget,
                    targetVariable = targetVariable,
                    actionType = actionType,
                    isPercentage = (actionType == "百分比加成")
                }
            end
        end
    end
    
    return detailedBonuses
end

--- 【新增】汇总所有加成的总数值
---@param detailedBonuses table 详细加成数据
---@return number 总加成数值
function Pet:SumAllBonuses(detailedBonuses)
    local totalBonus = 0
    
    for variableName, bonusData in pairs(detailedBonuses) do
        local value = bonusData.value or 0
        -- 简单累加所有数值（可根据需要调整权重）
        totalBonus = totalBonus + value
    end
    
    return totalBonus
end

--- 【新增】验证最强加成宠物是否适合装备到指定栏位
---@param companionSlotId number 要装备的宠物槽位
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil, number|nil 是否适合装备、原因、排名位置
function Pet:ValidateStrongestBonusPetEquip(companionSlotId, equipSlotId)
    local companionInstance = self.companionInstances[companionSlotId]
    if not companionInstance then
        return false, "宠物不存在", nil
    end
    
    local petName = companionInstance:GetConfigName()
    local ConfigLoader = require(game:GetService('MainStorage').Code.Common.ConfigLoader)
    local petConfig = ConfigLoader.GetPet(petName)
    
    -- 检查是否为最强加成宠物
    if not (petConfig and petConfig.specialBonus == "最强加成") then
        return true, nil, nil -- 普通宠物，直接通过
    end
    
    local starLevel = companionInstance:GetStarLevel()
    gg.log(string.format("[最强加成-验证] 宠物=%s 槽位=%d 目标装备栏=%s 星级=%d", petName, companionSlotId, equipSlotId, starLevel))
    -- gg.log(string.format("[最强加成-验证] specialBonus=%s specialEffectConfig=%s", tostring(petConfig and petConfig.specialBonus), tostring(petConfig and petConfig.specialEffectConfig)))
    
    -- 计算该宠物作为最强加成后的效果值
    local strongestBonusValue = self:CalculateStrongestBonusValue(companionInstance, petConfig)
    if not strongestBonusValue then
        gg.log("[最强加成-验证] 无法计算最强加成效果 strongestBonusValue=nil")
        return false, "无法计算最强加成效果", nil
    end
    gg.log(string.format("[最强加成-验证] 计算得到的最强加成效果值=%.4f", strongestBonusValue))
    
    -- 获取当前装备栏位的排名要求
    -- local requiredRanking = self:GetEquipSlotRankingRequirement(equipSlotId)
    -- if not requiredRanking then
    --     gg.log("[最强加成-验证] 该装备栏无排名要求，直接允许装备")
    --     return true, nil, nil -- 没有排名要求，直接通过
    -- end
    -- gg.log(string.format("[最强加成-验证] 装备栏位%s 的排名要求=前%d名", equipSlotId, requiredRanking))
    
    -- 获取所有宠物的排名（包括计算后的最强加成宠物）
    local allPetRanking = self:GetAllPetEffectRankingWithStrongestBonus()
    
    -- 查找该宠物在排名中的位置
    local petRanking = nil
    for rank, petData in ipairs(allPetRanking) do
        if petData.slotIndex == companionSlotId then
            petRanking = rank
            break
        end
    end
    
end

--- 【新增】计算最强加成宠物的效果值
---@param companionInstance CompanionInstance 最强加成宠物实例
---@param petConfig PetType 宠物配置
---@return number|nil 计算后的效果值
function Pet:CalculateStrongestBonusValue(companionInstance, petConfig)
    local starLevel = companionInstance:GetStarLevel()
    
    -- 1. 获取背包最强宠物
    local strongestPet = self:CalculateAllPetBonusesAndGetStrongest()
    if not strongestPet then
        gg.log("[最强加成-计算] 没有找到背包最强宠物")
        return nil
    end
    
    -- 2. 获取倍率
    local bonusMultiplier = petConfig:GetSpecialBonusMultiplier(starLevel)
    gg.log(string.format("[最强加成-计算] 宠物=%s 星级=%d specialEffectConfig=%s", petConfig.name or "", starLevel, tostring(petConfig.specialEffectConfig)))
    if petConfig.effectLevelType then
        local rawValue = petConfig.effectLevelType:GetEffectValue(starLevel)
        local rawDesc = petConfig.effectLevelType.GetEffectDesc and petConfig.effectLevelType:GetEffectDesc(starLevel) or nil
        gg.log(string.format("[最强加成-计算] 从效果等级配置获取: 效果值=%.4f 描述=%s", tonumber(rawValue or 0), tostring(rawDesc)))
    else
        gg.log("[最强加成-计算] effectLevelType 未加载，无法从配置读取倍率")
    end
    if not bonusMultiplier then
        gg.log(string.format("[最强加成-计算] 无法获取星级%d的倍率 (specialBonus=%s)", starLevel, tostring(petConfig.specialBonus)))
        return nil
    end
    
    -- 3. 计算最强加成后的效果值
    local strongestBonusValue = strongestPet.totalBonus * bonusMultiplier
    
    gg.log(string.format("[最强加成-计算] strongest.totalBonus=%.4f bonusMultiplier=%.4f 结果=%.4f", 
        strongestPet.totalBonus, bonusMultiplier, strongestBonusValue))
    
    return strongestBonusValue
end

--- 【新增】获取装备栏位的排名要求
---@param equipSlotId string 装备栏ID
---@return number|nil 要求的排名（前N强），nil表示无要求
function Pet:GetEquipSlotRankingRequirement(equipSlotId)
    -- 根据装备栏位ID确定排名要求
    local rankingRequirements = {
        ["Pet1"] = 1,    -- 第1栏位只能装备最强的
        ["Pet2"] = 2,    -- 第2栏位可以装备前2强
        ["Pet3"] = 3,    -- 第3栏位可以装备前3强
        ["Pet4"] = 4,    -- 第4栏位可以装备前4强
        ["Pet5"] = 5,    -- 第5栏位可以装备前5强
        ["Pet6"] = 6     -- 第6栏位可以装备前6强（无限制）
    }
    
    return rankingRequirements[equipSlotId]
end

--- 【新增】获取包含最强加成宠物的完整排名
---@return table 完整排名列表 {{slotIndex: number, effectValue: number, petName: string, isStrongestBonus: boolean}}
function Pet:GetAllPetEffectRankingWithStrongestBonus()
    local ranking = {}
    local ConfigLoader = require(game:GetService('MainStorage').Code.Common.ConfigLoader)
    
    gg.log("[最强加成-排名] 开始计算包含最强加成的完整排名...")
    -- 遍历所有宠物
    for slotIndex, companionInstance in pairs(self.companionInstances) do
        if companionInstance and companionInstance.companionData then
            local petName = companionInstance:GetConfigName()
            local petConfig = ConfigLoader.GetPet(petName)
            local effectValue = 0
            local isStrongestBonus = false
            
            if petConfig and petConfig.specialBonus == "最强加成" then
                -- 最强加成宠物，计算其加成后的效果值
                effectValue = self:CalculateStrongestBonusValue(companionInstance, petConfig) or 0
                isStrongestBonus = true
            else
                -- 普通宠物，使用现有的计算方法
                effectValue = companionInstance:CalculateTotalEffectValue()
            end
            
            table.insert(ranking, {
                slotIndex = slotIndex,
                effectValue = effectValue,
                petName = petName,
                starLevel = companionInstance:GetStarLevel(),
                isStrongestBonus = isStrongestBonus
            })
            gg.log(string.format("[最强加成-排名] 槽位=%d 宠物=%s 星级=%d 类型=%s 计算值=%.4f", 
                slotIndex, petName, companionInstance:GetStarLevel(), isStrongestBonus and "最强加成" or "普通", effectValue))
        end
    end
    
    -- 按效果值降序排序
    table.sort(ranking, function(a, b)
        return a.effectValue > b.effectValue
    end)
    
    -- 打印排名日志
    gg.log("[最强加成-排名] 完整宠物效果排名:")
    for rank, petData in ipairs(ranking) do
        gg.log(string.format("[最强加成-排名] 第%d名: %s (槽位%d, %d星, 效果值%.4f, %s)", 
            rank, petData.petName, petData.slotIndex, petData.starLevel, petData.effectValue,
            petData.isStrongestBonus and "最强加成" or "普通"))
    end
    
    return ranking
end

--- 【重写】装备宠物方法，增加排名验证
---@param companionSlotId number 伙伴背包槽位
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function Pet:EquipPet(companionSlotId, equipSlotId)
    -- 先验证最强加成宠物的排名
    local isValid, reason, ranking = self:ValidateStrongestBonusPetEquip(companionSlotId, equipSlotId)
    -- if not isValid then
    --     return false, string.format("最强加成宠物排名验证失败: %s", reason)
    -- end
    
    -- 验证通过，调用基类装备方法
    return self:EquipCompanion(companionSlotId, equipSlotId)
end

--- 【重写】获取所有激活宠物的物品加成（支持最强加成宠物）
---@return table<string, table> 物品加成 {[物品目标] = {fixed = number, percentage = number}}
function Pet:GetActiveItemBonuses()
    local totalBonuses = {}
    local BonusManager = require(game:GetService('ServerStorage').BonusManager.BonusManager)

    local activeCompanions = self:GetActiveCompanions()
    gg.log(string.format("[Pet调试] GetActiveItemBonuses: 找到 %d 个激活的宠物", #activeCompanions))
    
    for _, companionInstance in ipairs(activeCompanions) do
        local petName = companionInstance:GetConfigName()
        local petConfig = ConfigLoader.GetPet(petName)
        
        local singleBonus = {}
        
        -- 【核心逻辑】检查是否为最强加成宠物
        if petConfig and petConfig.specialBonus == "最强加成" then
            gg.log(string.format("[Pet调试] 处理最强加成宠物: %s", petName))
            
            -- 为最强加成宠物计算特殊加成
            singleBonus = self:CalculateStrongestBonusForCompanion(companionInstance, petConfig)
        else
            -- 普通宠物使用原有逻辑
            singleBonus = companionInstance:GetItemBonuses()
        end
        
        gg.log(string.format("[Pet调试] %s 单个加成数据:", petName), singleBonus)
        
        -- 合并加成到总加成中
        BonusManager.MergeBonuses(totalBonuses, singleBonus)
    end

    gg.log(string.format("[Pet调试] GetActiveItemBonuses: 最终合并的宠物加成数据:"), totalBonuses)
    return totalBonuses
end

--- 【新增】为最强加成宠物计算特殊加成效果（直接复制最强宠物的加成）
---@param companionInstance CompanionInstance 最强加成宠物实例
---@param petConfig PetType 宠物配置
---@return table<string, table> 加成效果
function Pet:CalculateStrongestBonusForCompanion(companionInstance, petConfig)
    local starLevel = companionInstance:GetStarLevel()
    
    gg.log(string.format("开始为最强加成宠物%s(%d星)计算效果", petConfig.name, starLevel))
    
    -- 1. 获取背包最强宠物
    local strongestPet = self:CalculateAllPetBonusesAndGetStrongest()
    if not strongestPet then
        gg.log("没有找到背包最强宠物")
        return {}
    end
    
    -- 2. 获取当前宠物的倍率
    local bonusMultiplier = petConfig:GetSpecialBonusMultiplier(starLevel)
    if not bonusMultiplier then
        gg.log(string.format("无法获取星级%d的倍率", starLevel))
        return {}
    end
    
    gg.log(string.format("使用最强宠物: %s (%d星), 倍率: %.2f", strongestPet.petName, strongestPet.starLevel, bonusMultiplier))
    
    -- 3. 【核心】直接获取最强宠物的加成数据
    local strongestPetBonuses = strongestPet.companionInstance:GetItemBonuses()
    if not strongestPetBonuses or next(strongestPetBonuses) == nil then
        gg.log(string.format("最强宠物%s没有任何加成", strongestPet.petName))
        return {}
    end
    
    -- 4. 复制并缩放最强宠物的加成
    local scaledBonuses = {}
    for targetName, bonusData in pairs(strongestPetBonuses) do
        scaledBonuses[targetName] = {
            fixed = (bonusData.fixed or 0) * bonusMultiplier,
            percentage = (bonusData.percentage or 0) * bonusMultiplier,
            itemTarget = bonusData.itemTarget,
            targetVariable = bonusData.targetVariable
        }
        
        gg.log(string.format("缩放加成: %s -> 固定: %.2f * %.2f = %.2f, 百分比: %.2f * %.2f = %.2f", 
            targetName, 
            bonusData.fixed or 0, bonusMultiplier, scaledBonuses[targetName].fixed,
            bonusData.percentage or 0, bonusMultiplier, scaledBonuses[targetName].percentage))
    end
    
    gg.log(string.format("最强加成宠物%s计算完成，共%d个加成效果", petConfig.name, self:GetTableSize(scaledBonuses)))
    
    return scaledBonuses
end

--- 【辅助方法】计算表大小
---@param tbl table
---@return number
function Pet:GetTableSize(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--- 【重写】自动装备最优宠物，支持最强加成排名验证
---@param equipSlotId string 装备栏ID
---@param excludeEquipped boolean|nil 是否排除已装备的宠物
---@return boolean, string|nil, number|nil
function Pet:AutoEquipBestPet(equipSlotId, excludeEquipped)
    if excludeEquipped == nil then excludeEquipped = true end
    
    -- 检查装备栏是否有效
    if not self:IsValidEquipSlotId(equipSlotId) then
        return false, "无效的装备栏ID: " .. tostring(equipSlotId), nil
    end
    
    gg.log(string.format("[最强加成-一键装备] 开始执行，equipSlotId=%s excludeEquipped=%s", tostring(equipSlotId), tostring(excludeEquipped)))
    -- 获取包含最强加成的完整排名
    local ranking = self:GetAllPetEffectRankingWithStrongestBonus()
    local requiredRanking = self:GetEquipSlotRankingRequirement(equipSlotId)
    gg.log(string.format("[最强加成-一键装备] 装备栏位%s 的排名要求=%s", tostring(equipSlotId), tostring(requiredRanking)))
    
    -- 查找最适合的宠物
    for rank, petData in ipairs(ranking) do
        local slotIndex = petData.slotIndex
        
        -- 检查是否应该跳过
        local shouldSkip = (excludeEquipped and self:IsCompanionEquipped(slotIndex))
        if shouldSkip then
            gg.log(string.format("[最强加成-一键装备] 跳过已装备的宠物: %s (槽位%d, 排名%d)", petData.petName, slotIndex, rank))
        end
        
        if not shouldSkip then
            -- 检查排名要求
            if not requiredRanking or rank <= requiredRanking then
                -- 尝试装备
                local success, errorMsg = self:EquipCompanion(slotIndex, equipSlotId)
                if success then
                    gg.log(string.format("[最强加成-一键装备] 自动装备成功: %s (第%d名) -> %s", 
                        petData.petName, rank, equipSlotId))
                    return true, nil, slotIndex
                end
                gg.log(string.format("[最强加成-一键装备] 装备失败: %s (第%d名) -> %s, 错误=%s", 
                    petData.petName, rank, equipSlotId, tostring(errorMsg)))
            else
                gg.log(string.format("[最强加成-一键装备] 宠物%s排名第%d，超过装备栏%s要求的前%d", 
                    petData.petName, rank, equipSlotId, requiredRanking))
                break -- 后面的排名更低，不用继续检查
            end
        end
    end
    
    gg.log("[最强加成-一键装备] 未找到符合排名要求的宠物，流程结束")
    return false, "没有找到符合排名要求的宠物", nil
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

--- 设置可携带栏位数量
---@param count number
function Pet:SetUnlockedEquipSlots(count)
    if count and count > 0 then
        local maxEquipped = #self.equipSlotIds
        self.unlockedEquipSlots = math.min(count, maxEquipped)
        --gg.log("玩家", self.uin, "可携带宠物栏位数量已设置为", self.unlockedEquipSlots)
    end
end

--- 设置宠物背包容量
---@param capacity number
function Pet:SetPetBagCapacity(capacity)
    if capacity and capacity > 0 then
        self.maxSlots = capacity
        --gg.log("玩家", self.uin, "宠物背包容量已设置为", self.maxSlots)
    end
end

--- 增加可携带栏位数量
---@param count number 增加的数量
function Pet:AddUnlockedEquipSlots(count)
    if count and count > 0 then
        self.unlockedEquipSlots = (self.unlockedEquipSlots or 0) + count
        --gg.log("玩家", self.uin, "宠物可携带栏位增加", count, "个，当前总数:", self.unlockedEquipSlots)
    end
end

-- =================================
-- 栏位和容量管理方法
-- =================================

---减少可携带栏位数量
---@param count number 减少的数量
---@return boolean
function Pet:ReduceUnlockedEquipSlots(count)
    if count and count > 0 then
        self.unlockedEquipSlots = math.max(1, (self.unlockedEquipSlots or 1) - count)
        --gg.log("玩家", self.uin, "宠物可携带栏位减少", count, "个，当前总数:", self.unlockedEquipSlots)
        return true
    end
    return false
end

---增加宠物背包容量
---@param capacity number 增加的容量
---@return boolean
function Pet:AddPetBagCapacity(capacity)
    if capacity and capacity > 0 then
        self.maxSlots = (self.maxSlots or 50) + capacity
        --gg.log("玩家", self.uin, "宠物背包容量增加", capacity, "个，当前总数:", self.maxSlots)
        return true
    end
    return false
end

---减少宠物背包容量
---@param capacity number 减少的容量
---@return boolean
function Pet:ReducePetBagCapacity(capacity)
    if capacity and capacity > 0 then
        local newCapacity = math.max(1, (self.maxSlots or 50) - capacity)
        if newCapacity >= self:GetPetCount() then
            self.maxSlots = newCapacity
            --gg.log("玩家", self.uin, "宠物背包容量减少", capacity, "个，当前总数:", self.maxSlots)
            return true
        else
            --gg.log("玩家", self.uin, "宠物背包容量减少失败，当前宠物数量超过新容量")
            return false
        end
    end
    return false
end

-- =================================
-- 自动装备最优宠物便捷方法
-- =================================

-- 自动装备效果数值最高的宠物（宠物专用接口）
-- 提示：实际实现见本文件上方的“重写”版本

---自动装备所有装备栏的最优宠物（宠物专用接口）
---@param excludeEquipped boolean|nil 是否排除已装备的宠物
---@return table
function Pet:AutoEquipAllBestPets(excludeEquipped)
    if excludeEquipped == nil then excludeEquipped = true end

    local results = {}
    local usedSlots = {} -- 防止同一只宠物被多次装备

    -- 获取完整排名（包含最强加成宠物的真实计算值）
    local ranking = self:GetAllPetEffectRankingWithStrongestBonus()

    -- 逐个已解锁的装备栏位尝试装备
    local unlockedCount = self.unlockedEquipSlots or 1
    for i = 1, math.min(unlockedCount, #self.equipSlotIds) do
        local equipSlotId = self.equipSlotIds[i]
        local requiredRanking = self:GetEquipSlotRankingRequirement(equipSlotId)

        gg.log(string.format("[最强加成-一键装备-多栏] 处理栏位=%s 要求=前%s 名", tostring(equipSlotId), tostring(requiredRanking or "无")))

        local equipped = false
        local errorMsg = "没有找到符合排名要求的宠物"

        for rank, petData in ipairs(ranking) do
            local slotIndex = petData.slotIndex

            local skipByEquipped = excludeEquipped and self:IsCompanionEquipped(slotIndex)
            local skipByUsed = usedSlots[slotIndex] == true
            local passRanking = (not requiredRanking) or (rank <= requiredRanking)

            if skipByEquipped then
                gg.log(string.format("[最强加成-一键装备-多栏] 跳过已装备: %s 槽位=%d 排名=%d", petData.petName, slotIndex, rank))
            end
            if skipByUsed then
                gg.log(string.format("[最强加成-一键装备-多栏] 跳过已使用: %s 槽位=%d 排名=%d", petData.petName, slotIndex, rank))
            end
            if not passRanking then
                gg.log(string.format("[最强加成-一键装备-多栏] 排名不满足: %s 排名=%d > 要求前%d", petData.petName, rank, requiredRanking))
            end

            if (not skipByEquipped) and (not skipByUsed) and passRanking then
                local success, err = self:EquipCompanion(slotIndex, equipSlotId)
                if success then
                    gg.log(string.format("[最强加成-一键装备-多栏] 装备成功: %s 槽位=%d 排名=%d -> %s", petData.petName, slotIndex, rank, equipSlotId))
                    results[equipSlotId] = { success = true, slotIndex = slotIndex, errorMsg = nil }
                    usedSlots[slotIndex] = true
                    equipped = true
                    break
                else
                    gg.log(string.format("[最强加成-一键装备-多栏] 装备失败: %s 槽位=%d 排名=%d -> %s 错误=%s", petData.petName, slotIndex, rank, equipSlotId, tostring(err)))
                    errorMsg = err or errorMsg
                end
            end
        end

        if not equipped then
            results[equipSlotId] = { success = false, slotIndex = nil, errorMsg = errorMsg }
        end
    end

    return results
end

---获取宠物效果数值排行（宠物专用接口）
---@param limit number|nil 返回数量限制
---@return table
function Pet:GetPetEffectRanking(limit)
    return self:GetEffectValueRanking(limit)
end

return Pet
