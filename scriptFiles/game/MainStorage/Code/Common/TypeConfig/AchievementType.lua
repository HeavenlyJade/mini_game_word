-- AchievementType.lua
-- 成就类型类 - 封装成就的元数据和行为逻辑

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local AchievementRewardCal = require(MainStorage.Code.GameReward.RewardCalc.AchievementRewardCal) ---@type AchievementRewardCal

---@class LevelEffect
---@field 效果类型 string 效果类型（如“玩家变量”）
---@field 效果字段名称 string 效果字段名称（如“加成_百分比_双倍训练”）
---@field 基础数值 number 基础数值
---@field 效果数值 string 效果数值公式（如“T_LVL*0.2”）
---@field 效果描述 string 效果描述
---@field 等级 number|nil 适用等级，可选

---@class UpgradeCondition
---@field 消耗物品 string 物品名称
---@field 消耗数量 string 消耗数量公式（如“T_LVL*2+10”）

---@class AchievementType : Class
---@field id string 成就唯一ID
---@field name string 成就名称
---@field type string 成就类型 ("普通成就" 或 "天赋成就")
---@field description string 成就描述
---@field icon string 成就图标路径
---@field unlockConditions table[] 解锁条件列表
---@field unlockRewards table[] 解锁奖励列表
---@field maxLevel number|nil 最大等级 (天赋成就专用)
---@field upgradeConditions UpgradeCondition[]|nil 升级条件列表 (天赋成就专用)
---@field costConfigName string|nil 消耗配置名称，关联到ActionCostConfig
---@field actionCostType ActionCostType|nil 对应的消耗配置实例
---@field levelEffects LevelEffect[]|nil 等级效果列表 (天赋成就专用)
local AchievementType = ClassMgr.Class("AchievementType")

--- 初始化成就类型
---@param data table 配置数据
function AchievementType:OnInit(data)
   local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)
   -- 基本信息
   self.id = data["名字"]
   self.name = data["名字"]
   self.type = data["类型"] or "普通成就"
   self.description = data["描述"] or ""
   self.icon = data["图标"] or ""
   self.sort = data["排序"] or 1
   -- 解锁相关
   self.unlockConditions = data["解锁条件"] or {}
   self.unlockRewards = data["解锁奖励"] or {}

   -- 天赋成就专用字段
   self.maxLevel = data["最大等级"]
   self.upgradeConditions = data["升级条件"]
   self.levelEffects = data["等级效果"]
   self.costConfigName = data["消耗配置"]
   if self.costConfigName then
       self.actionCostType = ConfigLoader.GetActionCost(self.costConfigName)
   else
       self.actionCostType = nil
   end
end

--- 是否为天赋成就
---@return boolean
function AchievementType:IsTalentAchievement()
   return self.type == "天赋成就" and self.maxLevel ~= nil
end

--- 是否为普通成就
---@return boolean
function AchievementType:IsNormalAchievement()
   return self.type == "普通成就" or self.maxLevel == nil
end

--- 获取最大等级
---@return number
function AchievementType:GetMaxLevel()
   return self.maxLevel or 1
end

--- 获取指定等级的效果
---@param level number 等级
---@return table|nil 效果配置
function AchievementType:GetLevelEffect(level)
   if not self.levelEffects then
       return nil
   end

   for _, effect in ipairs(self.levelEffects) do
       if effect["等级"] == level or not effect["等级"] then
           -- 如果没有指定等级，说明是通用效果公式
           return effect
       end
   end

   return nil
end

--- 获取等级效果数值
---@param level number 天赋等级
---@return any 计算后的效果值
function AchievementType:GetLevelEffectValue(level)
    if not self.levelEffects or #self.levelEffects == 0 then
        return nil
    end
    local effectConfig = self.levelEffects[1] -- 假设只有一个效果
    local formula = effectConfig["效果数值"]
    return AchievementRewardCal:CalculateEffectValue(formula, level, self)
end

--- 获取升级消耗
---@param currentLevel number 当前等级
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@return {item: string, amount: number}[] 消耗列表
function AchievementType:GetUpgradeCosts(currentLevel, playerData, bagData)
   local costsDict = {}

   -- 1. 处理旧的'升级条件'
   if self.upgradeConditions then
       for _, condition in ipairs(self.upgradeConditions) do
           local itemName = condition["消耗物品"]
           local costFormula = condition["消耗数量"]

           if itemName and costFormula and itemName ~= "" and costFormula ~= "" then
               local amount = self:GetUpgradeCostValue(costFormula, currentLevel)
               if amount and amount > 0 then
                   costsDict[itemName] = (costsDict[itemName] or 0) + amount
               end
           end
       end
   end

   local finalCostsArray = {}
   for name, amount in pairs(costsDict) do
       table.insert(finalCostsArray, { item = name, amount = amount })
   end

   return finalCostsArray
end

--- 获取动作消耗（专门用于天赋动作，如重生）
---@param targetLevel number 目标动作等级
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@return {item: string, amount: number}[] 消耗列表
function AchievementType:GetActionCosts(targetLevel, playerData, bagData)
    local costsDict = {}
    -- 只处理'消耗配置' (actionCostType)
    if self.actionCostType then
        local externalContext = { T_LVL = targetLevel }
        local actionCosts = self.actionCostType:GetActionCosts(playerData, bagData, externalContext)
 
        for name, amount in pairs(actionCosts) do
            costsDict[name] = (costsDict[name] or 0) + amount
        end
    end
    
    local finalCostsArray = {}
    for name, amount in pairs(costsDict) do
        table.insert(finalCostsArray, { item = name, amount = amount })
    end
 
    return finalCostsArray
end

--- 获取升级消耗数值
---@param formula string 消耗公式
---@param level number 当前等级
---@return number|nil 消耗数量
function AchievementType:GetUpgradeCostValue(formula, level)
    return AchievementRewardCal:CalculateUpgradeCost(formula, level, self)
end



return AchievementType

