-- ShopMgr.lua
-- 商城功能管理器（静态类）
-- 负责缓存在线玩家的商城数据实例并处理业务逻辑

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

-- 引入相关系统
local Shop = require(ServerStorage.MSystems.Shop.Shop) ---@type Shop
local ShopCloudDataMgr = require(ServerStorage.MSystems.Shop.ShopCloudDataMgr) ---@type ShopCloudDataMgr
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class ShopMgr
local ShopMgr = {}

-- 在线玩家商城数据实例缓存
local server_player_shop_data = {} ---@type table<number, Shop>

-- 定时器相关
local resetCheckInterval = 300 -- 5分钟检查一次重置
local lastResetCheck = 0



-- 玩家加入时创建商城实例
---@param player MPlayer 玩家对象
function ShopMgr.OnPlayerJoin(player)
    if not player or not player.Uin then
        --gg.log("创建玩家商城实例失败：玩家对象无效")
        return
    end
    
    local uin = player.Uin
    
    -- 检查是否已存在实例
    if server_player_shop_data[uin] then
        --gg.log("玩家商城实例已存在", uin)
        return server_player_shop_data[uin]
    end
    
    -- 从云数据加载玩家商城数据
    local shopData = ShopCloudDataMgr.LoadPlayerShopData(uin)
    shopData.uin = uin -- 确保UIN正确
    
    -- 检查并重置过期限购
    ShopCloudDataMgr.CheckAndResetLimitCounters(shopData)
    
    -- 创建商城实例
    local shopInstance = Shop.New(shopData)
    server_player_shop_data[uin] = shopInstance
    
    --gg.log("玩家商城实例创建成功", uin)
    return shopInstance
end

-- 玩家离开时保存并清理商城数据
---@param uin number 玩家UIN
function ShopMgr.OnPlayerLeave(uin)
    if not uin then
        return
    end
    
    local shopInstance = server_player_shop_data[uin]
    if shopInstance then
        -- 保存数据到云端
        local shopData = shopInstance:GetData()
        ShopCloudDataMgr.SavePlayerShopData(uin, shopData)
        
        -- 清理缓存
        server_player_shop_data[uin] = nil
        --gg.log("玩家商城数据已保存并清理", uin)
    end
end

-- 获取玩家商城实例
---@param uin number 玩家UIN
---@return Shop|nil 商城实例
function ShopMgr.GetPlayerShop(uin)
    if not uin then
        return nil
    end
    
    return server_player_shop_data[uin]
end

-- 获取或创建玩家商城实例
---@param player MPlayer 玩家对象
---@return Shop|nil 商城实例
function ShopMgr.GetOrCreatePlayerShop(player)
    if not player or not player.Uin then
        return nil
    end
    
    local shopInstance = server_player_shop_data[player.Uin]
    if not shopInstance then
        shopInstance = ShopMgr.OnPlayerJoin(player)
    end
    
    return shopInstance
end

-- 处理玩家购买请求
---@param player MPlayer 玩家对象
---@param shopItemId string 商品ID
---@return boolean, string, table|nil 是否成功，结果消息，附加数据
function ShopMgr.ProcessPurchase(player, shopItemId)
    if not player or not shopItemId then
        return false, "参数无效", nil
    end
    
    -- 获取商城实例
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        return false, "商城系统异常", nil
    end
    
    -- 获取商品配置
    local shopItem = ConfigLoader.GetShopItem(shopItemId)
    if not shopItem then
        return false, "商品不存在", nil
    end
    
    -- 检查迷你币商品
    if shopItem.specialProperties and shopItem.specialProperties.miniItemId and shopItem.specialProperties.miniItemId > 0 then
        return ShopMgr.ProcessMiniPurchase(player, shopItem)
    end
    
    -- 执行购买
    local success, message = shopInstance:ExecutePurchase(shopItemId, player)
    
    if success then
        -- 保存数据
        ShopMgr.SavePlayerShopData(player.Uin)
        
        -- 构建购买结果
        local purchaseResult = {
            shopItemId = shopItemId,
            shopItemName = shopItem.configName,
            rewards = shopItem.rewards,
            purchaseTime = os.time()
        }
        
        --gg.log("玩家购买成功", player.name, shopItemId)
        return true, message, purchaseResult
    else
        --gg.log("玩家购买失败", player.name, shopItemId, message)
        return false, message, nil
    end
