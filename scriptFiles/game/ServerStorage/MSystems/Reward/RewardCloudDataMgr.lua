--- 奖励系统云数据管理器
--- 负责奖励数据的云存储读取、保存和格式转换
--- V109 miniw-haima

local print        = print
local setmetatable = setmetatable
local math         = math
local game         = game
local pairs        = pairs
local os           = os
local SandboxNode  = SandboxNode ---@type SandboxNode

local MainStorage   = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local cloudService = game:GetService("CloudService") ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local CONST_CLOUD_SAVE_TIME = 30 -- 每30秒存盘一次

---@class RewardCloudData
---@field version number 数据版本号
---@field lastSaveTime number 最后保存时间戳
---@field online table 在线奖励数据
---@field daily table 七日登录数据
---@field activity table 活动奖励数据
---@field exchange table 兑换数据

---@class RewardCloudDataMgr
local RewardCloudDataMgr = {
    last_time_reward = 0, -- 最后一次奖励数据存盘时间
}

-- 读取玩家的奖励数据
---@param uin number 玩家ID
---@return number, RewardCloudData 返回值: 0表示成功, 1表示失败, 奖励数据
function RewardCloudDataMgr.ReadPlayerRewardData(uin)
    local ret_, ret2_ = cloudService:GetTableOrEmpty('reward_' .. uin)
    print("读取玩家奖励数据", 'reward_' .. uin, ret_, ret2_)

    if ret_ then
        if ret2_ and ret2_.version then
            -- 检查版本兼容性
            if ret2_.version and ret2_.version < 1 then
                ret2_ = RewardCloudDataMgr.MigrateData(ret2_)
            end
            --gg.log("从云端加载奖励数据成功", uin)
            return 0, ret2_
        else
            --gg.log("云端无奖励数据，已创建默认数据", uin)
            return 0, RewardCloudDataMgr.CreateDefaultData()
        end
    else
        --gg.log("读取云端奖励数据失败，为玩家创建新数据", uin)
        return 1, RewardCloudDataMgr.CreateDefaultData() -- 读取失败，返回默认数据
    end
end

-- 保存玩家奖励数据
---@param uin number 玩家ID
---@param rewardData RewardCloudData 奖励数据
---@param force_ boolean 是否强制保存，不检查时间间隔
function RewardCloudDataMgr.SavePlayerRewardData(uin, rewardData, force_)
    if force_ == false then
        local now_ = os.time()
        if now_ - RewardCloudDataMgr.last_time_reward < CONST_CLOUD_SAVE_TIME then
            return
        else
            RewardCloudDataMgr.last_time_reward = now_
        end
    end

    if uin and rewardData then
        -- 添加元数据
        rewardData.version = 1
        rewardData.lastSaveTime = gg.GetTimeStamp()
        
        cloudService:SetTableAsync('reward_' .. uin, rewardData, function(ret_)
            if ret_ then
                -- --gg.log("奖励数据保存成功", uin)
            else
                --gg.log("奖励数据保存失败", uin)
            end
        end)
    end
end

-- 获取奖励云存储键名
---@param uin number 玩家UIN
---@return string 云存储键名
function RewardCloudDataMgr.GetRewardCloudKey(uin)
    return 'reward_' .. uin
end

-- 清空玩家奖励数据（慎用）
---@param uin number 玩家UIN
function RewardCloudDataMgr.ClearPlayerRewardData(uin)
    cloudService:SetTableAsync('reward_' .. uin, { items = {} }, function(ret_)
        if ret_ then
            --gg.log("奖励数据清空成功", uin)
        else
            --gg.log("奖励数据清空失败", uin)
        end
    end)
end

-- 创建默认数据
---@return RewardCloudData 默认奖励数据
function RewardCloudDataMgr.CreateDefaultData()
    local currentDate = os.date("%Y-%m-%d")
    
    return {
        version = 1,
        lastSaveTime = gg.GetTimeStamp(),
        
        -- 在线奖励默认数据
        online = {
            configName = "在线奖励初级",
            currentRound = 1,
            todayOnlineTime = 0,
            roundOnlineTime = 0,
            claimedIndices = {},
            lastLoginDate = currentDate
        },
        
        -- 七日登录默认数据
        daily = {
            startDate = currentDate,
            currentDay = 1,
            claimedDays = {},
            lastClaimDate = ""
        },
        
        -- 活动奖励默认数据
        activity = {},
        
        -- 兑换默认数据
        exchange = {}
    }
end

-- 数据迁移（用于版本升级）
---@param oldData table 旧版本数据
---@return RewardCloudData 新版本数据
function RewardCloudDataMgr.MigrateData(oldData)
    -- 这里处理数据版本迁移逻辑
    -- 例如：从旧格式转换到新格式
    
    local newData = RewardCloudDataMgr.CreateDefaultData()
    
    -- 复制可用的旧数据
    if oldData.online then
        newData.online = oldData.online
    end
    
    if oldData.daily then
        newData.daily = oldData.daily
    end
    
    -- 其他迁移逻辑...
    
    return newData
end

-- 保存单个模块数据
---@param uin number 玩家ID
---@param moduleType string 模块类型 ("online", "daily", "activity", "exchange")
---@param moduleData table 模块数据
---@return boolean 是否保存成功
function RewardCloudDataMgr.SaveModuleData(uin, moduleType, moduleData)
    -- 先加载完整数据
    local _, fullData = RewardCloudDataMgr.ReadPlayerRewardData(uin)
    
    -- 更新指定模块
    fullData[moduleType] = moduleData
    
    -- 保存完整数据
    RewardCloudDataMgr.SavePlayerRewardData(uin, fullData, true)
    return true
end

-- 获取单个模块数据
---@param uin number 玩家ID
---@param moduleType string 模块类型
---@return table|nil 模块数据
function RewardCloudDataMgr.LoadModuleData(uin, moduleType)
    local _, fullData = RewardCloudDataMgr.ReadPlayerRewardData(uin)
    
    if fullData and fullData[moduleType] then
        return fullData[moduleType]
    end
    
    -- 返回该模块的默认数据
    local defaultData = RewardCloudDataMgr.CreateDefaultData()
    return defaultData[moduleType]
end

-- 批量保存（用于定时保存所有在线玩家）
---@param playerDataMap table<number, RewardCloudData> 玩家ID到数据的映射
---@return number 成功保存的数量
function RewardCloudDataMgr.BatchSave(playerDataMap)
    local successCount = 0
    
    for uin, data in pairs(playerDataMap) do
        RewardCloudDataMgr.SavePlayerRewardData(uin, data, true)
        successCount = successCount + 1
    end
    
    --gg.log(string.format("批量保存完成：成功 %d 个", successCount))
    return successCount
end

return RewardCloudDataMgr