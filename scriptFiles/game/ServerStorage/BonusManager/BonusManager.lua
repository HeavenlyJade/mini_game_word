-- BonusManager.lua
-- 加成管理器 - 统一处理所有加成计算逻辑
-- 负责获取、合并和应用各种来源的加成效果

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr
local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class BonusManager 加成管理器（静态类）
local BonusManager = {}

--- 验证玩家对象
---@param player MPlayer 玩家实例
---@return boolean 是否有效
function BonusManager.ValidatePlayer(player)
    return player and player.variableSystem ~= nil
end

-- ============================= 统一加成计算接口 =============================

--- 统一加成计算入口 - 合并所有类型的加成
---@param player MPlayer 玩家实例
---@param baseRewards table 基础奖励 {variables = {}, items = {}}
---@param bonusContext table 加成上下文 {source, gameMode, variableBonuses, etc.}
---@return table 最终奖励 {variables = {}, items = {}}
function BonusManager.CalculateUnifiedRewards(player, baseRewards, bonusContext)
    if not BonusManager.ValidatePlayer(player) or not baseRewards then
        return baseRewards or {}
    end

    local finalRewards = {
        variables = {},
        items = {}
    }

    bonusContext = bonusContext or {}

    --gg.log(string.format("[BonusManager] 开始统一奖励计算，玩家: %s，来源: %s", 
    --    player.name or "未知", bonusContext.source or "未知"))

    -- 1. 处理变量类型奖励（应用变量加成）
    if baseRewards.variables then
        for variableName, amount in pairs(baseRewards.variables) do
            local variableBonuses = bonusContext.variableBonuses or {}
            local finalAmount, bonusInfo = BonusManager.CalculatePlayerVariableBonuses(
                player, amount, variableBonuses, variableName
            )
            finalRewards.variables[variableName] = finalAmount
            
            if bonusInfo ~= "" then
                --gg.log(string.format("[统一加成] 变量 %s: %s", variableName, bonusInfo))
            end
        end
    end
    
    -- 2. 处理物品类型奖励（应用物品加成）
    if baseRewards.items then
        local itemBonuses = BonusManager.CalculatePlayerItemBonuses(player)
        finalRewards.items = BonusManager.ApplyBonusesToRewards(baseRewards.items, itemBonuses)
    end

    -- 3. 记录最终奖励统计
    BonusManager.LogUnifiedRewardSummary(player, baseRewards, finalRewards, bonusContext)

    return finalRewards
end

