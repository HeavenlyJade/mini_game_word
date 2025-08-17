--- 通用加成计算工具类

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local BonusManager = require(ServerStorage.BonusManager.BonusManager) ---@type BonusManager

---@class BonusCalculator
local BonusCalculator = {}

--- 计算其他加成（宠物、伙伴、尾迹、翅膀携带效果）
---@param player MPlayer 玩家对象
---@param baseValue number 基础数值
---@param otherBonuses table 其他加成类型列表 ["宠物", "伙伴", "尾迹", "翅膀"]
---@param targetName string 目标名称（用于匹配携带效果）
---@return number, table totalBonus, bonusDescriptions
function BonusCalculator.CalculateOtherBonuses(player, baseValue, otherBonuses, targetName)
    local totalBonus = 0
    local bonusDescriptions = {}
    
    if not (otherBonuses and type(otherBonuses) == "table") then
        return totalBonus, bonusDescriptions
    end
    
    for _, bonusType in ipairs(otherBonuses) do
        if bonusType == "宠物" then
            local petBonuses = BonusManager.GetPetItemBonuses(player)
            for itemName, bonusData in pairs(petBonuses) do
                local isMatch = bonusData.targetVariable == targetName or 
                               (not bonusData.targetVariable and bonusData.itemTarget == targetName)
                if isMatch then
                    if bonusData.fixed and bonusData.fixed > 0 then
                        totalBonus = totalBonus + bonusData.fixed
                        table.insert(bonusDescriptions, string.format("宠物携带加成(%s, +%d)", itemName, bonusData.fixed))
                    end
                    if bonusData.percentage and bonusData.percentage > 0 then
                        local percentageBonus = math.floor(baseValue * bonusData.percentage / 100)
                        totalBonus = totalBonus + percentageBonus
                        table.insert(bonusDescriptions, string.format("宠物携带加成(%s, +%d%%)", itemName, bonusData.percentage))
                    end
                end
            end
        elseif bonusType == "伙伴" then
            local partnerBonuses = BonusManager.GetPartnerItemBonuses(player)
            for itemName, bonusData in pairs(partnerBonuses) do
                local isMatch = bonusData.targetVariable == targetName or 
                               (not bonusData.targetVariable and bonusData.itemTarget == targetName)
                if isMatch then
                    if bonusData.fixed and bonusData.fixed > 0 then
                        totalBonus = totalBonus + bonusData.fixed
                        table.insert(bonusDescriptions, string.format("伙伴携带加成(%s, +%d)", itemName, bonusData.fixed))
                    end
                    if bonusData.percentage and bonusData.percentage > 0 then
                        local percentageBonus = math.floor(baseValue * bonusData.percentage / 100)
                        totalBonus = totalBonus + percentageBonus
                        table.insert(bonusDescriptions, string.format("伙伴携带加成(%s, +%d%%)", itemName, bonusData.percentage))
                    end
                end
            end
        elseif bonusType == "尾迹" then
            local trailBonuses = BonusManager.GetTrailItemBonuses(player)
            for itemName, bonusData in pairs(trailBonuses) do
                local isMatch = bonusData.targetVariable == targetName or 
                               (not bonusData.targetVariable and bonusData.itemTarget == targetName)
                if isMatch then
                    if bonusData.fixed and bonusData.fixed > 0 then
                        totalBonus = totalBonus + bonusData.fixed
                        table.insert(bonusDescriptions, string.format("尾迹携带加成(%s, +%d)", itemName, bonusData.fixed))
                    end
                    if bonusData.percentage and bonusData.percentage > 0 then
                        local percentageBonus = math.floor(baseValue * bonusData.percentage / 100)
                        totalBonus = totalBonus + percentageBonus
                        table.insert(bonusDescriptions, string.format("尾迹携带加成(%s, +%d%%)", itemName, bonusData.percentage))
                    end
                end
            end
        elseif bonusType == "翅膀" then
            local wingBonuses = BonusManager.GetWingItemBonuses(player)
            for itemName, bonusData in pairs(wingBonuses) do
                local isMatch = bonusData.targetVariable == targetName or 
                               (not bonusData.targetVariable and bonusData.itemTarget == targetName)
                if isMatch then
                    if bonusData.fixed and bonusData.fixed > 0 then
                        totalBonus = totalBonus + bonusData.fixed
                        table.insert(bonusDescriptions, string.format("翅膀携带加成(%s, +%d)", itemName, bonusData.fixed))
                    end
                    if bonusData.percentage and bonusData.percentage > 0 then
                        local percentageBonus = math.floor(baseValue * bonusData.percentage / 100)
                        totalBonus = totalBonus + percentageBonus
                        table.insert(bonusDescriptions, string.format("翅膀携带加成(%s, +%d%%)", itemName, bonusData.percentage))
                    end
                end
            end
        end
    end
    
    return totalBonus, bonusDescriptions
