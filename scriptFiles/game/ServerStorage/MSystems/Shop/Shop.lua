-- Shop.lua
-- 商城核心数据类 - 单个玩家的商城数据和业务方法
-- 负责管理玩家的购买记录、限购状态、个人设置等

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

-- 引入相关系统
local ShopCloudDataMgr = require(ServerStorage.MSystems.Shop.ShopCloudDataMgr) ---@type ShopCloudDataMgr
local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class Shop : Class
---@field uin number 玩家ID
---@field purchaseRecords table<string, ShopPurchaseRecord> 购买记录
---@field limitCounters table<string, ShopLimitCounter> 限购计数器
---@field preferences table<string, any> 个人设置
---@field vipLevel number VIP等级
---@field totalPurchaseValue number 累计迷你币消费金额
---@field totalCoinSpent number 累计金币消费金额
---@field dailyResetTime number 每日重置时间戳
---@field weeklyResetTime number 每周重置时间戳
---@field monthlyResetTime number 每月重置时间戳
---@field lastUpdateTime number 最后更新时间戳
local Shop = ClassMgr.Class("Shop")

-- 初始化商城数据
---@param shopData PlayerShopData 玩家商城数据
function Shop:OnInit(shopData)
    if not shopData then
        gg.log("警告：商城数据为空，使用默认数据")
        shopData = ShopCloudDataMgr.CreateDefaultShopData()
    end
    
    self.uin = shopData.uin or 0
    self.purchaseRecords = shopData.purchaseRecords or {}
    self.limitCounters = shopData.limitCounters or {}
    self.preferences = shopData.preferences or {}
    self.vipLevel = shopData.vipLevel or 0
    self.totalPurchaseValue = shopData.totalPurchaseValue or 0
    self.totalCoinSpent = shopData.totalCoinSpent or 0
    self.dailyResetTime = shopData.dailyResetTime or 0
    self.weeklyResetTime = shopData.weeklyResetTime or 0
    self.monthlyResetTime = shopData.monthlyResetTime or 0
    self.lastUpdateTime = shopData.lastUpdateTime or os.time()
end

-- 购买验证 --------------------------------------------------------

--- 检查是否可购买商品
---@param shopItemId string 商品ID
---@param player MPlayer 玩家对象
---@return boolean, string 是否可购买，失败原因
function Shop:CanPurchase(shopItemId, player)
    local shopItem = ConfigLoader.GetShopItem(shopItemId)
    if not shopItem then
        return false, "商品不存在"
    end
    
    -- 检查限购次数
    local canBuyLimit, limitReason = self:CheckPurchaseLimit(shopItemId, shopItem)
    if not canBuyLimit then
        return false, limitReason
    end
    
    -- 检查购买条件（通过ShopItemType验证）
    local canBuyCondition, conditionReason = shopItem:CanPurchase(player)
    if not canBuyCondition then
        return false, conditionReason
    end
    
    -- 检查背包空间
    local canBuySpace, spaceReason = self:CheckBagSpace(shopItem, player)
    if not canBuySpace then
        return false, spaceReason
    end
    
    return true, "可以购买"
end

--- 检查限购限制
---@param shopItemId string 商品ID
---@param shopItem ShopItemType 商品配置
---@return boolean, string 是否可购买，失败原因
function Shop:CheckPurchaseLimit(shopItemId, shopItem)
    if not shopItem.limitConfig or shopItem.limitConfig.limitType == "无限制" then
        return true, "无限制"
    end
    
    local limitType = shopItem.limitConfig.limitType
    local limitCount = shopItem.limitConfig.limitCount or 0
    local limitKey = self:GetLimitKey(shopItemId, limitType)
    
    -- 检查是否已达到限购次数
    local counter = self.limitCounters[limitKey]
    if counter then
        if counter.count >= limitCount then
            return false, string.format("已达到%s限购次数(%d次)", limitType, limitCount)
        end
    end
    
    -- 检查永久限购
    if limitType == "永久" then
        local purchaseRecord = self.purchaseRecords[shopItemId]
        if purchaseRecord and purchaseRecord.purchaseCount >= limitCount then
            return false, string.format("该商品永久限购%d次", limitCount)
        end
    end
    
    return true, "未达到限购限制"
end

