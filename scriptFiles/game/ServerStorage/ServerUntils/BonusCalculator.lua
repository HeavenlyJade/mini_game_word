--- 通用加成计算工具类

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local BonusManager = require(ServerStorage.BonusManager.BonusManager) ---@type BonusManager
local AttributeMapping = require(MainStorage.Code.Common.Icon.AttributeMapping) ---@type AttributeMapping
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

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
        if bonusType == "宠物" then
            local petBonuses = BonusManager.GetPetItemBonuses(player)
            for itemName, bonusData in pairs(petBonuses) do
                local isMatch = bonusData.targetVariable == statName or
                               (not bonusData.targetVariable and bonusData.itemTarget == statName)
                if isMatch then
                    if bonusData.fixed and bonusData.fixed > 0 then
                        totalValue = totalValue + bonusData.fixed
                        table.insert(bonusDescriptions, string.format("宠物属性加成(%s, +%d)", itemName, bonusData.fixed))
                    end
                    if bonusData.percentage and bonusData.percentage > 0 then
                        local percentageBonus = math.floor(playerStatValue * bonusData.percentage / 100)
                        totalValue = totalValue + percentageBonus
                        table.insert(bonusDescriptions, string.format("宠物属性加成(%s, +%d%%)", itemName, bonusData.percentage))
                    end
                end
            end
        elseif bonusType == "伙伴" then
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
        elseif bonusType == "尾迹" then
            local trailBonuses = BonusManager.GetTrailItemBonuses(player)
            for itemName, bonusData in pairs(trailBonuses) do
                local isMatch = bonusData.targetVariable == statName or
                               (not bonusData.targetVariable and bonusData.itemTarget == statName)
                if isMatch then
                    if bonusData.fixed and bonusData.fixed > 0 then
                        totalValue = totalValue + bonusData.fixed
                        table.insert(bonusDescriptions, string.format("尾迹属性加成(%s, +%d)", itemName, bonusData.fixed))
                    end
                    if bonusData.percentage and bonusData.percentage > 0 then
                        local percentageBonus = math.floor(playerStatValue * bonusData.percentage / 100)
                        totalValue = totalValue + percentageBonus
                        table.insert(bonusDescriptions, string.format("尾迹属性加成(%s, +%d%%)", itemName, bonusData.percentage))
                    end
                end
            end
        elseif bonusType == "翅膀" then
            local wingBonuses = BonusManager.GetWingItemBonuses(player)
            --------gg.log(string.format("[BonusCalculator调试] GetOtherStatBonuses: 处理翅膀类型，目标属性: %s，翅膀加成数据: %s", statName, tostring(wingBonuses)))
            for itemName, bonusData in pairs(wingBonuses) do
                local isMatch = bonusData.targetVariable == statName or
                               (not bonusData.targetVariable and bonusData.itemTarget == statName)
                --------gg.log(string.format("[BonusCalculator调试] 翅膀加成匹配检查: %s, targetVariable: %s, itemTarget: %s, isMatch: %s",
                 --itemName, tostring(bonusData.targetVariable), tostring(bonusData.itemTarget), tostring(isMatch)))
                if isMatch then
                    if bonusData.fixed and bonusData.fixed > 0 then
                        totalValue = totalValue + bonusData.fixed
                        table.insert(bonusDescriptions, string.format("翅膀属性加成(%s, +%d)", itemName, bonusData.fixed))
                        --------gg.log(string.format("[BonusCalculator调试] 添加翅膀固定加成: %s +%d", itemName, bonusData.fixed))
                    end
                    if bonusData.percentage and bonusData.percentage > 0 then
                        local percentageBonus = math.floor(playerStatValue * bonusData.percentage / 100)
                        totalValue = totalValue + percentageBonus
                        table.insert(bonusDescriptions, string.format("翅膀属性加成(%s, +%d%%)", itemName, bonusData.percentage))
                        --------gg.log(string.format("[BonusCalculator调试] 添加翅膀百分比加成: %s +%d%% (计算值: %d)", itemName, bonusData.percentage, percentageBonus))
                    end
                end
            end
        end
    end
    --gg.log("其它属性加成", totalValue, bonusDescriptions)
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
    --------gg.log("playerStatBonuses111121",playerStatBonuses)

    for _, bonusItem in ipairs(playerStatBonuses) do
        local bonusStatName = bonusItem["名称"]
        local actionType = bonusItem["作用类型"]
        local scalingRate = bonusItem["缩放倍率"] or 0
        local effectFieldName = bonusItem["玩家效果字段"] -- 新增：获取玩家效果字段
        --gg.log(string.format("[111111BonusCalculator调试] CalculatePlayerStatBonuses: 属性 %s, 作用类型: %s, 缩放倍率: %s", bonusStatName, actionType, scalingRate))
        if bonusStatName and actionType then
            local bonusValue = 0

            -- 原有逻辑：从玩家属性系统读取
            local playerStatValue = 0
            if AttributeMapping.IsAttributeVariable(bonusStatName) then
                local actualStatName = AttributeMapping.GetCorrespondingStat(bonusStatName)
                playerStatValue = player:GetStat(actualStatName) or 0
            else
                playerStatValue = player:GetStat(bonusStatName) or 0
            end

            bonusValue = bonusValue + playerStatValue

            -- 新增逻辑：当玩家效果字段不为nil时，从EffectLevelType配置中获取最大效果值
            if effectFieldName and effectFieldName ~= "" then
                local effectLevelConfig = ConfigLoader.GetEffectLevel(bonusStatName)
                if effectLevelConfig then
                    -- 获取玩家背包数据
                    local bagData = MServerDataManager.BagMgr.GetPlayerBag(player.uin)

                    -- 构建外部上下文（可根据需要扩展）
                    local externalContext = {}

                    -- 获取满足条件的最大效果数值
                    local playerData =  player.variableSystem:GetVariablesDictionary()
                    local maxEffectIndex = effectLevelConfig:GetMaxEffectIndex(playerData, bagData, externalContext)
                    if maxEffectIndex then
                        local maxEffectValue = effectLevelConfig.levelEffects[maxEffectIndex].effectValue
                        bonusValue = bonusValue + maxEffectValue

                        table.insert(bonusDescriptions, string.format("效果等级配置加成(%s, +%s)",
                            bonusStatName, tostring(maxEffectValue)))
                    end
                end
            end

            -- 从其他加成中读取同名属性配置
            local otherStatValue, otherDescriptions = BonusCalculator.GetOtherStatBonuses(player, bonusStatName, otherBonuses, playerStatValue)
            bonusValue = bonusValue + otherStatValue

            --gg.log(string.format("[BonusCalculator调试] CalculatePlayerStatBonuses: 属性 %s 从其他加成读取到值: %s, 描述: %s",
                -- bonusStatName, tostring(otherStatValue), tostring(otherDescriptions)))

            -- 合并描述信息
            for _, desc in ipairs(otherDescriptions) do
                table.insert(bonusDescriptions, desc)
            end

            -- 应用加成计算
            if actionType == "单独相加" then
                local finalBonus = bonusValue * (1 + scalingRate)
                totalBonus = totalBonus + finalBonus
                table.insert(bonusDescriptions, string.format("属性加成(%s, %s)", bonusStatName, tostring(finalBonus)))
            elseif actionType == "基础相乘" then
                local multiplier = 1 +  scalingRate
                baseValue = baseValue * math.max(0, multiplier)
                table.insert(bonusDescriptions, string.format("属性基础相乘(%s, ×%s)", bonusStatName, tostring(multiplier)))
            elseif actionType == "基础相加" then
                local addValue = bonusValue * (1 + scalingRate)
                baseValue = baseValue + addValue
                table.insert(bonusDescriptions, string.format("属性基础相加(%s, +%s)", bonusStatName, tostring(addValue)))
            elseif actionType == "仅作引用" then
                -- 仅作引用：不改变任何数值，只记录当前值供其它加成引用
                table.insert(bonusDescriptions, string.format("属性仅作引用(%s, 值=%s)", bonusStatName, tostring(bonusValue)))
            end
        end
    end
    --gg.log("玩家属性加成", totalBonus, bonusDescriptions)
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
--- 完整的加成计算（串行模式：属性加成 → 变量加成 → 其他加成）
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

    -- 阶段1：计算玩家属性加成
    local currentValue = baseValue
    local statBonus = 0
    if playerStatBonuses and type(playerStatBonuses) == "table" and #playerStatBonuses > 0 then
        local statBonusValue, statDescriptions = BonusCalculator.CalculatePlayerStatBonuses(player, currentValue, playerStatBonuses, otherBonuses)
        statBonus = statBonusValue
        currentValue = currentValue + statBonus

        for _, desc in ipairs(statDescriptions) do
            table.insert(allDescriptions, desc)
        end

        --gg.log(string.format("玩家属性加成阶段: 基础值 %s → 加成后 %s (增加 %s)",
            -- tostring(baseValue), tostring(currentValue), tostring(statBonus)))
    end

    -- 阶段2：计算玩家变量加成（基于属性加成后的值）
    local variableBonus = 0
    if playerVariableBonuses and type(playerVariableBonuses) == "table" and #playerVariableBonuses > 0 then
        local variableFinalValue, variableInfo = BonusManager.CalculatePlayerVariableBonuses(player, currentValue, playerVariableBonuses, targetName)
        variableBonus = variableFinalValue - currentValue  -- 计算净加成值
        currentValue = variableFinalValue

        if variableInfo and variableInfo ~= "" then
            table.insert(allDescriptions, "变量加成")
        end

        --gg.log(string.format("玩家变量加成阶段: 输入值 %s → 加成后 %s (增加 %s)",tostring(currentValue - variableBonus), tostring(currentValue), tostring(variableBonus)))
    end

    -- 阶段3：计算其他加成（宠物、伙伴等，基于变量加成后的值）
    local otherBonus = 0
    if otherBonuses and type(otherBonuses) == "table" and #otherBonuses > 0 then
        local otherBonusValue, otherDescriptions = BonusCalculator.CalculateOtherBonuses(player, currentValue, otherBonuses, targetName)
        otherBonus = otherBonusValue
        currentValue = currentValue + otherBonus

        for _, desc in ipairs(otherDescriptions) do
            table.insert(allDescriptions, desc)
        end

        --gg.log(string.format("其他加成阶段: 输入值 %s → 加成后 %s (增加 %s)",
            -- tostring(currentValue - otherBonus), tostring(currentValue), tostring(otherBonus)))
    end

    local finalValue = currentValue
    local totalBonus = finalValue - originalBaseValue

    local bonusInfo = ""
    if #allDescriptions > 0 then
        bonusInfo = string.format(
            "\n> 加成来源: %s.\n> 原始基础: %s, 最终值: %s, 总加成: %s.\n> 计算阶段: 属性加成(%s) → 变量加成(%s) → 其他加成(%s).",
            table.concat(allDescriptions, ", "),
            tostring(originalBaseValue),
            tostring(finalValue),
            tostring(totalBonus),
            tostring(statBonus),
            tostring(variableBonus),
            tostring(otherBonus)
        )
    end

    return finalValue, bonusInfo
end

return BonusCalculator