end

-- 处理迷你币商品购买
---@param player MPlayer 玩家对象
---@param shopItem ShopItemType 商品配置
---@return boolean, string, table|nil 是否成功，结果消息，附加数据
function ShopMgr.ProcessMiniPurchase(player, shopItem)
    -- 迷你币商品由迷你世界商城处理，这里只做记录
    local purchaseResult = {
        shopItemId = shopItem.configName,
        shopItemName = shopItem.configName,
        miniItemId = shopItem.specialProperties.miniItemId,
        purchaseType = "mini_coin",
        purchaseTime = os.time()
    }
    
    --gg.log("迷你币商品购买", player.name, shopItem.configName)
    return true, "迷你币商品购买处理", purchaseResult
end

-- 验证购买条件
---@param player MPlayer 玩家对象
---@param shopItemId string 商品ID
---@return boolean, string 是否可购买，失败原因
function ShopMgr.ValidatePurchase(player, shopItemId)
    if not player or not shopItemId then
        return false, "参数无效"
    end
    
    -- 获取商城实例
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        return false, "商城系统异常"
    end
    
    -- 验证购买条件
    return shopInstance:CanPurchase(shopItemId, player)
end

-- 获取商品列表
---@param player MPlayer 玩家对象
---@param category string|nil 商品分类
---@return table 商品列表
function ShopMgr.GetShopItemList(player, category)
    local allItems = ConfigLoader.GetAllShopItems()
    if not allItems then
        return {}
    end
    
    local itemList = {}
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    
    for itemId, shopItem in pairs(allItems) do
        -- 分类过滤
        if not category or shopItem.category == category then
            -- 构建商品信息
            local itemInfo = {
                itemId = itemId,
                name = shopItem.configName,
                description = shopItem.description,
                category = shopItem.category,
                price = shopItem.price,
                uiConfig = shopItem.uiConfig,
                specialProperties = shopItem.specialProperties,
                canPurchase = false,
                purchaseInfo = nil
            }
            
            -- 检查购买条件
            if shopInstance then
                local canBuy, reason = shopInstance:CanPurchase(itemId, player)
                itemInfo.canPurchase = canBuy
                if not canBuy then
                    itemInfo.purchaseInfo = { reason = reason }
                end
                
                -- 获取限购状态
                local limitStatus = shopInstance:GetLimitStatus(itemId)
                if limitStatus then
                    itemInfo.limitStatus = limitStatus
                end
            end
            
            table.insert(itemList, itemInfo)
        end
    end
    
    -- 按排序权重排序
    table.sort(itemList, function(a, b)
        local weightA = (a.uiConfig and a.uiConfig.sortWeight) or 0
        local weightB = (b.uiConfig and b.uiConfig.sortWeight) or 0
        return weightA > weightB
    end)
    
    return itemList
end

-- 获取玩家购买记录
---@param player MPlayer 玩家对象
---@param shopItemId string|nil 商品ID，nil则返回所有记录
---@return table 购买记录
function ShopMgr.GetPurchaseRecords(player, shopItemId)
    if not player then
        return {}
    end
    
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        return {}
    end
    
    return shopInstance:GetPurchaseRecords(shopItemId)
end

-- 获取商城统计信息
---@param player MPlayer 玩家对象
---@return table 统计信息
function ShopMgr.GetShopStats(player)
    if not player then
        return {}
    end
    
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        return {}
    end
    
    return shopInstance:GetShopStats()
end