--- 检查背包空间
---@param shopItem ShopItemType 商品配置
---@param player MPlayer 玩家对象
---@return boolean, string 是否有足够空间，失败原因
function Shop:CheckBagSpace(shopItem, player)
    if not shopItem.rewards or not next(shopItem.rewards) then
        return true, "无需检查空间"
    end
    
    -- 根据商品类型检查对应的系统空间
    for _, reward in ipairs(shopItem.rewards) do
        local itemType = reward.itemType
        local itemName = reward.itemName
        local amount = reward.amount or 1
        
        if itemType == "伙伴" then
            -- 检查伙伴槽位空间
            local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
            local hasSlot = PartnerMgr.HasAvailableSlot(player.uin)
            if not hasSlot then
                return false, "伙伴槽位已满，无法购买"
            end
        elseif itemType == "宠物" then
            -- 检查宠物槽位空间
            local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr
            local hasSlot = PetMgr.HasAvailableSlot(player.uin)
            if not hasSlot then
                return false, "宠物槽位已满，无法购买"
            end
        elseif itemType == "翅膀" then
            -- 检查翅膀槽位空间
            local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
            local hasSlot = WingMgr.HasAvailableSlot(player.uin)
            if not hasSlot then
                return false, "翅膀槽位已满，无法购买"
            end
        elseif itemType == "尾迹" then
            -- 检查尾迹槽位空间
            local TrailMgr = require(ServerStorage.MSystems.Trail.TrailMgr) ---@type TrailMgr
            local hasSlot = TrailMgr.HasAvailableSlot(player.uin)
            if not hasSlot then
                return false, "尾迹槽位已满，无法购买"
            end
        elseif itemType == "物品" then
            -- 检查背包空间
            local bagInstance = BagMgr.GetOrCreatePlayerBag(player.uin, player)
            if not bagInstance then
                return false, "背包系统异常"
            end
            
            -- 检查背包是否有足够空间
            local hasSpace = BagMgr.HasEnoughSpace(player, {[itemName] = amount})
            if not hasSpace then
                return false, "背包空间不足"
            end
        else
            -- 未知类型，默认检查背包
            local bagInstance = BagMgr.GetOrCreatePlayerBag(player.uin, player)
            if not bagInstance then
                return false, "背包系统异常"
            end
            
            local hasSpace = BagMgr.HasEnoughSpace(player, {[itemName] = amount})
            if not hasSpace then
                return false, "背包空间不足"
            end
        end
    end
    
    return true, "空间检查通过"
end

-- 购买执行 --------------------------------------------------------

--- 执行购买
---@param shopItemId string 商品ID
---@param player MPlayer 玩家对象
---@param currencyType string 货币类型
---@return boolean, string 是否成功，结果消息
function Shop:ExecutePurchase(shopItemId, player, currencyType)
    local shopItem = ConfigLoader.GetShopItem(shopItemId)
    if not shopItem then
        return false, "商品不存在"
    end
    
    -- 再次验证购买条件
    local canBuy, reason = self:CanPurchase(shopItemId, player)
    if not canBuy then
        return false, reason
    end
    
    -- 执行扣费，传递货币类型
    local paySuccess, payReason = self:ProcessPayment(shopItem, player, currencyType)
    if not paySuccess then
        return false, payReason
    end
    
    -- 发放奖励
    local rewardSuccess, rewardReason = self:GrantRewards(shopItem, player)
    if not rewardSuccess then
        -- 购买失败，需要退款
        self:RefundPayment(shopItem, player, currencyType)
        return false, "发放奖励失败：" .. rewardReason
    end
    
    -- 更新购买记录
    self:UpdatePurchaseRecord(shopItemId, shopItem, currencyType)
    
    -- 更新限购计数器
    self:UpdateLimitCounter(shopItemId, shopItem)
    
    -- 执行特殊指令
    self:ExecuteCommands(shopItem, player)
    
    gg.log("玩家购买商品成功", player.name, shopItemId, currencyType)
    return true, "购买成功"
end

--- 处理支付
---@param shopItem ShopItemType 商品配置
---@param player MPlayer 玩家对象
---@param currencyType string 货币类型
---@return boolean, string 是否成功，失败原因
function Shop:ProcessPayment(shopItem, player, currencyType)
    -- 根据选择的货币类型获取对应的价格
    local priceAmount = 0
    
    if currencyType == "迷你币" then
        priceAmount = shopItem.price.miniCoinAmount or 0
        if priceAmount <= 0 then
            return false, "该商品不支持迷你币购买"
        end
        -- 迷你币支付由迷你世界商城处理
        return true, "迷你币支付成功"
        
    elseif currencyType == "金币" then
        priceAmount = shopItem.price.amount or 0
        if priceAmount <= 0 then
            return false, "该商品不支持金币购买"
        end
        
        -- 使用BagMgr获取玩家金币数量
        local currentCoin = BagMgr.GetItemAmount(player, "金币")
        if currentCoin < priceAmount then
            return false, string.format("金币不足，需要%d个，当前拥有%d个", priceAmount, currentCoin)
        end
        
        -- 使用BagMgr扣除玩家金币
        local removeSuccess = BagMgr.RemoveItem(player, "金币", priceAmount)
        if not removeSuccess then
            return false, "扣除金币失败"
        end
        
        -- 更新金币消费统计
        self.totalCoinSpent = self.totalCoinSpent + priceAmount
        
    else
        return false, "不支持的货币类型：" .. tostring(currencyType)
    end
    
    -- 更新消费统计
    if currencyType == "迷你币" then
        self.totalPurchaseValue = self.totalPurchaseValue + priceAmount
    end
    
    return true, "支付成功"
