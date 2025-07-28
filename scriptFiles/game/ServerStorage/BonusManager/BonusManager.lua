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

-- ============================= 主要接口方法 =============================

--- 计算玩家所有物品加成
---@param player MPlayer 玩家实例
---@return table<string, {fixed: number, percentage: number}> 按物品目标分组的加成数据
function BonusManager.CalculatePlayerItemBonuses(player)
    if not player then
        gg.log("错误: [BonusManager] 玩家实例为空")
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

            gg.log(string.format("[BonusManager] 玩家 %s 的 %s 加成: %s",
                   player.name or "未知", itemName, table.concat(logParts, ", ")))
            bonusCount = bonusCount + 1
        end
    end

    if bonusCount > 0 then
        gg.log(string.format("[BonusManager] 玩家 %s 共享受 %d 种物品加成",
               player.name or "未知", bonusCount))
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
            gg.log(logMsg)
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
        gg.log(string.format("[BonusManager] 获取到玩家 %s 的宠物加成", player.name or "未知"))
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
        gg.log(string.format("[BonusManager] 获取到玩家 %s 的伙伴加成", player.name or "未知"))
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

--- 验证玩家实例
---@param player any 玩家对象
---@return boolean 是否为有效玩家
function BonusManager.ValidatePlayer(player)
    if not player then
        gg.log("错误: [BonusManager] 玩家实例为空")
        return false
    end

    if not player.uin then
        gg.log("错误: [BonusManager] 玩家UIN无效")
        return false
    end

    return true
end

--- 记录加成应用详情
---@param player MPlayer 玩家实例
---@param originalRewards table<string, number> 原始奖励
---@param finalRewards table<string, number> 最终奖励
function BonusManager.LogBonusApplication(player, originalRewards, finalRewards)
    if not originalRewards or not finalRewards then
        return
    end

    local changedItems = 0
    for itemName, originalAmount in pairs(originalRewards) do
        local finalAmount = finalRewards[itemName]
        if finalAmount and finalAmount ~= originalAmount then
            local bonusPercent = ((finalAmount - originalAmount) / originalAmount) * 100
            gg.log(string.format("[BonusManager] %s %s奖励: %d -> %d (+%.1f%%)",
                   player.name or "未知", itemName, originalAmount, finalAmount, bonusPercent))
            changedItems = changedItems + 1
        end
    end

    if changedItems > 0 then
        gg.log(string.format("[BonusManager] 玩家 %s 共有 %d 种物品奖励受到加成影响",
               player.name or "未知", changedItems))
    else
        gg.log(string.format("[BonusManager] 玩家 %s 本次无物品奖励受到加成影响",
               player.name or "未知"))
    end
end

return BonusManager
