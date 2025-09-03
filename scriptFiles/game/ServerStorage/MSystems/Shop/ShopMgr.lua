-- ShopMgr.lua
-- 商城功能管理器（静态类）
-- 负责缓存在线玩家的商城数据实例并处理业务逻辑

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local MS = require(MainStorage.Code.Untils.MS) ---@type MS

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
    if not player or not player.uin then
        --gg.log("创建玩家商城实例失败：玩家对象无效")
        return
    end
    
    local uin = player.uin
    
    -- 检查是否已存在实例
    if server_player_shop_data[uin] then
        --gg.log("玩家商城实例已存在", uin)
        return server_player_shop_data[uin]
    end
    
    -- 从云数据加载玩家商城数据
    local shopData = ShopCloudDataMgr.LoadPlayerShopData(uin)
    
    -- 检查并重置过期限购
    ShopCloudDataMgr.CheckAndResetLimitCounters(shopData)
    
    -- 创建商城实例
    local shopInstance = Shop.New(shopData)
    ---@cast shopInstance Shop
    server_player_shop_data[uin] = shopInstance
    
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
    if not player or not player.uin then
        return nil
    end
    
    local shopInstance = server_player_shop_data[player.uin]
    return shopInstance
end

-- 【新增】专门处理迷你币购买的函数
---@param player MPlayer 玩家对象
---@param shopItemId string 商品ID
---@param categoryName string|nil 商品分类
---@return boolean|string, string, table|nil 状态（true=成功, false=失败, "pending"=等待支付），结果消息，附加数据
function ShopMgr.ProcessMiniCoinPurchase(player, shopItemId, categoryName)
    gg.log("处理迷你币专用购买", player.name, shopItemId, categoryName)
    
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
    
    -- 验证商品是否支持迷你币购买
    if not shopItem.price.miniCoinType or shopItem.price.miniCoinType ~= "迷你币" then
        return false, "该商品不支持迷你币购买未配置", nil
    end
    
    if not shopItem.price.miniCoinAmount or shopItem.price.miniCoinAmount <= 0 then
        return false, "迷你币价格配置异常", nil
    end
    
    -- 验证迷你商品ID配置
    if not shopItem.specialProperties or 
       not shopItem.specialProperties.miniItemId or 
       shopItem.specialProperties.miniItemId <= 0 then
        return false, "迷你币商品配置异常", nil
    end
    
    -- 验证购买条件（限购、VIP等）
    local canPurchase, reason = shopInstance:CanPurchase(shopItemId, player)
    if not canPurchase then
        return false, reason, nil
    end
    
    -- 调用迷你币购买处理（弹出支付窗口）
    return ShopMgr.ProcessMiniPurchase(player, shopItem, "迷你币")
end

-- 【新增】专门处理非迷你币购买的函数
---@param player MPlayer 玩家对象
---@param shopItemId string 商品ID
---@param currencyType string 货币类型
---@param categoryName string|nil 商品分类
---@return boolean, string, table|nil 是否成功，结果消息，附加数据
function ShopMgr.ProcessNormalPurchase(player, shopItemId, currencyType, categoryName)
    gg.log("处理普通货币购买", player.name, shopItemId, currencyType, categoryName)
    
    if not player or not shopItemId or not currencyType then
        return false, "参数无效", nil
    end
    
    -- 明确拒绝迷你币
    if currencyType == "迷你币" then
        return false, "迷你币购买请使用专用接口", nil
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
    
    -- 验证货币类型支持
    if currencyType == "金币" then
        if not shopItem.price.amount or shopItem.price.amount <= 0 then
            return false, "该商品不支持金币购买", nil
        end
    else
        return false, "不支持的货币类型：" .. currencyType, nil
    end
    
    -- 直接执行购买（无需弹窗确认）
    local success, message, purchaseData = shopInstance:ExecutePurchase(shopItemId, player, currencyType)
    
    if success then
        -- 保存数据
        -- ShopMgr.SavePlayerShopData(player.uin)
        
        -- 构建购买结果
        local purchaseResult = {
            shopItemId = shopItemId,
            shopItemName = shopItem.configName,
            rewards = shopItem.rewards,
            currencyType = currencyType,
            categoryName = categoryName,
            purchaseTime = os.time()
        }
        
        return true, message, purchaseResult
    else
        return false, message, nil
    end
