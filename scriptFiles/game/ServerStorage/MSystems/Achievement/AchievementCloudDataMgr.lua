-- AchievementCloudDataMgr.lua
-- 成就云数据管理器 - 简单的数据保存和读取

local cloudService = game:GetService("CloudService") ---@type CloudService
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class AchievementCloudDataMgr
local AchievementCloudDataMgr = {
    -- 云存储key配置
    CLOUD_KEY_PREFIX = "achievement_data_new", -- 成就数据key前缀
}

---@class AchievementData 单个成就/天赋数据
---@field achievementId string 成就/天赋ID标识符
---@field unlockTime number 解锁时间戳
---@field currentLevel number 当前等级（天赋为实际等级，普通成就固定为1）

---@alias AchievementDataTable table<string, AchievementData> 玩家成就数据表，键为成就ID，值为成就详情
---@
---@
--- 从云端加载玩家成就数据
---@param playerId number 玩家ID
---@return boolean, table|nil 是否成功，成就数据
function AchievementCloudDataMgr.LoadPlayerAchievements(playerId)
    if not playerId then
        --gg.log("无效的玩家ID:", playerId)
        return false, nil
    end

    local key = AchievementCloudDataMgr.CLOUD_KEY_PREFIX .. playerId
    local success, cloudData = cloudService:GetTableOrEmpty(key)

    if success and cloudData and cloudData.achievements then
        --gg.log("成功加载玩家成就数据:", playerId)
        return true, cloudData.achievements
    else
        --gg.log("玩家成就数据为空或加载失败:", playerId)
        return false, nil
    end
end

--- 保存玩家成就数据到云端
---@param playerId number 玩家ID
---@param saveData AchievementDataTable 成就数据
---@param force boolean|nil 是否强制保存
---@return boolean 是否成功
function AchievementCloudDataMgr.SavePlayerAchievements(playerId, saveData, force)
    if not playerId then
        --gg.log("无效的玩家ID:", playerId)
        return false
    end

    if not saveData then
        --gg.log("保存成就数据失败：数据为空", playerId)
        return false
    end

    local cloudData = {
        uin = playerId,
        achievements = saveData,
        lastUpdate = os.time()
    }

    local key = AchievementCloudDataMgr.CLOUD_KEY_PREFIX .. playerId

    cloudService:SetTableAsync(key, cloudData, function(success)
        if success then
            -- --gg.log("成功保存玩家成就数据:", playerId)
        else
            --gg.log("保存玩家成就数据失败:", playerId)
        end
    end)

    return true
end

--- 清空玩家成就数据
---@param playerId number 玩家ID
---@return boolean 是否成功
function AchievementCloudDataMgr.ClearPlayerAchievements(playerId)
    if not playerId then
        --gg.log("无效的玩家ID:", playerId)
        return false
    end

    local key = AchievementCloudDataMgr.CLOUD_KEY_PREFIX .. playerId

    cloudService:SetTableAsync(key, {}, function(success)
        if success then
            --gg.log("成功删除玩家成就数据:", playerId)
        else
            --gg.log("删除玩家成就数据失败:", playerId)
        end
    end)

    return true
end

return AchievementCloudDataMgr