end

--- 退款
---@param shopItem ShopItemType 商品配置
---@param player MPlayer 玩家对象
---@param currencyType string 货币类型
function Shop:RefundPayment(shopItem, player, currencyType)
    local priceAmount = 0
    
    if currencyType == "金币" then
        priceAmount = shopItem.price.amount or 0
        if priceAmount > 0 then
            -- 使用BagMgr退还玩家金币
            local addSuccess = BagMgr.AddItem(player, "金币", priceAmount)
            if addSuccess then
                self.totalCoinSpent = math.max(0, self.totalCoinSpent - priceAmount)
                gg.log("执行购买退款成功", player.name, currencyType, priceAmount)
            else
                gg.log("执行购买退款失败", player.name, currencyType, priceAmount)
            end
        end
    end
    
    -- 迷你币退款由迷你世界商城处理，这里不做处理
end

--- 发放奖励
---@param shopItem ShopItemType 商品配置
---@param player MPlayer 玩家对象
---@return boolean, string 是否成功，失败原因
function Shop:GrantRewards(shopItem, player)
    if not shopItem.rewards or not next(shopItem.rewards) then
        return true, "无奖励物品"
    end
    local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
    local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr
    local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
    local TrailMgr = require(ServerStorage.MSystems.Trail.TrailMgr) ---@type TrailMgr

    -- 按类型统计，用于决定是否同步
    local stats = { bag = 0, pet = 0, partner = 0, wing = 0, trail = 0 }
    
    -- 根据商品类型发放奖励
    for _, reward in ipairs(shopItem.rewards) do
        local itemType = reward.itemType
        local itemName = reward.itemName
        local amount = reward.amount or 1
        
        if itemType == "伙伴" then
            -- 发放伙伴
            local success, actualSlot = PartnerMgr.AddPartner(player, itemName)
            if not success then
                return false, string.format("添加伙伴失败：%s", itemName)
            end
            stats.partner = stats.partner + 1
        elseif itemType == "宠物" then
            -- 发放宠物
            local success, actualSlot = PetMgr.AddPet(player, itemName)
            if not success then
                return false, string.format("添加宠物失败：%s", itemName)
            end
            stats.pet = stats.pet + 1
        elseif itemType == "翅膀" then
            -- 发放翅膀
            local success, actualSlot = WingMgr.AddWing(player, itemName)
            if not success then
                return false, string.format("添加翅膀失败：%s", itemName)
            end
            stats.wing = stats.wing + 1
        elseif itemType == "尾迹" then
            -- 发放尾迹
            local success, actualSlot = TrailMgr.AddTrail(player, itemName)
            if not success then
                return false, string.format("添加尾迹失败：%s", itemName)
            end
            stats.trail = stats.trail + 1
        elseif itemType == "物品" then
            -- 发放物品到背包
            local success = BagMgr.AddItem(player, itemName, amount)
            if not success then
                return false, string.format("添加物品失败：%s", itemName)
            end
            stats.bag = stats.bag + 1
        else
        end
    end
    
    -- 统一按需同步（仅在对应类型发放过奖励时同步一次）
    if stats.bag > 0 then
        BagMgr.ForceSyncToClient(player.uin)
    end
    if stats.pet > 0 then
        PetMgr.ForceSyncToClient(player.uin)
    end
    if stats.partner > 0 then
        PartnerMgr.ForceSyncToClient(player.uin)
    end
    if stats.wing > 0 then
        WingMgr.ForceSyncToClient(player.uin)
    end
    if stats.trail > 0 then
        TrailMgr.ForceSyncToClient(player.uin)
    end
    
    gg.log("商城奖励发放完成，已同步数据到客户端", player.name, "伙伴:", stats.partner, "宠物:", stats.pet, "翅膀:", stats.wing, "尾迹:", stats.trail, "物品:", stats.bag)
    
    return true, "奖励发放完成"
end

--- 执行特殊指令
---@param shopItem ShopItemType 商品配置
---@param player MPlayer 玩家对象
function Shop:ExecuteCommands(shopItem, player)
    if not shopItem.commands or #shopItem.commands == 0 then
        return
    end
    
    for _, command in ipairs(shopItem.commands) do
        if type(command) == "string" and command ~= "" then
            player:ExecuteCommand(command)
        end
    end
end

-- 数据管理 --------------------------------------------------------

