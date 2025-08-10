-- ShopEventManager.lua
-- 商城事件管理器（静态类）
-- 负责处理客户端请求和服务器响应事件

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local ShopEventConfig = require(MainStorage.Code.Event.EventShop) ---@type ShopEventConfig

-- 引入相关系统
local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class ShopEventManager
local ShopEventManager = {}

-- 初始化事件管理器
function ShopEventManager.Init()
    --gg.log("商城事件管理器初始化")
    
    -- 注册网络事件处理器
    ShopEventManager.RegisterNetworkHandlers()
    
    --gg.log("商城事件管理器初始化完成")
end

-- 注册网络事件处理器
function ShopEventManager.RegisterNetworkHandlers()
    -- 获取商城商品列表
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_SHOP_LIST, function(event)
        ShopEventManager.HandleGetShopList(event)
    end, 100)
    
    -- 获取分类商品列表
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_CATEGORY_LIST, function(event)
        ShopEventManager.HandleGetCategoryList(event)
    end, 100)
    
    -- 购买商品
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.PURCHASE_ITEM, function(event)
        ShopEventManager.HandlePurchaseItem(event)
    end, 100)
    
    -- 验证购买条件
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.VALIDATE_PURCHASE, function(event)
        ShopEventManager.HandleValidatePurchase(event)
    end, 100)
    
    -- 获取购买记录
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_PURCHASE_RECORDS, function(event)
        ShopEventManager.HandleGetPurchaseRecords(event)
    end, 100)
    
    -- 获取限购状态
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_LIMIT_STATUS, function(event)
        ShopEventManager.HandleGetLimitStatus(event)
    end, 100)
    
    -- 获取商城统计
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_SHOP_STATS, function(event)
        ShopEventManager.HandleGetShopStats(event)
    end, 100)
    
    -- 设置个人偏好
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.SET_PREFERENCE, function(event)
        ShopEventManager.HandleSetPreference(event)
    end, 100)
    
    -- 获取个人偏好
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_PREFERENCE, function(event)
        ShopEventManager.HandleGetPreference(event)
    end, 100)
    
    -- 设置个人偏好
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.SET_PREFERENCE, function(event)
        ShopEventManager.HandleSetPreference(event)
    end, 100)
    
    -- 获取个人偏好
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_PREFERENCE, function(event)
        ShopEventManager.HandleGetPreference(event)
    end, 100)
    
    -- 刷新商城数据
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.REFRESH_SHOP, function(event)
        ShopEventManager.HandleRefreshShop(event)
    end, 100)
    
    --gg.log("商城事件处理器注册完成")
end

-- 事件处理函数 --------------------------------------------------------

--- 处理获取商城商品列表请求
---@param event table 事件对象
function ShopEventManager.HandleGetShopList(event)
    local player = event.player ---@type MPlayer
    local args = event.args or {}
    
    if not player or not player.Uin then
        return
    end
    
    local category = args.category
    local itemList = ShopMgr.GetShopItemList(player, category)
    
    --gg.log("获取商城商品列表", player.name, category, #itemList)
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.Uin, {
        cmd = ShopEventConfig.RESPONSE.SHOP_LIST_RESPONSE,
        success = true,
        data = {
            category = category,
            itemList = itemList,
            totalCount = #itemList
        },
        errorMsg = nil
    })
end

--- 处理获取分类商品列表请求
---@param event table 事件对象
function ShopEventManager.HandleGetCategoryList(event)
    local player = event.player ---@type MPlayer
    local args = event.args or {}
    
    if not player or not player.Uin then
        return
    end
    
    local category = args.category
    if not category then
        -- 发送错误响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.ERROR,
            success = false,
            data = nil,
            errorMsg = "商品分类不能为空"
        })
        return
    end
    
    local itemList = ShopMgr.GetShopItemList(player, category)
    
    --gg.log("获取分类商品列表", player.name, category, #itemList)
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.Uin, {
        cmd = ShopEventConfig.RESPONSE.CATEGORY_LIST_RESPONSE,
        success = true,
        data = {
            category = category,
            itemList = itemList,
            totalCount = #itemList
        },
        errorMsg = nil
    })
end

--- 处理购买商品请求
---@param event table 事件对象
function ShopEventManager.HandlePurchaseItem(event)
    local player = event.player ---@type MPlayer
    local args = event.args or {}
    
    if not player or not player.Uin then
        return
    end
    
    local shopItemId = args.shopItemId
    if not shopItemId then
        -- 发送错误响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.ERROR,
            success = false,
            data = nil,
            errorMsg = "商品ID不能为空"
        })
        return
    end
    
    -- 执行购买
    local success, message, purchaseResult = ShopMgr.ProcessPurchase(player, shopItemId)
    
    if success then
        --gg.log("商品购买成功", player.name, shopItemId)
        
        -- 发送成功响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.PURCHASE_RESPONSE,
            success = true,
            data = {
                message = message,
                purchaseResult = purchaseResult
            },
            errorMsg = nil
        })
    else
        --gg.log("商品购买失败", player.name, shopItemId, message)
        
        -- 发送错误响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.PURCHASE_RESPONSE,
            success = false,
            data = nil,
            errorMsg = message
        })
    end
