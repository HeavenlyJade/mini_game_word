-- BonusManager.lua
-- 加成管理器 - 简化版，只保留核心的变量计算和宠物/伙伴计算规则

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr
local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
local TrailMgr = require(ServerStorage.MSystems.Trail.TrailMgr) ---@type TrailMgr
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class BonusManager 加成管理器（静态类）
local BonusManager = {}

-- ============================= 玩家变量加成计算 =============================

--- 计算玩家变量加成
--- 计算玩家变量加成（增强版：支持天赋加成）
--- 计算玩家变量加成（增强版：支持天赋系统独立获取）
---@param player MPlayer 玩家对象
---@param baseValue number 基础操作数值
---@param variableBonuses table 玩家变量加成列表
---@param targetVariable string|nil 目标变量名称（用于匹配加成，nil表示应用所有加成）
---@return number finalValue, string bonusInfo
function BonusManager.CalculatePlayerVariableBonuses(player, baseValue, variableBonuses, targetVariable)
    if not (player and player.variableSystem and variableBonuses and type(variableBonuses) == "table" and #variableBonuses > 0) then
        return baseValue, ""
    end

    local variableSystem = player.variableSystem
    local totalFlatBonus = 0
    local totalPercentBonus = 0
    local finalMultipliers = {}
    local bonusDescriptions = {}
    -- 基础值改造量：先对 baseValue 做"基础相加/基础相乘"，再计算其余加成
    local baseFlatAdd = 0
    local baseMultiplier = 1

    -- 获取玩家成就系统（用于天赋变量获取）
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr)
    local playerAchievement = AchievementMgr.server_player_achievement_data[player.uin] ---@type Achievement

    for i, bonusItem in ipairs(variableBonuses) do
        local bonusVarName = bonusItem["名称"]
        local actionType = bonusItem["作用类型"]
        local targetVar = bonusItem["目标变量"]
        local scalingRate = bonusItem["缩放倍率"] or 1
        local effectFieldName = bonusItem["玩家效果字段"] -- 效果等级配置字段

        -- 如果指定了目标变量，只对匹配的变量生效
        if targetVariable and targetVar and targetVar ~= targetVariable then
            -- 跳过不匹配的加成
        else
            if bonusVarName and actionType then
                local parsed = variableSystem:ParseVariableName(bonusVarName)
                if parsed then
                    local bonusValue = 0
                    
                    if effectFieldName and effectFieldName ~= "" then
                        -- 从效果等级配置获取值
                        local effectLevelConfig = ConfigLoader.GetEffectLevel(effectFieldName)
                        if effectLevelConfig then
                            local bagData = MServerDataManager.BagMgr.GetPlayerBag(player.uin)
                            local externalContext = {}
                            local playerData = player.variableSystem:GetVariablesDictionary()
                            local maxEffectIndex = effectLevelConfig:GetMaxEffectIndex(playerData, bagData, externalContext)
                            if maxEffectIndex then
                                local maxEffectValue = effectLevelConfig.levelEffects[maxEffectIndex].effectValue
                                bonusValue = maxEffectValue
                                table.insert(bonusDescriptions, string.format("效果等级配置加成(%s, +%s)", 
                                    effectFieldName, tostring(maxEffectValue)))
                            end
                        end
                    else
                        -- 关键修改：根据变量名前缀选择数据源
                        if string.find(bonusVarName, "^天赋_") then
                            -- 从天赋变量系统获取
                            if playerAchievement and playerAchievement.talentVariableSystem then
                                bonusValue = playerAchievement.talentVariableSystem:GetRawBonusValue(bonusVarName)
                                --gg.log(string.format("从天赋系统获取变量[%s]: %s", bonusVarName, tostring(bonusValue)))
                            else
                                ----gg.log(string.format("警告：玩家[%s]天赋系统不存在，无法获取[%s]", player.uin, bonusVarName))
                            end
                        else
                            -- 其他所有变量从玩家变量系统获取
                            bonusValue = variableSystem:GetRawBonusValue(bonusVarName)
                            --gg.log(string.format("从玩家系统获取变量[%s]: %s", bonusVarName, tostring(bonusValue)))
                        end
                    end
                    
                    -- 应用加成计算逻辑
                    if actionType == "单独相加" then
                        if parsed.method == "百分比" then
                            totalPercentBonus = totalPercentBonus + bonusValue
                            table.insert(bonusDescriptions, string.format("'%s' (%s%%, 单独相加)", parsed.name, bonusValue * 100))
                        elseif parsed.method == "固定值" then
                            totalFlatBonus = totalFlatBonus + bonusValue
                            table.insert(bonusDescriptions, string.format("'%s' (+%s, 单独相加)", parsed.name, bonusValue))
                        end
                    elseif actionType == "最终乘法" and bonusValue > 0 then
                        table.insert(finalMultipliers, bonusValue)
                        table.insert(bonusDescriptions, string.format("'%s' (×%s, 最终乘法)", parsed.name, bonusValue))
                    elseif actionType == "基础相乘" then
                        -- 基础相乘：先作用到基础值 baseValue 上
                        local multiplier = 1 + (bonusValue * scalingRate)
                        baseMultiplier = baseMultiplier * math.max(0, multiplier)
                        table.insert(bonusDescriptions, string.format("'%s' (基础×%s)", parsed.name, multiplier))
                    elseif actionType == "基础相加" then
                        -- 基础相加：直接累加到基础值 baseValue 上
                        local addValue = bonusValue * scalingRate
                        baseFlatAdd = baseFlatAdd + addValue
                        table.insert(bonusDescriptions, string.format("'%s' (基础+%s)", parsed.name, addValue))
                    end
                end
            end
        end
    end

    -- 先对基础值应用"基础相加/基础相乘"
    local baseAfterFoundation = baseValue * baseMultiplier + baseFlatAdd
    -- 在改造后的基础值上应用"单独相加"（百分比、固定）
    local finalBonusValue = baseAfterFoundation + (baseAfterFoundation * totalPercentBonus) + totalFlatBonus
    
    -- 应用最终乘法
    for i, multiplier in ipairs(finalMultipliers) do
        finalBonusValue = finalBonusValue * multiplier
    end

    local bonusInfo = ""
    if #bonusDescriptions > 0 then
        bonusInfo = string.format(
            "\n> 加成来源: %s.\n> 原始基础: %s, 基础改造后: %s, 最终值: %s (固定: %s, 百分比: %s%%, 最终乘法: %d个).",
            table.concat(bonusDescriptions, ", "),
            tostring(baseValue),
            tostring(baseAfterFoundation),
            tostring(finalBonusValue),
            tostring(totalFlatBonus),
            tostring(totalPercentBonus * 100),
            #finalMultipliers
        )
    end
    
    --gg.log("变量加成计算完成", bonusInfo)
    return finalBonusValue, bonusInfo
