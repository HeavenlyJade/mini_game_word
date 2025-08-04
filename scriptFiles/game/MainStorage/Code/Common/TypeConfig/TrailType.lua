-- /TypeConfig/TrailType.lua

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class TrailType:Class
---@field name string 尾迹名称
---@field description string 尾迹描述
---@field displayName string 显示名称
---@field rarity string 稀有度
---@field carryingEffects table 携带效果列表
---@field imageResource string| nil 图片资源
---@field effectNode string| nil 特效节点
---@field New fun(data:table):TrailType
local TrailType = ClassMgr.Class("TrailType")

function TrailType:OnInit(data)
    -- 基础信息
    self.name = data["名称"] or "未知尾迹"
    self.description = data["描述"] or ""
    self.displayName = data["显示名"] or self.name
    self.rarity = data["稀有度"] or "N"

    -- 携带效果
    self.carryingEffects = data["携带效果"] or {}

    -- 资源配置
    self.imageResource = data["图片资源"] or nil
    self.effectNode = data["特效节点"] or nil
end

-- 便利函数：获取特效节点
function TrailType:GetEffectNode()
    return self.effectNode
end

-- 便利函数：获取指定星级的携带效果
function TrailType:GetCarryingEffectsByStarLevel(starLevel)
    local effects = {}
    for _, effect in ipairs(self.carryingEffects) do
        if effect["星级"] == starLevel then
            table.insert(effects, effect)
        end
    end
    return effects
end

--- 计算携带效果的显示数值
---@param starLevel number 星级
---@return table<string, table> 计算后的效果列表，格式：{变量名称: {描述: string, 数值: number, isPercentage: boolean}}
function TrailType:CalculateCarryingEffectsByStarLevel(starLevel)
    local calculatedEffects = {}

    -- 获取尾迹公式计算器
    local RewardManager = require(game.MainStorage.Code.GameReward.RewardManager)
    local calculator = RewardManager.GetCalculator("宠物公式")

    if not calculator then
        --gg.log("错误: 无法获取尾迹公式计算器")
        return calculatedEffects
    end

    for _, effect in ipairs(self.carryingEffects) do
        local variableType = effect["变量类型"] or ""
        local variableName = effect["变量名称"] or ""
        local effectValue = effect["效果数值"] or ""
        local bonusType = effect["加成类型"]
        local itemTarget = effect["物品目标"]
        local targetVariable = effect["目标变量"]
        local actionType = effect["作用类型"]

        if variableName ~= "" and effectValue ~= "" then
            -- 使用RewardCalc计算公式
            local calculatedValue = calculator:CalculateEffectValue(effectValue, starLevel, 1, self)

            if calculatedValue then
                -- 【修复】添加 isPercentage 标志位
                local isPercentage = string.find(variableName, "百分比") ~= nil

                calculatedEffects[variableName] = {
                    -- 【修复】传递 isPercentage 标志给格式化函数
                    description = self:FormatEffectDescription(variableName, calculatedValue, isPercentage),
                    value = calculatedValue, -- 存储原始计算值
                    isPercentage = isPercentage, -- 新增标志位
                    originalFormula = effectValue,
                    bonusType = bonusType,
                    itemTarget = itemTarget,
                    targetVariable = targetVariable, -- 新增目标变量字段
                    actionType = actionType -- 新增作用类型字段
                }
            end
        end
    end

    return calculatedEffects
end

--- 格式化效果描述
---@param variableName string 变量名称
---@param value number 计算后的数值
---@param isPercentage boolean 是否为百分比
---@return string 格式化后的描述
function TrailType:FormatEffectDescription(variableName, value, isPercentage)
    local cleanName = variableName:gsub("加成_百分比_", ""):gsub("属性_固定值_", ""):gsub("_", " ")

    if isPercentage then
        -- 【修复】对于百分比，将原始值(如16.5)乘以100用于显示
        return string.format("%s: +%.0f%%", cleanName, value * 100)
    else
        -- 【修复】对于固定值，直接显示
        return string.format("%s: +%.0f", cleanName, value)
    end
end

return TrailType 