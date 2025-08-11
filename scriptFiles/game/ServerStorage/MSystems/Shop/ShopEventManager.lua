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
local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager

---@class ShopEventManager
local ShopEventManager = {}

-- 初始化事件管理器
function ShopEventManager.Init()
    
    -- 注册网络事件处理器
    ShopEventManager.RegisterNetworkHandlers()
    
end

-- 注册网络事件处理器
function ShopEventManager.RegisterNetworkHandlers()
    local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
    
    -- 购买商品
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.PURCHASE_ITEM, function(evt)
        ShopEventManager.HandlePurchaseItem(evt)
    end, 100)
    
    -- 验证购买条件
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.VALIDATE_PURCHASE, function(evt)
        ShopEventManager.HandleValidatePurchase(evt)
    end, 100)
    
    -- 获取购买记录
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_PURCHASE_RECORDS, function(evt)
        ShopEventManager.HandleGetPurchaseRecords(evt)
    end, 100)
    
    -- 获取限购状态
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_LIMIT_STATUS, function(evt)
        ShopEventManager.HandleGetLimitStatus(evt)
    end, 100)
    
    -- 获取商城统计
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.GET_SHOP_STATS, function(evt)
        ShopEventManager.HandleGetShopStats(evt)
    end, 100)
    
    -- 刷新商城数据
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.REFRESH_SHOP, function(evt)
        ShopEventManager.HandleRefreshShopData(evt)
    end, 100)
    
    gg.log("商城事件处理器注册完成")
end

-- 事件处理函数 --------------------------------------------------------

--- 处理购买商品请求
---@param evt table 事件对象
function ShopEventManager.HandlePurchaseItem(evt)
    gg.log("处理购买商品请求", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    local args = evt.args or {}
    
    if not player then
        return
    end
    
    local shopItemId = args.shopItemId
    local currencyType = args.currencyType
    local categoryName = args.categoryName
    
    if not shopItemId then
        player:SendHoverText("商品ID不能为空")
        return
    end
    
    if not currencyType then
        player:SendHoverText("货币类型不能为空")
        return
    end
    
    -- 执行购买，传递货币类型和分类名
    local success, message, purchaseResult = ShopMgr.ProcessPurchase(player, shopItemId, currencyType, categoryName)
    
    if success then
        gg.log("商品购买成功", player.name, shopItemId, currencyType)
        
        -- 发送成功响应
        gg.network_channel:fireClient(player.Uin, {
            cmd = ShopEventConfig.RESPONSE.PURCHASE_RESPONSE,
            success = true,
            data = {
                message = message,
                purchaseResult = purchaseResult,
                currencyType = currencyType,
                categoryName = categoryName
            },
            errorMsg = nil
        })
    else
        gg.log("商品购买失败", player.name, shopItemId, currencyType, message)
        player:SendHoverText(message)
    end
end

--- 处理验证购买条件请求
---@param evt table 事件对象
function ShopEventManager.HandleValidatePurchase(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    local args = evt.args or {}
    
    if not player then
        return
    end
    
    local shopItemId = args.shopItemId
    if not shopItemId then
        player:SendHoverText("商品ID不能为空")
        return
    end
    
    -- 验证购买条件
    local canPurchase, reason = ShopMgr.ValidatePurchase(player, shopItemId)
    
    gg.log("验证购买条件", player.name, shopItemId, canPurchase, reason)
    
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
---@param evt table 事件对象
function ShopEventManager.HandleGetPurchaseRecords(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    local args = evt.args or {}
    
    if not player then
        return
    end
    
    local shopItemId = args.shopItemId -- 可选，如果为nil则返回所有记录
    local records = ShopMgr.GetPurchaseRecords(player, shopItemId)
    
    gg.log("获取购买记录", player.name, shopItemId)
    
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
---@param evt table 事件对象
function ShopEventManager.HandleGetLimitStatus(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    local args = evt.args or {}
    
    if not player then
        return
    end
    
    local shopItemId = args.shopItemId
    if not shopItemId then
        player:SendHoverText("商品ID不能为空")
        return
    end
    
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        player:SendHoverText("商城系统异常")
        return
    end
    
    local limitStatus = shopInstance:GetLimitStatus(shopItemId)
    
    gg.log("获取限购状态", player.name, shopItemId)
    
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
---@param evt table 事件对象
function ShopEventManager.HandleGetShopStats(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    
    if not player then
        return
    end
    
    local stats = ShopMgr.GetShopStats(player)
    
    gg.log("获取商城统计", player.name)
    
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
---@param evt table 事件对象
function ShopEventManager.HandleRefreshShopData(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    
    if not player then
        return
    end
    
    -- 保存当前数据
    ShopMgr.SavePlayerShopData(player.Uin)
    
    -- 推送最新数据到客户端
    local success = ShopMgr.PushShopDataToClient(player.Uin)
    
    if success then
        gg.log("刷新商城数据", player.name)
        
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
        player:SendHoverText("商城数据刷新失败")
    end
end

return ShopEventManager