end

--- 获取其他加成中的属性配置（用于玩家属性加成计算）
---@param player MPlayer 玩家对象
---@param statName string 属性名
---@param otherBonuses table 其他加成类型列表
---@param playerStatValue number 玩家当前属性值（用于百分比计算）
---@return number, table totalValue, bonusDescriptions
function BonusCalculator.GetOtherStatBonuses(player, statName, otherBonuses, playerStatValue)
    local totalValue = 0
    local bonusDescriptions = {}
    
    if not (otherBonuses and type(otherBonuses) == "table") then
        return totalValue, bonusDescriptions
    end
    
    for _, bonusType in ipairs(otherBonuses) do
        if bonusType == "伙伴" then
            local partnerBonuses = BonusManager.GetPartnerItemBonuses(player)
            for itemName, bonusData in pairs(partnerBonuses) do
                local isMatch = bonusData.targetVariable == statName or 
                               (not bonusData.targetVariable and bonusData.itemTarget == statName)
                if isMatch then
                    if bonusData.fixed and bonusData.fixed > 0 then
                        totalValue = totalValue + bonusData.fixed
                        table.insert(bonusDescriptions, string.format("伙伴属性加成(%s, +%d)", itemName, bonusData.fixed))
                    end
                    if bonusData.percentage and bonusData.percentage > 0 then
                        local percentageBonus = math.floor(playerStatValue * bonusData.percentage / 100)
                        totalValue = totalValue + percentageBonus
                        table.insert(bonusDescriptions, string.format("伙伴属性加成(%s, +%d%%)", itemName, bonusData.percentage))
                    end
                end
            end
        end
        -- 可以扩展其他类型的属性加成（宠物、尾迹、翅膀）
    end
    
    return totalValue, bonusDescriptions
end

--- 计算玩家属性加成（包括从其他加成中读取的属性配置）
---@param player MPlayer 玩家对象
---@param baseValue number 基础数值
---@param playerStatBonuses table 玩家属性加成列表
---@param otherBonuses table 其他加成类型列表
---@return number, table totalBonus, bonusDescriptions
function BonusCalculator.CalculatePlayerStatBonuses(player, baseValue, playerStatBonuses, otherBonuses)
    local totalBonus = 0
    local bonusDescriptions = {}
    
    if not (playerStatBonuses and type(playerStatBonuses) == "table") then
        return totalBonus, bonusDescriptions
    end
    
    for _, bonusItem in ipairs(playerStatBonuses) do
        local bonusStatName = bonusItem["名称"]
        local actionType = bonusItem["作用类型"]
        local scalingRate = bonusItem["缩放倍率"] or 1
        
        if bonusStatName and actionType then
            local bonusValue = 0
            
            -- 从玩家属性系统读取
            local playerStatValue = player:GetStat(bonusStatName) or 0
            bonusValue = bonusValue + playerStatValue
            
            -- 从其他加成中读取同名属性配置
            local otherStatValue, otherDescriptions = BonusCalculator.GetOtherStatBonuses(player, bonusStatName, otherBonuses, playerStatValue)
            bonusValue = bonusValue + otherStatValue
            
            -- 合并描述信息
            for _, desc in ipairs(otherDescriptions) do
                table.insert(bonusDescriptions, desc)
            end
            
            -- 应用加成计算
            if actionType == "单独相加" then
                local finalBonus = bonusValue * scalingRate
                totalBonus = totalBonus + finalBonus
                table.insert(bonusDescriptions, string.format("属性加成(%s, %s)", bonusStatName, tostring(finalBonus)))
            elseif actionType == "基础相乘" then
                local multiplier = 1 + (bonusValue * scalingRate / 100)
                baseValue = baseValue * math.max(0, multiplier)
                table.insert(bonusDescriptions, string.format("属性基础相乘(%s, ×%s)", bonusStatName, tostring(multiplier)))
            elseif actionType == "基础相加" then
                local addValue = bonusValue * scalingRate
                baseValue = baseValue + addValue
                table.insert(bonusDescriptions, string.format("属性基础相加(%s, +%s)", bonusStatName, tostring(addValue)))
            end
        end
    end
    
    return totalBonus, bonusDescriptions
