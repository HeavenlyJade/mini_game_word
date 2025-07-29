-- ActionCostType.lua
-- 定义了成本和通用计算配置的数据结构

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local ActionCosteRewardCal = require(MainStorage.Code.GameReward.RewardCalc.ActionCosteRewardCal) ---@type ActionCosteRewardCal

---@class CostSegment
---@field Condition string | nil 条件表达式
---@field Formula string | number 公式或固定值

---@class CostItem
---@field CostType string 消耗类型 (例如 "玩家变量")
---@field Source string 变量来源
---@field Name string 消耗名称 (例如 "数据_固定值_战力值")
---@field Segments CostSegment[] 数量分段

---@class ActionCostType : Class
---@field CostList CostItem[] 消耗列表
local ActionCostType = ClassMgr.Class("ActionCostType")

--- 初始化
---@param configData table<string, any> 从 ActionCostConfig.lua 中读取的单条原始配置数据
function ActionCostType:OnInit(configData)
    self.CostList = {}

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
            Source = costItemData['变量来源'],
            Name = costItemData['消耗名称'],
            Segments = segments
        }
        table.insert(self.CostList, costItem)
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

return ActionCostType