end

--- 处理验证购买条件请求
---@param event table 事件对象
function ShopEventManager.HandleValidatePurchase(event)
    local player = event.player ---@type MPlayer
    local args = event.args or {}
    
    if not player or not player.Uin then
        return
    end
    
    local shopItemId = args.shopItemId
    if not shopItemId then
        -- 发送错误响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.ERROR,
            success = false,
            data = nil,
            errorMsg = "商品ID不能为空"
        })
        return
    end
    
    -- 验证购买条件
    local canPurchase, reason = ShopMgr.ValidatePurchase(player, shopItemId)
    
    --gg.log("验证购买条件", player.name, shopItemId, canPurchase, reason)
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.Uin, {
        cmd = ShopEventConfig.RESPONSE.VALIDATE_RESPONSE,
        success = true,
        data = {
            shopItemId = shopItemId,
            canPurchase = canPurchase,
            reason = reason
        },
        errorMsg = nil
    })
end

--- 处理获取购买记录请求
---@param event table 事件对象
function ShopEventManager.HandleGetPurchaseRecords(event)
    local player = event.player ---@type MPlayer
    local args = event.args or {}
    
    if not player or not player.Uin then
        return
    end
    
    local shopItemId = args.shopItemId -- 可选，如果为nil则返回所有记录
    local records = ShopMgr.GetPurchaseRecords(player, shopItemId)
    
    --gg.log("获取购买记录", player.name, shopItemId)
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.Uin, {
        cmd = ShopEventConfig.RESPONSE.RECORDS_RESPONSE,
        success = true,
        data = {
            shopItemId = shopItemId,
            records = records
        },
        errorMsg = nil
    })
end

--- 处理获取限购状态请求
---@param event table 事件对象
function ShopEventManager.HandleGetLimitStatus(event)
    local player = event.player ---@type MPlayer
    local args = event.args or {}
    
    if not player or not player.Uin then
        return
    end
    
    local shopItemId = args.shopItemId
    if not shopItemId then
        -- 发送错误响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.ERROR,
            success = false,
            data = nil,
            errorMsg = "商品ID不能为空"
        })
        return
    end
    
    local shopInstance = ShopMgr.GetPlayerShop(player.Uin)
    if not shopInstance then
        -- 发送错误响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.ERROR,
            success = false,
            data = nil,
            errorMsg = "商城数据异常"
        })
        return
    end
    
    local limitStatus = shopInstance:GetLimitStatus(shopItemId)
    
    --gg.log("获取限购状态", player.name, shopItemId)
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.Uin, {
        cmd = ShopEventConfig.RESPONSE.LIMIT_STATUS_RESPONSE,
        success = true,
        data = {
            shopItemId = shopItemId,
            limitStatus = limitStatus
        },
        errorMsg = nil
    })
end

--- 处理获取商城统计请求
---@param event table 事件对象
function ShopEventManager.HandleGetShopStats(event)
    local player = event.player ---@type MPlayer
    
    if not player or not player.Uin then
        return
    end
    
    local stats = ShopMgr.GetShopStats(player)
    
    --gg.log("获取商城统计", player.name)
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.Uin, {
        cmd = ShopEventConfig.RESPONSE.STATS_RESPONSE,
        success = true,
        data = {
            stats = stats
        },
        errorMsg = nil
    })
end

--- 处理刷新商城数据请求
---@param event table 事件对象
function ShopEventManager.HandleRefreshShop(event)
    local player = event.player ---@type MPlayer
    
    if not player or not player.Uin then
        return
    end
    
    -- 重新获取商城实例（会触发数据刷新）
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if shopInstance then
        -- 检查并重置过期限购
        local shopData = shopInstance:GetData()
        local ShopCloudDataMgr = require(ServerStorage.MSystems.Shop.ShopCloudDataMgr)
        ShopCloudDataMgr.CheckAndResetLimitCounters(shopData)
        
        -- 保存更新后的数据
        ShopMgr.SavePlayerShopData(player.Uin)
        
        --gg.log("刷新商城数据", player.name)
        
        -- 发送成功响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.REFRESH_RESPONSE,
            success = true,
            data = {
                message = "商城数据刷新成功"
            },
            errorMsg = nil
        })
    else
        -- 发送错误响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.ERROR,
            success = false,
            data = nil,
            errorMsg = "刷新商城数据失败"
        })
    end
end

return ShopEventManager