end

--- 计算玩家变量加成（包括从其他加成中读取的变量配置）
---@param player MPlayer 玩家对象
---@param baseValue number 基础数值
---@param playerVariableBonuses table 玩家变量加成列表
---@param otherBonuses table 其他加成类型列表
---@param targetName string 目标名称
---@return number, table totalBonus, bonusDescriptions
function BonusCalculator.CalculatePlayerVariableBonuses(player, baseValue, playerVariableBonuses, otherBonuses, targetName)
    local totalBonus = 0
    local bonusDescriptions = {}
    
    if not (playerVariableBonuses and type(playerVariableBonuses) == "table") then
        return totalBonus, bonusDescriptions
    end
    
    -- 使用 BonusManager 计算变量加成
    local variableBonus, variableInfo = BonusManager.CalculatePlayerVariableBonuses(player, baseValue, playerVariableBonuses, targetName)
    totalBonus = totalBonus + (variableBonus - baseValue)
    
    if variableInfo and variableInfo ~= "" then
        table.insert(bonusDescriptions, "变量加成")
    end
    
    return totalBonus, bonusDescriptions
end

--- 完整的加成计算（属性加成 + 变量加成 + 其他加成）
---@param player MPlayer 玩家对象
---@param baseValue number 基础数值
---@param playerStatBonuses table 玩家属性加成列表
---@param playerVariableBonuses table 玩家变量加成列表
---@param otherBonuses table 其他加成类型列表
---@param targetName string 目标名称
---@return number, string finalValue, bonusInfo
function BonusCalculator.CalculateAllBonuses(player, baseValue, playerStatBonuses, playerVariableBonuses, otherBonuses, targetName)
    local allDescriptions = {}
    local originalBaseValue = baseValue
    local totalBonus = 0
    
    -- 1. 计算玩家属性加成
    local statBonus, statDescriptions = BonusCalculator.CalculatePlayerStatBonuses(player, baseValue, playerStatBonuses, otherBonuses)
    totalBonus = totalBonus + statBonus
    for _, desc in ipairs(statDescriptions) do
        table.insert(allDescriptions, desc)
    end
    
    -- 2. 计算玩家变量加成
    local variableBonus, variableDescriptions = BonusCalculator.CalculatePlayerVariableBonuses(player, baseValue, playerVariableBonuses, otherBonuses, targetName)
    totalBonus = totalBonus + variableBonus
    for _, desc in ipairs(variableDescriptions) do
        table.insert(allDescriptions, desc)
    end
    
    -- 3. 计算其他加成
    local otherBonus, otherDescriptions = BonusCalculator.CalculateOtherBonuses(player, baseValue, otherBonuses, targetName)
    totalBonus = totalBonus + otherBonus
    for _, desc in ipairs(otherDescriptions) do
        table.insert(allDescriptions, desc)
    end
    
    local finalValue = baseValue + totalBonus
    local bonusInfo = ""
    if #allDescriptions > 0 then
        bonusInfo = string.format("\n> 加成来源: %s.\n> 基础值: %s, 总加成: %s, 最终值: %s.",
            table.concat(allDescriptions, ", "),
            tostring(originalBaseValue),
            tostring(totalBonus),
            tostring(finalValue)
        )
    end
    
    return finalValue, bonusInfo
end

return BonusCalculator