-- 保存玩家商城数据
---@param uin number 玩家UIN
---@return boolean 是否成功
function ShopMgr.SavePlayerShopData(uin)
    if not uin then
        return false
    end
    
    local shopInstance = server_player_shop_data[uin]
    if not shopInstance then
        return false
    end
    
    local shopData = shopInstance:GetData()
    return ShopCloudDataMgr.SavePlayerShopData(uin, shopData)
end

-- 保存所有在线玩家的商城数据
function ShopMgr.SaveAllPlayerShopData()
    local saveCount = 0
    
    for uin, shopInstance in pairs(server_player_shop_data) do
        if shopInstance then
            local shopData = shopInstance:GetData()
            ShopCloudDataMgr.SavePlayerShopData(uin, shopData)
            saveCount = saveCount + 1
        end
    end
    
    --gg.log("批量保存商城数据完成", saveCount)
    return saveCount
end

-- 清理离线玩家数据
function ShopMgr.CleanupOfflinePlayers()
    local Players = game:GetService("Players")
    local cleanupCount = 0
    
    for uin, shopInstance in pairs(server_player_shop_data) do
        local player = Players:GetPlayerByUserId(uin)
        if not player then
            -- 玩家已离线，保存并清理数据
            local shopData = shopInstance:GetData()
            ShopCloudDataMgr.SavePlayerShopData(uin, shopData)
            server_player_shop_data[uin] = nil
            cleanupCount = cleanupCount + 1
        end
    end
    
    if cleanupCount > 0 then
        --gg.log("清理离线玩家商城数据", cleanupCount)
    end
    
    return cleanupCount
end



-- 检查并重置限购
function ShopMgr.CheckAndResetLimits()
    local currentTime = os.time()
    local resetCount = 0
    
    for uin, shopInstance in pairs(server_player_shop_data) do
        if shopInstance then
            local shopData = shopInstance:GetData()
            local hasReset = ShopCloudDataMgr.CheckAndResetLimitCounters(shopData)
            
            if hasReset then
                -- 更新实例数据
                shopInstance.limitCounters = shopData.limitCounters
                shopInstance.dailyResetTime = shopData.dailyResetTime
                shopInstance.weeklyResetTime = shopData.weeklyResetTime
                shopInstance.monthlyResetTime = shopData.monthlyResetTime
                
                -- 保存到云端
                ShopCloudDataMgr.SavePlayerShopData(uin, shopData)
                resetCount = resetCount + 1
            end
        end
    end
    
    if resetCount > 0 then
        --gg.log("执行商城限购重置", resetCount)
    end
end

-- 手动重置指定玩家的限购
---@param player MPlayer 玩家对象
---@param resetType string 重置类型：daily|weekly|monthly
---@return boolean 是否成功
function ShopMgr.ResetPlayerLimits(player, resetType)
    if not player or not resetType then
        return false
    end
    
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        return false
    end
    
    shopInstance:ResetLimitCounters(resetType)
    ShopMgr.SavePlayerShopData(player.Uin)
    
    --gg.log("手动重置玩家限购", player.name, resetType)
    return true
end

-- 获取在线玩家数量
---@return number 在线玩家商城实例数量
function ShopMgr.GetOnlinePlayerCount()
    local count = 0
    for _ in pairs(server_player_shop_data) do
        count = count + 1
    end
    return count
end

-- 设置玩家偏好
---@param player MPlayer 玩家对象
---@param key string 偏好键
---@param value any 偏好值
---@return boolean 是否成功
function ShopMgr.SetPlayerPreference(player, key, value)
    if not player or not key then
        return false
    end
    
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        return false
    end
    
    shopInstance:SetPreference(key, value)
    ShopMgr.SavePlayerShopData(player.Uin)
    
    return true
end

-- 获取玩家偏好
---@param player MPlayer 玩家对象
---@param key string 偏好键
---@param defaultValue any 默认值
---@return any 偏好值
function ShopMgr.GetPlayerPreference(player, key, defaultValue)
    if not player or not key then
        return defaultValue
    end
    
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        return defaultValue
    end
    
    return shopInstance:GetPreference(key, defaultValue)
end

return ShopMgr