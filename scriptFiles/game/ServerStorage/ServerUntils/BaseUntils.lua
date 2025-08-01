-- BaseUntils.lua
-- 提供服务器端通用的基础工具函数

local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")
local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg


---@class BaseUntils
local BaseUntils = {}

--- 检查玩家是否拥有足够的资源来支付给定的消耗列表，不执行扣除。
---@param player MPlayer 玩家对象
---@param costs table 消耗列表，每个元素需要包含 { item = string, amount = number, costType = string }
---@return boolean 是否有足够的资源
function BaseUntils.CheckCosts(player, costs)
    if not player or not costs or #costs == 0 then
        return true -- 没有玩家或没有消耗，视为检查通过
    end

    local itemCosts = {}
    local variableCosts = {}

    -- 1. 将消耗按类型分类
    for _, cost in ipairs(costs) do
        local costType = cost.costType
        if costType == "玩家变量" then
            table.insert(variableCosts, cost)
        elseif costType == "玩家属性" then
            --gg.log(string.format("跳过检查'玩家属性'类型消耗: %s", cost.item))
        else -- 默认为 "背包" 物品
            table.insert(itemCosts, cost)
        end
    end

    -- 2. 检查背包物品
    if #itemCosts > 0 then
        if not BagMgr.HasItemsByCosts(player, itemCosts) then
            --gg.log("检查失败：背包物品不足。", itemCosts)
            return false
        end
    end

    -- 3. 检查玩家变量
    if #variableCosts > 0 then
        if not player.variableSystem then
            --gg.log("错误：玩家对象缺少 'variableSystem'，无法检查变量消耗。")
            return false
        end
        for _, cost in ipairs(variableCosts) do
            local currentAmount = player.variableSystem:GetVariable(cost.item) or 0
            if currentAmount < cost.amount then
                --gg.log(string.format("检查失败：玩家变量 '%s' 不足。需要: %d, 当前: %d", cost.item, cost.amount, currentAmount))
                return false
            end
        end
    end

    return true
end

--- 仅扣除消耗，不进行检查。
---@param player MPlayer 玩家对象
---@param costs table 消耗列表
---@return boolean 是否成功扣除
function BaseUntils.DeductCosts(player, costs)
    --gg.log("进入 BaseUntils.DeductCosts，收到的消耗列表:", costs)

    if not costs or #costs == 0 then
        --gg.log("消耗列表为空，直接返回成功。")
        return true -- 没有消耗，直接成功
    end

    local itemCosts = {}
    local variableCosts = {}

    -- 1. 将消耗按类型分类
    for _, cost in ipairs(costs) do
        local costType = cost.costType
        if costType == "玩家变量" then
            table.insert(variableCosts, cost)
        elseif costType == "玩家属性" then
            --gg.log(string.format("搁置处理'玩家属性'类型消耗: %s，数量: %s。不执行扣除。", cost.item, tostring(cost.amount)))
        else -- 默认为 "背包" 物品
            table.insert(itemCosts, cost)
        end
    end

    --gg.log("分类后的背包消耗:", itemCosts)
    --gg.log("分类后的变量消耗:", variableCosts)

    -- 2. 扣除背包物品
    if #itemCosts > 0 then
        --gg.log("开始扣除背包物品...")
        if not BagMgr.RemoveItemsByCosts(player, itemCosts) then
            --gg.log("错误：扣除背包物品失败。", itemCosts)
            return false -- 扣除失败
        end
        --gg.log("背包物品扣除完成。")
    end

    -- 3. 扣除玩家变量
    if #variableCosts > 0 then
        if not player.variableSystem then
            --gg.log("错误：玩家对象缺少 'variableSystem'，无法扣除变量消耗。")
            return false
        end
        --gg.log("开始扣除玩家变量...")
        for _, cost in ipairs(variableCosts) do
            local originalValue = player.variableSystem:GetVariable(cost.item)
            --gg.log(string.format("准备扣除玩家变量: %s, 当前值: %s, 计划扣除: %s", cost.item, tostring(originalValue), cost.amount))
            player.variableSystem:SubtractVariable(cost.item, cost.amount)
            local newValue = player.variableSystem:GetVariable(cost.item)
            --gg.log(string.format("扣除后玩家变量: %s, 新值: %s", cost.item, tostring(newValue)))
        end
        --gg.log("玩家变量扣除完成。")
    end

    --gg.log("所有消耗已成功扣除。")
    return true
end

--- 计算玩家变量加成
---@param player MPlayer 玩家对象
---@param baseValue number 基础操作数值
---@param variableBonuses table 玩家变量加成列表
---@return number, string totalBonusValue, bonusInfoString
function BaseUntils.CalculateBonuses(player, baseValue, variableBonuses)
    if not (player and player.variableSystem and variableBonuses and type(variableBonuses) == "table" and #variableBonuses > 0) then
        return 0, ""
    end

    local variableSystem = player.variableSystem
    local totalFlatBonus = 0
    local totalPercentBonus = 0
    local finalMultipliers = {}
    local bonusDescriptions = {}

    for _, bonusItem in ipairs(variableBonuses) do
        local bonusVarName = bonusItem["名称"]
        local actionType = bonusItem["作用类型"]
        
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

return BaseUntils
