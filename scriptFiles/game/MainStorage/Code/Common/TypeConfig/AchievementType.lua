-- AchievementType.lua
-- 成就类型类 - 封装成就的元数据和行为逻辑

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class AchievementType : Class
---@field id string 成就唯一ID
---@field name string 成就名称
---@field type string 成就类型 ("普通成就" 或 "天赋成就")
---@field description string 成就描述
---@field icon string 成就图标路径
---@field unlockConditions table[] 解锁条件列表
---@field unlockRewards table[] 解锁奖励列表
---@field maxLevel number|nil 最大等级 (天赋成就专用)
---@field upgradeConditions table[]|nil 升级条件列表 (天赋成就专用)
---@field levelEffects table[]|nil 等级效果列表 (天赋成就专用)
local AchievementType = ClassMgr.Class("AchievementType")

--- 初始化成就类型
---@param data table 配置数据
function AchievementType:OnInit(data)
   -- 基本信息
   self.id = data["名字"]
   self.name = data["名字"]
   self.type = data["类型"] or "普通成就"
   self.description = data["描述"] or ""
   self.icon = data["图标"] or ""
   
   -- 解锁相关
   self.unlockConditions = data["解锁条件"] or {}
   self.unlockRewards = data["解锁奖励"] or {}
   
   -- 天赋成就专用字段
   self.maxLevel = data["最大等级"]
   self.upgradeConditions = data["升级条件"]
   self.levelEffects = data["等级效果"]
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

--- 计算等级效果数值
---@param level number 天赋等级
---@param effectConfig table 效果配置
---@return any 计算后的效果值
function AchievementType:CalculateEffectValue(level, effectConfig)
   local formula = effectConfig["效果数值"]
   if not formula then
       return 0
   end
   
   -- 如果是数值，直接返回
   if type(formula) == "number" then
       return formula
   end
   
   -- 如果是公式字符串，进行计算
   if type(formula) == "string" then
       return self:EvaluateEffectFormula(formula, level)
   end
   
   return 0
end

--- 计算效果公式
---@param formula string 公式字符串
---@param level number 天赋等级
---@return number 计算结果
function AchievementType:EvaluateEffectFormula(formula, level)
   -- 将 T_LVL 替换为实际等级
   local expression = string.gsub(formula, "T_LVL", tostring(level))
   
   -- 使用 load 函数安全地执行表达式
   local func = load("return " .. expression)
   if func then
       local success, result = pcall(func)
       if success and type(result) == "number" then
           return math.floor(result)
       else
           gg.log("效果公式计算失败:", formula, "错误:", result)
       end
   else
       gg.log("效果公式解析失败:", formula)
   end
   
   return 0
end

--- 获取升级消耗
---@param currentLevel number 当前等级
---@return table[] 消耗列表
function AchievementType:GetUpgradeCosts(currentLevel)
   if not self.upgradeConditions then
       return {}
   end
   
   local costs = {}
   for _, condition in ipairs(self.upgradeConditions) do
       local itemName = condition["消耗物品"]
       local costFormula = condition["消耗数量"]
       
       if itemName and costFormula and itemName ~= "" and costFormula ~= "" then
           local amount = self:CalculateUpgradeCost(costFormula, currentLevel)
           if amount > 0 then
               table.insert(costs, {
                   item = itemName,
                   amount = amount
               })
           end
       end
   end
   
   return costs
end

--- 计算升级消耗数量
---@param formula string 消耗公式
---@param level number 当前等级
---@return number 消耗数量
function AchievementType:CalculateUpgradeCost(formula, level)
   -- 将 T_LVL 替换为实际等级
   local expression = string.gsub(formula, "T_LVL", tostring(level))
   
   -- 使用 load 函数安全地执行表达式
   local func = load("return " .. expression)
   if func then
       local success, result = pcall(func)
       if success and type(result) == "number" then
           return math.floor(result)
       else
           gg.log("升级消耗公式计算失败:", formula, "错误:", result)
       end
   else
       gg.log("升级消耗公式解析失败:", formula)
   end
   
   return 0
end



return AchievementType