--- 更新购买记录
---@param shopItemId string 商品ID
---@param shopItem ShopItemType 商品配置
---@param currencyType string 货币类型
function Shop:UpdatePurchaseRecord(shopItemId, shopItem, currencyType)
    local currentTime = os.time()
    local priceAmount = 0
    
    -- 根据货币类型获取对应的价格
    if currencyType == "迷你币" then
        priceAmount = shopItem.price.miniCoinAmount or 0
    elseif currencyType == "金币" then
        priceAmount = shopItem.price.amount or 0
    end
    
    if not self.purchaseRecords[shopItemId] then
        self.purchaseRecords[shopItemId] = ShopCloudDataMgr.CreatePurchaseRecord(shopItemId, priceAmount)
    else
        local record = self.purchaseRecords[shopItemId]
        record.purchaseCount = record.purchaseCount + 1
        record.lastPurchaseTime = currentTime
        record.totalSpent = record.totalSpent + priceAmount
    end
end

--- 更新限购计数器
---@param shopItemId string 商品ID
---@param shopItem ShopItemType 商品配置
function Shop:UpdateLimitCounter(shopItemId, shopItem)
    if not shopItem.limitConfig or shopItem.limitConfig.limitType == "无限制" then
        return
    end
    
    local limitType = shopItem.limitConfig.limitType
    local limitKey = self:GetLimitKey(shopItemId, limitType)
    
    if not self.limitCounters[limitKey] then
        self.limitCounters[limitKey] = ShopCloudDataMgr.CreateLimitCounter(limitType)
    end
    
    self.limitCounters[limitKey].count = self.limitCounters[limitKey].count + 1
end

--- 获取限购键
---@param shopItemId string 商品ID
---@param limitType string 限制类型
---@return string 限购键
function Shop:GetLimitKey(shopItemId, limitType)
    if limitType == "每日" then
        return "daily_" .. shopItemId
    elseif limitType == "每周" then
        return "weekly_" .. shopItemId
    elseif limitType == "每月" then
        return "monthly_" .. shopItemId
    else
        return "permanent_" .. shopItemId
    end
end

--- 重置限购计数器
---@param resetType string 重置类型：daily|weekly|monthly
function Shop:ResetLimitCounters(resetType)
    local prefix = resetType .. "_"
    local currentTime = os.time()
    
    for limitKey, counter in pairs(self.limitCounters) do
        if string.sub(limitKey, 1, #prefix) == prefix then
            counter.count = 0
            counter.resetTime = currentTime
        end
    end
    
    gg.log("重置限购计数器", resetType, self.uin)
end

-- 查询方法 --------------------------------------------------------

--- 获取购买记录
---@param shopItemId string|nil 商品ID，nil则返回所有记录
---@return table 购买记录
function Shop:GetPurchaseRecords(shopItemId)
    if shopItemId then
        return self.purchaseRecords[shopItemId]
    else
        return self.purchaseRecords
    end
end

--- 获取限购状态
---@param shopItemId string 商品ID
---@return table|nil 限购状态信息
function Shop:GetLimitStatus(shopItemId)
    local shopItem = ConfigLoader.GetShopItem(shopItemId)
    if not shopItem or not shopItem.limitConfig then
        return nil
    end
    
    local limitType = shopItem.limitConfig.limitType
    local limitCount = shopItem.limitConfig.limitCount or 0
    local limitKey = self:GetLimitKey(shopItemId, limitType)
    local counter = self.limitCounters[limitKey]
    
    return {
        limitType = limitType,
        limitCount = limitCount,
        currentCount = counter and counter.count or 0,
        resetTime = counter and counter.resetTime or 0,
        isReached = counter and counter.count >= limitCount or false
    }
end

--- 获取商城统计信息
---@return table 统计信息
function Shop:GetShopStats()
    return ShopCloudDataMgr.GetShopDataStats(self:GetData())
end

--- 获取完整数据用于保存
---@return PlayerShopData 完整的商城数据
function Shop:GetData()
    return {
        uin = self.uin,
        purchaseRecords = self.purchaseRecords,
        limitCounters = self.limitCounters,
        preferences = self.preferences,
        vipLevel = self.vipLevel,
        totalPurchaseValue = self.totalPurchaseValue,
        totalCoinSpent = self.totalCoinSpent,
        dailyResetTime = self.dailyResetTime,
        weeklyResetTime = self.weeklyResetTime,
        monthlyResetTime = self.monthlyResetTime,
        lastUpdateTime = os.time()
    }
end

--- 设置个人偏好
---@param key string 设置键
---@param value any 设置值
function Shop:SetPreference(key, value)
    self.preferences[key] = value
end

--- 获取个人偏好
---@param key string 设置键
---@param defaultValue any 默认值
---@return any 设置值
function Shop:GetPreference(key, defaultValue)
    return self.preferences[key] or defaultValue
end

return Shop