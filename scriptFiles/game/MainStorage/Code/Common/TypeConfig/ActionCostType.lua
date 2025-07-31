-- ActionCostType.lua
-- 定义了成本和通用计算配置的数据结构

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local ActionCosteRewardCal = require(MainStorage.Code.GameReward.RewardCalc.ActionCosteRewardCal) ---@type ActionCosteRewardCal
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class CostSegment
---@field Condition string | nil 条件表达式
---@field Formula string | number 公式或固定值

---@class CostItem
---@field CostType string 消耗类型 (例如 "玩家变量"，玩家属性，物品)
---@field Name string 消耗名称 (例如 "数据_固定值_战力值")
---@field Segments CostSegment[] 数量分段

---@class TargetItem
---@field TargetType string 目标类型 (例如 "玩家变量", "玩家属性")
---@field TargetName string 目标名称 (例如 "加成_百分比_双倍训练")
---@field EffectValue string|number 作用数值 (可以是公式字符串或纯粹数值)

---@class ActionCostType : Class
---@field CostList CostItem[] 消耗列表
---@field TargetList TargetItem[] 作用目标列表
local ActionCostType = ClassMgr.Class("ActionCostType")

--- 初始化
---@param configData table<string, any> 从 ActionCostConfig.lua 中读取的单条原始配置数据
function ActionCostType:OnInit(configData)
    self.CostList = {}
    self.TargetList = {}

    -- 解析消耗列表
    local rawCostList = configData['消耗列表'] or {}
    for _, costItemData in ipairs(rawCostList) do
        local segments = {}
        local rawSegments = costItemData['数量分段'] or {}
        for _, segmentData in ipairs(rawSegments) do
            table.insert(segments, {
                Condition = segmentData['条件'],
                Formula = segmentData['公式']
            })
        end

        ---@type CostItem
        local costItem = {
            CostType = costItemData['消耗类型'],
            Name = costItemData['消耗名称'],
            Segments = segments
        }
        table.insert(self.CostList, costItem)
    end

    -- 解析作用目标列表
    local rawTargetList = configData['作用目标列表'] or {}
    --gg.log("rawTargetList",rawTargetList)
    for _, targetItemData in ipairs(rawTargetList) do
        ---@type TargetItem
        local targetItem = {
            TargetType = targetItemData['目标类型'],
            TargetName = targetItemData['目标名称'],
            EffectValue = targetItemData['作用数值']
        }
        table.insert(self.TargetList, targetItem)
    end
end

--- 获取动态计算后的成本列表
---@param playerData table 玩家数据，包含变量、属性等信息
---@param bagData table 背包数据，包含物品信息
---@param externalContext table|nil 外部上下文，例如 { T_LVL = 5 }
---@return table<string, number> 消耗名称 -> 数量的映射表
function ActionCostType:GetActionCosts(playerData, bagData, externalContext)
    return ActionCosteRewardCal:CalculateCosts(self, playerData, bagData, externalContext)
end

--- 获取作用目标列表
---@return TargetItem[]
function ActionCostType:GetTargetList()
    return self.TargetList
end

--- 计算单个目标的作用数值
---@param targetItem TargetItem 目标项
---@return number 计算出的作用数值
function ActionCostType:CalculateEffectValue(targetItem)
    if not targetItem or not targetItem.EffectValue then
        return 0
    end

    if type(targetItem.EffectValue) == "string" then
        -- 公式字符串，使用gg.eval计算
        return gg.eval(targetItem.EffectValue) or 0
    else
        -- 纯粹数值，直接使用
        return targetItem.EffectValue or 0
    end
end

--- 应用效果到玩家
---@param targetItem TargetItem 目标项
---@param player MPlayer 玩家对象
---@param playerId string 玩家ID
---@param executionCount number/nil 执行次数
---@return boolean 是否成功应用
function ActionCostType:ApplyEffectToPlayer(targetItem, player, playerId, executionCount)
    --gg.log("作用的目标相关名称字段", targetItem,targetItem.TargetName, player, playerId, executionCount)
    if not targetItem or not player then
        return false
    end
    if not executionCount then
        executionCount = 1
    end

    -- 计算单次作用数值
    local singleEffectValue = self:CalculateEffectValue(targetItem)
    -- 计算最终作用数值 = 单次效果值 × 执行次数
    local finalEffectValue = singleEffectValue * executionCount

    if targetItem.TargetType == "玩家变量" then
        -- 应用最终效果值到玩家变量系统
        player.variableSystem:ApplyVariableValue(targetItem.TargetName, finalEffectValue, "天赋动作")
        --gg.log(string.format("成功为玩家 %s 的变量 %s 应用了效果 %s (单次:%s × 次数:%s)",playerId, targetItem.TargetName, finalEffectValue, singleEffectValue, executionCount))
        return true
    elseif targetItem.TargetType == "玩家属性" then
        -- TODO: 玩家属性系统还未实现，需要后续开发
        --gg.log(string.format("警告：玩家属性系统还未实现，无法应用效果到 %s", targetItem.TargetName))
        return false
    else
        --gg.log(string.format("警告：未知的目标类型 %s，目标名称 %s", targetItem.TargetType, targetItem.TargetName))
        return false
    end
end

--- 应用所有目标效果
---@param player MPlayer 玩家对象
---@param playerId string 玩家ID
---@param executionCount number 执行次数
---@return number 成功应用的效果数量
function ActionCostType:ApplyAllEffects(player, playerId,executionCount)
    if not self.TargetList or #self.TargetList == 0 then
        return 0
    end

    local successCount = 0
    --gg.log("self.TargetList",self.TargetList)
    for _, targetItem in ipairs(self.TargetList) do
        --gg.log("作用的目标相关名称字段", targetItem,targetItem.TargetName, player, playerId, executionCount)
        if self:ApplyEffectToPlayer(targetItem, player, playerId,executionCount) then
            successCount = successCount + 1
        end
    end

    return successCount
end

--- 获取指定消耗名称的消耗类型
---@param costName string 消耗名称
---@return string|nil 消耗类型，如果未找到则返回 nil
function ActionCostType:GetCostTypeByName(costName)
    if not self.CostList or not costName then
        return nil
    end
    for _, costItem in ipairs(self.CostList) do
        if costItem.Name == costName then
            return costItem.CostType
        end
    end

    return nil
end

return ActionCostType