end



-- 处理迷你币商品购买
---@param player MPlayer 玩家对象
---@param shopItem ShopItemType 商品配置
---@param currencyType string 货币类型
---@return boolean|string, string, table|nil 状态（true=成功, false=失败, "pending"=等待支付），结果消息，附加数据
function ShopMgr.ProcessMiniPurchase(player, shopItem, currencyType)
    gg.log("处理迷你币商品购买", player.name, shopItem.configName, currencyType)

    local miniId = shopItem.specialProperties and shopItem.specialProperties.miniItemId or 0
    if not miniId or miniId <= 0 then
        return false, "迷你币商品ID无效", nil
    end

    -- 检查迷你币商品映射是否存在（由 ConfigLoader 在初始化时构建）
    if not ConfigLoader.HasMiniShopItem(miniId) then
        gg.log("警告：迷你商品ID未在配置中找到", miniId, shopItem.configName)
        return false, "迷你币商品配置异常", nil
    end
    gg.log("拉起迷你币购买弹窗", miniId, shopItem.configName)

    player:SendEvent("ViewMiniGood", {
        goodId = miniId,
        desc = shopItem.configName,
        amount = 1
    })

    gg.log("已发起迷你币支付弹窗", player.name, shopItem.configName, miniId)
    -- 返回中间状态：既不是成功也不是失败，而是等待用户完成支付
    -- 真实购买处理在 MiniShopManager:OnPurchaseCallback 中完成
    return "pending", "支付弹窗已拉起，等待用户完成支付", nil
end

-- 迷你币支付成功回调处理（由 MiniShopManager 调用）
---@param uin number
---@param goodsid number
---@param num number
function ShopMgr.HandleMiniPurchaseCallback(uin, goodsid, num)
    if not uin or not goodsid then return end

    local ShopEventConfig = require(MainStorage.Code.Event.EventShop) ---@type ShopEventConfig

    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        gg.log("迷你币购买回调失败：找不到玩家", uin)
        return
    end

    -- 使用 ConfigLoader 直接获取迷你币商品配置
    local targetItem = ConfigLoader.GetMiniShopItem(goodsid)
    if not targetItem then
        gg.log("迷你币购买成功但未找到对应配置", goodsid)
        return
    end

    -- 获取/创建玩家商城实例
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        shopInstance = ShopMgr.OnPlayerJoin(player)
    end
    if not shopInstance then
        return
    end
    ---@cast shopInstance Shop

    -- 根据购买数量发放（通常为1）
    local ok, reason = shopInstance:GrantRewards(targetItem, player)
    if not ok then
        gg.log("迷你币购买发奖失败", player.name, targetItem.configName, reason)
        return
    end
    -- 记录购买与限购计数（以迷你币计）
    shopInstance:UpdatePurchaseRecord(targetItem.configName, targetItem, "迷你币")
    shopInstance:UpdateLimitCounter(targetItem.configName, targetItem)
    
    -- 更新迷你币消费统计（这里需要手动更新，因为跳过了ProcessPayment）
    local miniCoinAmount = targetItem.price.miniCoinAmount or 0
    

    if miniCoinAmount > 0 then
        shopInstance.totalPurchaseValue = shopInstance.totalPurchaseValue + miniCoinAmount
    end
    gg.log("更新迷你币消费统计", player.name, "商品:", targetItem.configName, "金额:", miniCoinAmount, "累计:", shopInstance.totalPurchaseValue)

    -- 执行商品配置的额外指令（如果有）
    if targetItem.executeCommands and type(targetItem.executeCommands) == "table" and #targetItem.executeCommands > 0 then
        for _, commandStr in ipairs(targetItem.executeCommands) do
            if type(commandStr) == "string" and commandStr ~= "" then
                shopInstance:ExecuteRewardCommand(commandStr, player)
            end
        end
    end
    

    
    -- 持久化
    ShopMgr.SavePlayerShopData(player.uin)
    local ShopEventManager = require(ServerStorage.MSystems.Shop.ShopEventManager) ---@type ShopEventManager
    ShopEventManager.SendShopItemAcquiredNotification(player.uin, targetItem.rewards, "商城购买")

    -- 通知客户端购买成功
    local purchaseResult = {
        shopItemId = targetItem.configName,
        shopItemName = targetItem.configName,
        rewards = targetItem.rewards,
        currencyType = "迷你币",
        categoryName = targetItem.category,
        purchaseTime = os.time()
    }

    if not player.uin then
        gg.log("警告：玩家Uin为空，无法发送客户端通知", player.name or "未知玩家")
        return
    end
    
    gg.network_channel:fireClient(player.uin, {
        cmd = ShopEventConfig.RESPONSE.MINI_PURCHASE_RESPONSE,
        success = true,
        data = {
            status = "success",
            message = "奖励发放完成",
            purchaseResult = purchaseResult,
            categoryName = targetItem.category
        },
        errorMsg = nil
    })
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

