-- AchievementCloudDataMgr.lua
-- 成就云数据管理器 - 简单的数据保存和读取

local cloudService = game:GetService("CloudService") ---@type CloudService
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class AchievementCloudDataMgr
local AchievementCloudDataMgr = {}

--- 从云端加载玩家成就数据
---@param playerId string 玩家ID
---@return boolean, table|nil 是否成功，成就数据
function AchievementCloudDataMgr.LoadPlayerAchievements(playerId)
    local uin = tonumber(playerId)
    if not uin then
        gg.log("无效的玩家ID:", playerId)
        return false, nil
    end
    
    local key = "achievement_data_" .. uin
    local success, cloudData = cloudService:GetTableOrEmpty(key)
    
    if success and cloudData and cloudData.achievements then
        gg.log("成功加载玩家成就数据:", playerId)
        return true, cloudData.achievements
    else
        gg.log("玩家成就数据为空或加载失败:", playerId)
        return false, nil
    end
end

--- 保存玩家成就数据到云端
---@param playerId string 玩家ID
---@param saveData table 成就数据
---@param force boolean|nil 是否强制保存
---@return boolean 是否成功
function AchievementCloudDataMgr.SavePlayerAchievements(playerId, saveData, force)
    local uin = tonumber(playerId)
    if not uin then
        gg.log("无效的玩家ID:", playerId)
        return false
    end
    
    if not saveData then
        gg.log("保存成就数据失败：数据为空", playerId)
        return false
    end
    
    local cloudData = {
        uin = uin,
        achievements = saveData,
        lastUpdate = os.time()
    }
    
    local key = "achievement_data_" .. uin
    
    cloudService:SetTableAsync(key, cloudData, function(success)
        if success then
            gg.log("成功保存玩家成就数据:", playerId)
        else
            gg.log("保存玩家成就数据失败:", playerId)
        end
    end)
    
    return true
end

--- 清空玩家成就数据
---@param playerId string 玩家ID
---@return boolean 是否成功
function AchievementCloudDataMgr.ClearPlayerAchievements(playerId)
    local uin = tonumber(playerId)
    if not uin then
        gg.log("无效的玩家ID:", playerId)
        return false
    end
    
    local key = "achievement_data_" .. uin
    
    cloudService:SetTableAsync(key, nil, function(success)
        if success then
            gg.log("成功删除玩家成就数据:", playerId)
        else
            gg.log("删除玩家成就数据失败:", playerId)
        end
    end)
    
    return true
end

return AchievementCloudDataMgr