-- AchievementCloudDataMgr.lua
-- 成就云数据管理器 - 专门负责云端数据的读取和存储

local cloudService = game:GetService("CloudService") ---@type CloudService
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class AchievementCloudDataMgr
local AchievementCloudDataMgr = {}

-- 数据结构定义 --------------------------------------------------------

---@class PlayerAchievementCloudData 玩家成就云端数据结构
---@field uin number 玩家ID
---@field achievements table<string, AchievementCloudData> 成就数据映射表
---@field statistics AchievementStatistics 统计数据
---@field lastUpdate number 最后更新时间戳

---@class AchievementCloudData 单个成就的云端数据
---@field unlocked boolean 是否已解锁
---@field unlockTime number|nil 解锁时间戳
---@field currentLevel number|nil 当前等级（天赋成就专用，普通成就为nil或者0）
---@field progress table|nil 成就进度数据（自定义结构）
---@field lastUpdateTime number 最后更新时间戳

---@class AchievementStatistics 成就统计数据
---@field totalUnlocked number 已解锁成就总数
---@field totalAchievementPoints number 总成就点数
---@field lastUnlockTime number 最后解锁时间戳
---@field totalTalentLevels number 天赋成就总等级数

-- 云端数据操作 --------------------------------------------------------

--- 从云端加载玩家成就数据
---@param uin number 玩家ID
---@return boolean, PlayerAchievementCloudData|nil 是否成功，成就数据
function AchievementCloudDataMgr:LoadPlayerAchievementData(uin)
   local key = "achievement_data_" .. uin
   local success, cloudData = cloudService:GetTableOrEmpty(key)
   
   if success then
       gg.log("成功加载玩家成就数据:", uin)
       return true, cloudData
   else
       gg.log("加载玩家成就数据失败:", uin)
       return false, nil
   end
end

--- 保存玩家成就数据到云端
---@param uin number 玩家ID
---@param data PlayerAchievementCloudData 成就数据
---@return boolean 是否成功
function AchievementCloudDataMgr:SavePlayerAchievementData(uin, data)
   if not data then
       gg.log("保存成就数据失败：数据为空", uin)
       return false
   end
   
   local key = "achievement_data_" .. uin
   
   cloudService:SetTableAsync(key, data, function(success)
       if success then
           gg.log("成功保存玩家成就数据:", uin)
       else
           gg.log("保存玩家成就数据失败:", uin)
       end
   end)
   
   return true
end

--- 检查玩家成就数据是否存在
---@param uin number 玩家ID
---@return boolean 数据是否存在
function AchievementCloudDataMgr:HasPlayerAchievementData(uin)
   local key = "achievement_data_" .. uin
   local success, cloudData = cloudService:GetTableOrEmpty(key)
   
   return success and cloudData ~= nil and next(cloudData) ~= nil
end

--- 删除玩家成就数据（管理用途）
---@param uin number 玩家ID
---@return boolean 是否成功
function AchievementCloudDataMgr:DeletePlayerAchievementData(uin)
   local key = "achievement_data_" .. uin
   
   cloudService:SetTableAsync(key, nil, function(success)
       if success then
           gg.log("成功删除玩家成就数据:", uin)
       else
           gg.log("删除玩家成就数据失败:", uin)
       end
   end)
   
   return true
end

return AchievementCloudDataMgr