--- 计算玩家变量加成（从BaseUntils迁移过来）
---@param player MPlayer 玩家对象
---@param baseValue number 基础操作数值
---@param variableBonuses table 玩家变量加成列表
---@param targetVariable string|nil 目标变量名称（用于匹配加成，nil表示应用所有加成）
---@return number, string finalValue, bonusInfo
function BonusManager.CalculatePlayerVariableBonuses(player, baseValue, variableBonuses, targetVariable)
    if not (player and player.variableSystem and variableBonuses and type(variableBonuses) == "table" and #variableBonuses > 0) then
        return baseValue, ""
    end

    local variableSystem = player.variableSystem
    local totalFlatBonus = 0
    local totalPercentBonus = 0
    local finalMultipliers = {}
    local bonusDescriptions = {}

    for _, bonusItem in ipairs(variableBonuses) do
        local bonusVarName = bonusItem["名称"]
        local actionType = bonusItem["作用类型"]
        local targetVar = bonusItem["目标变量"] -- 检查目标变量匹配
        
        -- 如果指定了目标变量，只对匹配的变量生效
        if not (targetVariable and targetVar and targetVar ~= targetVariable) then
            if bonusVarName and actionType then
                local parsed = variableSystem:ParseVariableName(bonusVarName)
                if parsed then
                    local bonusValue = variableSystem:GetRawBonusValue(bonusVarName)
                    
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
                    end
                end
            end
        end
    end

    local finalBonusValue = totalFlatBonus + (baseValue * totalPercentBonus)
    
    -- 应用最终乘法
    for _, multiplier in ipairs(finalMultipliers) do
        finalBonusValue = finalBonusValue * multiplier
    end

    local bonusInfo = ""
    if #bonusDescriptions > 0 then
        bonusInfo = string.format("\n> 加成来源: %s.\n> 基础值: %s, 总加成: %s (固定: %s, 百分比: %s%%, 最终乘法: %d个).",
            table.concat(bonusDescriptions, ", "),
            tostring(baseValue),
            tostring(finalBonusValue),
            tostring(totalFlatBonus),
            tostring(totalPercentBonus * 100),
            #finalMultipliers
        )
    end

    return finalBonusValue, bonusInfo
end

--- 获取玩家所有类型的加成（扩展接口）
---@param player MPlayer 玩家实例
---@param bonusContext table|nil 加成上下文
---@return table 所有加成数据 {items = {}, variables = {}, buffs = {}}
function BonusManager.GetAllPlayerBonuses(player, bonusContext)

    bonusContext = bonusContext or {}
    local allBonuses = {
        items = {},
        variables = {},
        buffs = {}
    }

    -- 1. 物品加成（现有功能）
    local itemBonuses = BonusManager.CalculatePlayerItemBonuses(player)
    BonusManager.MergeBonuses(allBonuses.items, itemBonuses)

    -- 2. 变量加成（新增）
    if bonusContext.variableBonuses then
        -- 这里可以进一步处理变量加成的预计算
        allBonuses.variables = bonusContext.variableBonuses
    end

    -- 3. 临时buff加成（预留接口）
    -- local buffBonuses = BonusManager.GetPlayerBuffBonuses(player)
    -- BonusManager.MergeBonuses(allBonuses.buffs, buffBonuses)

    return allBonuses
end

--- 增强指令中的加成配置
---@param commandStr string 原始指令字符串
---@param player MPlayer 玩家实例
---@return string 增强后的指令字符串
function BonusManager.EnhanceCommandWithBonuses(commandStr, player)
    if not commandStr or not player then
        return commandStr
    end

    -- 尝试解析JSON格式的指令
    local json = require(MainStorage.Code.Untils.json) ---@type json
    local success, commandData = pcall(function()
        return json.decode(commandStr)
    end)
    
    if not success or not commandData then
        -- 解析失败，直接返回原指令
        return commandStr
    end

    -- 检查是否包含需要增强的字段
    local enhancedData = {}
    for key, value in pairs(commandData) do
        if key == "玩家变量加成" then
            -- 保持原有的玩家变量加成配置
            enhancedData[key] = value
        else
            enhancedData[key] = value
        end
    end

    -- 添加宠物/伙伴加成配置（自动获取）
    local petBonuses = BonusManager.GetPetItemBonuses(player)
    local partnerBonuses = BonusManager.GetPartnerItemBonuses(player)
    
    -- 将宠物/伙伴加成转换为变量加成格式
    local companionBonuses = {}
    
    -- 处理宠物加成
    for itemName, bonusData in pairs(petBonuses) do
        if bonusData.percentage and bonusData.percentage > 0 then
            table.insert(companionBonuses, {
                ["名称"] = "加成_百分比_" .. itemName .. "加成",
                ["作用类型"] = "单独相加",
                ["目标变量"] = "数据_固定值_" .. itemName
            })
        end
        if bonusData.fixed and bonusData.fixed > 0 then
            table.insert(companionBonuses, {
                ["名称"] = "加成_固定值_" .. itemName .. "加成",
                ["作用类型"] = "单独相加",
                ["目标变量"] = "数据_固定值_" .. itemName
            })
        end
    end
    
    -- 处理伙伴加成
    for itemName, bonusData in pairs(partnerBonuses) do
        if bonusData.percentage and bonusData.percentage > 0 then
            table.insert(companionBonuses, {
                ["名称"] = "加成_百分比_" .. itemName .. "加成",
                ["作用类型"] = "单独相加",
                ["目标变量"] = "数据_固定值_" .. itemName
            })
        end
        if bonusData.fixed and bonusData.fixed > 0 then
            table.insert(companionBonuses, {
                ["名称"] = "加成_固定值_" .. itemName .. "加成",
                ["作用类型"] = "单独相加",
                ["目标变量"] = "数据_固定值_" .. itemName
            })
        end
    end
    
    -- 合并所有加成
    if #companionBonuses > 0 then
        if not enhancedData["玩家变量加成"] then
            enhancedData["玩家变量加成"] = {}
        end
        for _, bonus in ipairs(companionBonuses) do
            table.insert(enhancedData["玩家变量加成"], bonus)
        end
    end

    -- 转换回JSON格式
    local enhancedCommandStr = json.encode(enhancedData)
    return enhancedCommandStr
end



--- 记录统一奖励计算摘要
---@param player MPlayer 玩家实例
---@param originalRewards table 原始奖励
---@param finalRewards table 最终奖励
---@param bonusContext table 加成上下文
function BonusManager.LogUnifiedRewardSummary(player, originalRewards, finalRewards, bonusContext)
    if not originalRewards or not finalRewards then
        return
    end

    local changeCount = 0
    local source = bonusContext.source or "未知来源"

    -- 统计变量奖励变化
    if originalRewards.variables and finalRewards.variables then
        for varName, originalAmount in pairs(originalRewards.variables) do
            local finalAmount = finalRewards.variables[varName]
            if finalAmount and finalAmount ~= originalAmount then
                local bonusPercent = ((finalAmount - originalAmount) / originalAmount) * 100
                --gg.log(string.format("[统一奖励] %s 变量%s: %d -> %d (+%.1f%%)", 
                --    player.name or "未知", varName, originalAmount, finalAmount, bonusPercent))
                changeCount = changeCount + 1
            end
        end
    end

    -- 统计物品奖励变化
    if originalRewards.items and finalRewards.items then
        for itemName, originalAmount in pairs(originalRewards.items) do
            local finalAmount = finalRewards.items[itemName]
            if finalAmount and finalAmount ~= originalAmount then
                local bonusPercent = ((finalAmount - originalAmount) / originalAmount) * 100
                --gg.log(string.format("[统一奖励] %s 物品%s: %d -> %d (+%.1f%%)", 
                --    player.name or "未知", itemName, originalAmount, finalAmount, bonusPercent))
                changeCount = changeCount + 1
            end
        end
    end

    if changeCount > 0 then
        --gg.log(string.format("[统一奖励] 玩家 %s 来源 '%s' 共有 %d 项奖励受到加成影响", 
        --    player.name or "未知", source, changeCount))
    else
        --gg.log(string.format("[统一奖励] 玩家 %s 来源 '%s' 无奖励受到加成影响", 
        --    player.name or "未知", source))
    end
end

-- ============================= 原有接口保持不变 =============================

--- 计算玩家所有物品加成
---@param player MPlayer 玩家实例
---@return table<string, {fixed: number, percentage: number}> 按物品目标分组的加成数据
function BonusManager.CalculatePlayerItemBonuses(player)
    if not player then
        --gg.log("错误: [BonusManager] 玩家实例为空")
        return {}
    end

    local totalBonuses = {}

    -- 1. 获取宠物加成
    local petBonuses = BonusManager.GetPetItemBonuses(player)
    BonusManager.MergeBonuses(totalBonuses, petBonuses)

    -- 2. 获取伙伴加成
    local partnerBonuses = BonusManager.GetPartnerItemBonuses(player)
    BonusManager.MergeBonuses(totalBonuses, partnerBonuses)

    -- 3. 记录加成信息
    local bonusCount = 0
    for itemName, bonusData in pairs(totalBonuses) do
        local hasBonus = (bonusData.percentage and bonusData.percentage > 0) or (bonusData.fixed and bonusData.fixed > 0)
        if hasBonus then
            local logParts = {}
            if bonusData.percentage and bonusData.percentage > 0 then
                table.insert(logParts, string.format("百分比 +%.1f%%", bonusData.percentage))
            end
            if bonusData.fixed and bonusData.fixed > 0 then
                table.insert(logParts, string.format("固定值 +%d", bonusData.fixed))
            end

            --gg.log(string.format("[BonusManager] 玩家 %s 的 %s 加成: %s",player.name or "未知", itemName, table.concat(logParts, ", ")))
            bonusCount = bonusCount + 1
        end
    end

    if bonusCount > 0 then
        --gg.log(string.format("[BonusManager] 玩家 %s 共享受 %d 种物品加成", player.name or "未知", bonusCount))
    end

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

        if (bonusData.percentage or 0) > 0 or (bonusData.fixed or 0) > 0 then
            local logMsg = string.format("[BonusManager] 奖励加成: %s %d -> %d (百分比:%.1f%%, 固定值:%d)",
                   itemName, amount, finalAmount, bonusData.percentage or 0, bonusData.fixed or 0)
            --gg.log(logMsg)
        else
            finalRewards[itemName] = amount
        end
    end

    return finalRewards
end

-- ============================= 获取加成方法 =============================

--- 获取宠物物品加成
---@param player MPlayer 玩家实例
---@return table<string, {fixed: number, percentage: number}> 宠物加成数据
function BonusManager.GetPetItemBonuses(player)
    if not player or not player.uin then
        return {}
    end

    local bonuses = PetMgr.GetActiveItemBonuses(player.uin)

    if bonuses and next(bonuses) then
        --gg.log(string.format("[BonusManager] 获取到玩家 %s 的宠物加成", player.name or "未知"))
    end

    return bonuses or {}
end

--- 获取伙伴物品加成
---@param player MPlayer 玩家实例
---@return table<string, {fixed: number, percentage: number}> 伙伴加成数据
function BonusManager.GetPartnerItemBonuses(player)
    if not player or not player.uin then
        return {}
    end

    local bonuses = PartnerMgr.GetActiveItemBonuses(player.uin)

    if bonuses and next(bonuses) then
        --gg.log(string.format("[BonusManager] 获取到玩家 %s 的伙伴加成", player.name or "未知"))
    end

    return bonuses or {}
end

-- ============================= 工具方法 =============================

--- 合并加成数据
---@param target table<string, {fixed: number, percentage: number}> 目标加成表
---@param source table<string, {fixed: number, percentage: number}> 源加成表
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
    end
end



return BonusManager