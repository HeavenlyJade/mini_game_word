-- ShopCloudDataMgr.lua
-- 商城云数据结构管理器
-- 负责定义商城数据的存储格式、序列化和反序列化逻辑

local game = game
local os = os

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService")   ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

---@class ShopPurchaseRecord
---@field shopItemId string 商品ID
---@field purchaseCount number 购买次数
---@field firstPurchaseTime number 首次购买时间戳
---@field lastPurchaseTime number 最后购买时间戳
---@field totalSpent number 总花费金额

---@class ShopLimitCounter
---@field count number 当前计数
---@field resetTime number 重置时间戳
---@field limitType string 限制类型：每日|每周|每月|永久

---@class PlayerShopData
---@field purchaseRecords table<string, ShopPurchaseRecord> 购买记录 {[shopItemId] = purchaseRecord}
---@field limitCounters table<string, ShopLimitCounter> 限购计数器 {[limitKey] = counter}
---@field preferences table<string, any> 商城个人设置 {[settingKey] = value}
---@field vipLevel number VIP等级
---@field totalPurchaseValue number 累计迷你币消费金额
---@field totalCoinSpent number 累计金币消费金额
---@field dailyResetTime number 每日重置时间戳（4点重置）
---@field weeklyResetTime number 每周重置时间戳（周一4点重置）
---@field monthlyResetTime number 每月重置时间戳（每月1日4点重置）
---@field lastUpdateTime number 最后更新时间戳

---@class ShopCloudDataMgr
local ShopCloudDataMgr = {}



-- 默认重置时间配置
local RESET_HOUR = 4 -- 凌晨4点重置

--- 计算下一个重置时间
---@param resetType string 重置类型：daily|weekly|monthly
---@param currentTime number 当前时间戳
---@return number 下一个重置时间戳
local function CalculateNextResetTime(resetType, currentTime)
    local date = os.date("*t", currentTime)
    
    if resetType == "daily" then
        -- 每日4点重置
        local resetTime = os.time({
            year = date.year,
            month = date.month,
            day = date.day,
            hour = RESET_HOUR,
            min = 0,
            sec = 0
        })
        
        -- 如果当前时间已过今日4点，则计算明日4点
        if currentTime >= resetTime then
            resetTime = resetTime + 24 * 3600
        end
        
        return resetTime
        
    elseif resetType == "weekly" then
        -- 每周一4点重置
        local dayOfWeek = date.wday == 1 and 7 or date.wday - 1 -- 转换为周一为1的格式
        local daysUntilMonday = (8 - dayOfWeek) % 7
        if daysUntilMonday == 0 and currentTime >= os.time({
            year = date.year,
            month = date.month,
            day = date.day,
            hour = RESET_HOUR,
            min = 0,
            sec = 0
        }) then
            daysUntilMonday = 7
        end
        
        local resetTime = os.time({
            year = date.year,
            month = date.month,
            day = date.day + daysUntilMonday,
            hour = RESET_HOUR,
            min = 0,
            sec = 0
        })
        
        return resetTime
        
    elseif resetType == "monthly" then
        -- 每月1日4点重置
        local resetTime = os.time({
            year = date.month == 12 and date.year + 1 or date.year,
            month = date.month == 12 and 1 or date.month + 1,
            day = 1,
            hour = RESET_HOUR,
            min = 0,
            sec = 0
        })
        
        return resetTime
    end
    
    return currentTime
end

--- 创建默认商城数据
---@return PlayerShopData
local function CreateDefaultShopData()
    local currentTime = os.time()
    
    return {
        purchaseRecords = {},
        limitCounters = {},
        preferences = {
            ["显示热卖标签"] = true,
            ["显示限定标签"] = true,
            ["自动刷新"] = true
        },
        vipLevel = 0,
        totalPurchaseValue = 0,
        totalCoinSpent = 0,
        dailyResetTime = CalculateNextResetTime("daily", currentTime),
        weeklyResetTime = CalculateNextResetTime("weekly", currentTime),
        monthlyResetTime = CalculateNextResetTime("monthly", currentTime),
        lastUpdateTime = currentTime
    }
end

--- 验证和修复商城数据
---@param shopData PlayerShopData
---@return PlayerShopData
local function ValidateAndRepairShopData(shopData)
    if not shopData or type(shopData) ~= "table" then
        --gg.log("商城数据无效，创建默认数据")
        return CreateDefaultShopData()
    end
    
    -- 确保必要字段存在
    shopData.purchaseRecords = shopData.purchaseRecords or {}
    shopData.limitCounters = shopData.limitCounters or {}
    shopData.preferences = shopData.preferences or {}
    shopData.vipLevel = shopData.vipLevel or 0
    shopData.totalPurchaseValue = shopData.totalPurchaseValue or 0
    shopData.totalCoinSpent = shopData.totalCoinSpent or 0
    shopData.lastUpdateTime = os.time()
    
    -- 重新计算重置时间
    local currentTime = os.time()
    shopData.dailyResetTime = shopData.dailyResetTime or CalculateNextResetTime("daily", currentTime)
    shopData.weeklyResetTime = shopData.weeklyResetTime or CalculateNextResetTime("weekly", currentTime)
    shopData.monthlyResetTime = shopData.monthlyResetTime or CalculateNextResetTime("monthly", currentTime)
    
    return shopData