end
-- ============================= 宠物/伙伴加成计算 =============================

--- 获取宠物物品加成
---@param player MPlayer 玩家实例
---@return table<string, any> 宠物加成数据（可能包含 fixed, percentage, targetVariable, itemTarget 等字段）
function BonusManager.GetPetItemBonuses(player)
    if not player or not player.uin then
        ------gg.log("[BonusManager调试] GetPetItemBonuses: 玩家对象无效")
        return {}
    end

    local bonuses = PetMgr.GetActiveItemBonuses(player.uin)
    ------gg.log("[BonusManager调试] GetPetItemBonuses: 玩家", player.uin, "宠物加成数据:", bonuses)
    return bonuses
end

--- 获取伙伴物品加成
---@param player MPlayer 玩家实例
---@return table<string, any> 伙伴加成数据（可能包含 fixed, percentage, targetVariable, itemTarget 等字段）
function BonusManager.GetPartnerItemBonuses(player)
    if not player or not player.uin then
        ------gg.log("[BonusManager调试] GetPartnerItemBonuses: 玩家对象无效")
        return {}
    end

    local bonuses = PartnerMgr.GetActiveItemBonuses(player.uin)
    ------gg.log("[BonusManager调试] GetPartnerItemBonuses: 玩家", player.uin, "伙伴加成数据:", bonuses)
    return bonuses
