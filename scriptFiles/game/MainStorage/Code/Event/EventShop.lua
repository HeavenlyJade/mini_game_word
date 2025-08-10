--- 商城事件配置文件
--- 包含所有商城系统相关的事件名称定义

---@class ShopEventConfig
local ShopEventConfig = {}

--[[
===================================
网络事件定义
===================================
]]

-- 客户端请求事件
ShopEventConfig.REQUEST = {
    GET_SHOP_LIST = "ShopRequest_GetShopList",           -- 获取商城商品列表
    GET_CATEGORY_LIST = "ShopRequest_GetCategoryList",   -- 获取分类商品列表
    PURCHASE_ITEM = "ShopRequest_PurchaseItem",          -- 购买商品
    VALIDATE_PURCHASE = "ShopRequest_ValidatePurchase",  -- 验证购买条件
    GET_PURCHASE_RECORDS = "ShopRequest_GetRecords",     -- 获取购买记录
    GET_LIMIT_STATUS = "ShopRequest_GetLimitStatus",     -- 获取限购状态
    GET_SHOP_STATS = "ShopRequest_GetStats",             -- 获取商城统计
    SET_PREFERENCE = "ShopRequest_SetPreference",        -- 设置个人偏好
    GET_PREFERENCE = "ShopRequest_GetPreference",        -- 获取个人偏好
    REFRESH_SHOP = "ShopRequest_RefreshShop",            -- 刷新商城数据
}

-- 服务器响应事件
ShopEventConfig.RESPONSE = {
    SHOP_LIST_RESPONSE = "ShopResponse_ShopList",        -- 商城列表响应
    CATEGORY_LIST_RESPONSE = "ShopResponse_CategoryList", -- 分类列表响应
    PURCHASE_RESPONSE = "ShopResponse_Purchase",         -- 购买结果响应
    VALIDATE_RESPONSE = "ShopResponse_Validate",         -- 验证结果响应
    RECORDS_RESPONSE = "ShopResponse_Records",           -- 购买记录响应
    LIMIT_STATUS_RESPONSE = "ShopResponse_LimitStatus",  -- 限购状态响应
    STATS_RESPONSE = "ShopResponse_Stats",               -- 统计信息响应
    PREFERENCE_RESPONSE = "ShopResponse_Preference",     -- 偏好设置响应
    REFRESH_RESPONSE = "ShopResponse_Refresh",           -- 刷新结果响应
    ERROR = "ShopResponse_Error",                        -- 错误响应
}

return ShopEventConfig