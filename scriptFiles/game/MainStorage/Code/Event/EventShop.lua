--- 商城事件配置文件
--- 包含所有商城系统相关的事件名称定义

---@class ShopEventConfig
local ShopEventConfig = {}

-- 客户端请求事件
ShopEventConfig.REQUEST = {
    GET_SHOP_LIST = "ShopRequest_GetShopList",           -- 获取商城商品列表
    PURCHASE_ITEM = "ShopRequest_PurchaseItem",          -- 购买商品
    PURCHASE_DYNAMIC_ITEM = "ShopRequest_PurchaseDynamicItem", -- 【新增】动态价格购买事件
    VALIDATE_PURCHASE = "ShopRequest_ValidatePurchase",  -- 验证购买条件
    GET_PURCHASE_RECORDS = "ShopRequest_GetRecords",     -- 获取购买记录
    REFRESH_SHOP = "ShopRequest_RefreshShop",            -- 刷新商城数据
    PURCHASE_MINI_ITEM = "ShopRequest_PurchaseMiniItem", -- 【新增】迷你币专用购买事件

}

-- 服务器响应事件
ShopEventConfig.RESPONSE = {
    SHOP_LIST_RESPONSE = "ShopResponse_ShopList",        -- 商城列表响应
    PURCHASE_RESPONSE = "ShopResponse_Purchase",         -- 购买结果响应
    VALIDATE_RESPONSE = "ShopResponse_Validate",         -- 验证结果响应
    RECORDS_RESPONSE = "ShopResponse_Records",           -- 购买记录响应
    REFRESH_RESPONSE = "ShopResponse_Refresh",           -- 刷新结果响应
    ERROR = "ShopResponse_Error",                        -- 错误响应
    MINI_PURCHASE_RESPONSE = "ShopResponse_MiniPurchase", -- 【新增】迷你币购买响应

}

-- 服务器主动推送事件
ShopEventConfig.NOTIFY = {
    SHOP_DATA_SYNC = "ShopNotify_ShopDataSync",                  -- 商城数据同步
}

return ShopEventConfig