end

--- 获取翅膀物品/玩家变量加成
---@param player MPlayer 玩家实例
---@return table<string, any> 翅膀加成数据（可能包含 fixed, percentage, targetVariable, itemTarget 等字段）
function BonusManager.GetWingItemBonuses(player)
    if not player or not player.uin then
        return {}
    end
    local bonuses = WingMgr.GetActiveItemBonuses(player.uin)
    ------gg.log("[BonusManager调试] GetWingItemBonuses: 玩家", player.uin, "翅膀加成数据:", bonuses)
    return bonuses or {}
end

--- 获取尾迹物品/玩家变量加成
---@param player MPlayer 玩家实例
---@return table<string, any> 尾迹加成数据（可能包含 fixed, percentage, targetVariable, itemTarget 等字段）
function BonusManager.GetTrailItemBonuses(player)
    if not player or not player.uin then
        return {}
    end
    local bonuses = TrailMgr.GetActiveItemBonuses(player.uin)
    return bonuses or {}
end

--- 计算玩家所有物品加成
---@param player MPlayer 玩家实例
---@return table<string, { fixed: number, percentage: number, [any]: any }> 按物品目标分组的加成数据
function BonusManager.CalculatePlayerItemBonuses(player)
    if not player then
        return {}
    end

    local totalBonuses = {}

    -- 1. 获取宠物加成
    local petBonuses = BonusManager.GetPetItemBonuses(player)
    BonusManager.MergeBonuses(totalBonuses, petBonuses)

    -- 2. 获取伙伴加成
    local partnerBonuses = BonusManager.GetPartnerItemBonuses(player)
    BonusManager.MergeBonuses(totalBonuses, partnerBonuses)

    -- 3. 获取翅膀加成
    local wingBonuses = BonusManager.GetWingItemBonuses(player)
    BonusManager.MergeBonuses(totalBonuses, wingBonuses)

    -- 4. 获取尾迹加成
    local trailBonuses = BonusManager.GetTrailItemBonuses(player)
    BonusManager.MergeBonuses(totalBonuses, trailBonuses)

    return totalBonuses
end

--- 将加成应用到奖励（先乘后加）
---@param rewards table<string, number> 原始奖励 {[物品名] = 数量}
---@param bonuses table<string, {fixed: number, percentage: number}> 加成数据
---@return table<string, number> 应用加成后的奖励
function BonusManager.ApplyBonusesToRewards(rewards, bonuses)
    if not rewards or not bonuses then
        return rewards or {}
    end

    local finalRewards = {}

    for itemName, amount in pairs(rewards) do
        local bonusData = bonuses[itemName] or { fixed = 0, percentage = 0 }

        -- 1. 应用百分比加成（乘法）
        local amountAfterPercentage = math.floor(amount * (1 + (bonusData.percentage or 0) / 100))

        -- 2. 应用固定值加成（加法）
        local finalAmount = amountAfterPercentage + (bonusData.fixed or 0)

        finalRewards[itemName] = finalAmount
    end

    return finalRewards
end

-- ============================= 工具方法 =============================

--- 合并加成数据
---@param target table<string, { fixed: number, percentage: number, [any]: any }> 目标加成表
---@param source table<string, any> 源加成表
function BonusManager.MergeBonuses(target, source)
    if not source then
        return
    end

    for itemName, bonusData in pairs(source) do
        if not target[itemName] then
            target[itemName] = { fixed = 0, percentage = 0 }
        end

        if type(bonusData.fixed) == "number" and bonusData.fixed > 0 then
            target[itemName].fixed = (target[itemName].fixed or 0) + bonusData.fixed
        end
        if type(bonusData.percentage) == "number" and bonusData.percentage > 0 then
            target[itemName].percentage = (target[itemName].percentage or 0) + bonusData.percentage
        end
        
        -- 【修复】保留匹配所需的字段
        if bonusData.targetVariable then
            target[itemName].targetVariable = bonusData.targetVariable
        end
        if bonusData.itemTarget then
            target[itemName].itemTarget = bonusData.itemTarget
        end
    end
end

return BonusManager