end



--- 加载玩家商城数据
---@param uin number 玩家ID
---@return PlayerShopData 玩家商城数据
function ShopCloudDataMgr.LoadPlayerShopData(uin)
    local ret, data = cloudService:GetTableOrEmpty('shop_player_' .. uin)
    
    if ret and data then
        --gg.log("加载玩家商城数据成功", uin)
        return ValidateAndRepairShopData(data)
    else
        --gg.log("加载玩家商城数据失败，创建默认数据", uin)
        return CreateDefaultShopData()
    end
end

--- 保存玩家商城数据
---@param uin number 玩家ID
---@param shopData PlayerShopData
---@return boolean 是否成功
function ShopCloudDataMgr.SavePlayerShopData(uin, shopData)
    if not shopData then
        --gg.log("商城数据为空，无法保存", uin)
        return false
    end
    
    -- 更新最后保存时间
    shopData.lastUpdateTime = os.time()
    
    -- 异步保存到云存储
    cloudService:SetTableAsync('shop_player_' .. uin, shopData, function(success)
        if not success then
            --gg.log("保存玩家商城数据失败", uin)
        else
            --gg.log("保存玩家商城数据成功", uin)
        end
    end)
    
    return true
end

--- 检查是否需要重置限购计数器
---@param shopData PlayerShopData
---@return boolean 是否有重置
function ShopCloudDataMgr.CheckAndResetLimitCounters(shopData)
    local currentTime = os.time()
    local hasReset = false
    
    -- 检查每日重置
    if currentTime >= shopData.dailyResetTime then
        ShopCloudDataMgr.ResetDailyLimits(shopData)
        shopData.dailyResetTime = CalculateNextResetTime("daily", currentTime)
        hasReset = true
        --gg.log("执行每日商城限购重置")
    end
    
    -- 检查每周重置
    if currentTime >= shopData.weeklyResetTime then
        ShopCloudDataMgr.ResetWeeklyLimits(shopData)
        shopData.weeklyResetTime = CalculateNextResetTime("weekly", currentTime)
        hasReset = true
        --gg.log("执行每周商城限购重置")
    end
    
    -- 检查每月重置
    if currentTime >= shopData.monthlyResetTime then
        ShopCloudDataMgr.ResetMonthlyLimits(shopData)
        shopData.monthlyResetTime = CalculateNextResetTime("monthly", currentTime)
        hasReset = true
        --gg.log("执行每月商城限购重置")
    end
    
    return hasReset
end

--- 重置每日限购
---@param shopData PlayerShopData
function ShopCloudDataMgr.ResetDailyLimits(shopData)
    for limitKey, counter in pairs(shopData.limitCounters) do
        if counter.limitType == "每日" then
            counter.count = 0
            counter.resetTime = CalculateNextResetTime("daily", os.time())
        end
    end
end

--- 重置每周限购
---@param shopData PlayerShopData
function ShopCloudDataMgr.ResetWeeklyLimits(shopData)
    for limitKey, counter in pairs(shopData.limitCounters) do
        if counter.limitType == "每周" then
            counter.count = 0
            counter.resetTime = CalculateNextResetTime("weekly", os.time())
        end
    end
end

--- 重置每月限购
---@param shopData PlayerShopData
function ShopCloudDataMgr.ResetMonthlyLimits(shopData)
    for limitKey, counter in pairs(shopData.limitCounters) do
        if counter.limitType == "每月" then
            counter.count = 0
            counter.resetTime = CalculateNextResetTime("monthly", os.time())
        end
    end
end

--- 创建购买记录
---@param shopItemId string 商品ID
---@param purchaseAmount number 购买金额
---@return ShopPurchaseRecord
function ShopCloudDataMgr.CreatePurchaseRecord(shopItemId, purchaseAmount)
    local currentTime = os.time()
    
    return {
        shopItemId = shopItemId,
        purchaseCount = 1,
        firstPurchaseTime = currentTime,
        lastPurchaseTime = currentTime,
        totalSpent = purchaseAmount or 0
    }
end

--- 创建限购计数器
---@param limitType string 限制类型
---@return ShopLimitCounter
function ShopCloudDataMgr.CreateLimitCounter(limitType)
    return {
        count = 0,
        resetTime = CalculateNextResetTime(limitType == "每日" and "daily" or 
                                         limitType == "每周" and "weekly" or 
                                         limitType == "每月" and "monthly" or "daily", os.time()),
        limitType = limitType
    }
end

--- 获取商城数据统计信息
---@param shopData PlayerShopData
---@return table 统计信息
function ShopCloudDataMgr.GetShopDataStats(shopData)
    local totalPurchases = 0
    local uniqueItems = 0
    
    for _, record in pairs(shopData.purchaseRecords) do
        totalPurchases = totalPurchases + record.purchaseCount
        uniqueItems = uniqueItems + 1
    end
    
    return {
        totalPurchases = totalPurchases,
        uniqueItems = uniqueItems,
        totalMiniCoinSpent = shopData.totalPurchaseValue,
        totalCoinSpent = shopData.totalCoinSpent,
        vipLevel = shopData.vipLevel,
        activeLimits = #shopData.limitCounters
    }
end

return ShopCloudDataMgr