-- 清空指定玩家的商城数据并保存
---@param uin number 玩家UIN
---@return boolean 是否成功
function ShopMgr.ClearPlayerShopData(uin)
    if not uin then
        return false
    end

    -- 创建默认数据并保存到云端
    local defaultData = ShopCloudDataMgr.CreateDefaultShopData()
    defaultData.uin = uin
    ShopCloudDataMgr.SavePlayerShopData(uin, defaultData)

    -- 如果内存中存在实例，同步重置其字段，避免旧数据残留
    local shopInstance = server_player_shop_data[uin]
    if shopInstance then
        shopInstance.purchaseRecords = {}
        shopInstance.limitCounters = {}
        shopInstance.preferences = {}
        shopInstance.vipLevel = 0
        shopInstance.totalPurchaseValue = 0
        shopInstance.totalCoinSpent = 0
        shopInstance.dailyResetTime = defaultData.dailyResetTime
        shopInstance.weeklyResetTime = defaultData.weeklyResetTime
        shopInstance.monthlyResetTime = defaultData.monthlyResetTime
    end

    -- 确保有实例后推送同步
    if not shopInstance then
        local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
        local player = MServerDataManager.getPlayerByUin(uin)
        if player then
            shopInstance = ShopMgr.OnPlayerJoin(player)
        end
    end

    if shopInstance then
        ShopMgr.PushShopDataToClient(uin)
        gg.log("已清空玩家商城数据并同步:", uin)
    else
        gg.log("已清空玩家商城云数据，但未找到在线实例用于同步:", uin)
    end

    return true
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
    ShopMgr.SavePlayerShopData(player.uin)
    
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
    ShopMgr.SavePlayerShopData(player.uin)
    
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

-- 向客户端推送玩家的商城云端数据
---@param uin number 玩家UIN
---@return boolean 是否成功
function ShopMgr.PushShopDataToClient(uin)
    if not uin then
        return false
    end
    
    local shopInstance = server_player_shop_data[uin]
    if not shopInstance then
        --gg.log("玩家商城实例不存在，跳过数据推送", uin)
        return false
    end
    
    -- 获取商城数据
    local shopData = shopInstance:GetData()
    
    -- 向客户端推送数据
    local ShopEventConfig = require(MainStorage.Code.Event.EventShop) ---@type ShopEventConfig
    gg.network_channel:fireClient(uin, {
        cmd = ShopEventConfig.NOTIFY.SHOP_DATA_SYNC,
        success = true,
        data = {
            shopData = shopData,
            message = "商城数据同步完成",
            timestamp = os.time()
        }
    })
    
    --gg.log("已向客户端推送商城数据", uin)
    return true
end

return ShopMgr