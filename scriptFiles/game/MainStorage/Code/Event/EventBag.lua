--- 背包事件配置
---@class BagEventConfig
local BagEventConfig = {}

-- 客户端请求事件
BagEventConfig.REQUEST = {
    GET_BAG_ITEMS = "GetBagItems",           -- 获取背包物品
    USE_ITEM = "UseItem",                    -- 使用物品
    DECOMPOSE_ITEM = "DecomposeItem",        -- 分解装备
    SWAP_ITEMS = "SwapItems",                -- 交换物品位置
    USE_ALL_BOXES = "UseAllBoxes",           -- 打开所有宝箱
    DECOMPOSE_ALL_LOW_EQ = "DecomposeAllLowEq" -- 分解所有低质量装备
}

-- 服务器响应事件
BagEventConfig.RESPONSE = {
    SYNC_INVENTORY_ITEMS = "SyncInventoryItems", -- 同步背包物品
    ITEM_USED = "ItemUsed",                      -- 物品使用结果
    ITEM_DECOMPOSED = "ItemDecomposed",          -- 物品分解结果
    ITEMS_SWAPPED = "ItemsSwapped",              -- 物品交换结果
    BOXES_USED = "BoxesUsed",                    -- 宝箱使用结果
    LOW_EQ_DECOMPOSED = "LowEqDecomposed"        -- 低质量装备分解结果
}

-- 服务器通知事件
BagEventConfig.NOTIFY = {
    BAG_CHANGED = "BagChanged",                  -- 背包变化通知
    ITEM_OBTAINED = "ItemObtained"               -- 获得物品通知
}

-- 错误码定义
BagEventConfig.ERROR_CODES = {
    SUCCESS = 0,
    PLAYER_NOT_FOUND = 1,
    ITEM_NOT_FOUND = 2,
    INSUFFICIENT_QUANTITY = 3,
    BAG_FULL = 4,
    INVALID_OPERATION = 5,
    SYSTEM_ERROR = 6
}

-- 错误消息映射
BagEventConfig.ERROR_MESSAGES = {
    [BagEventConfig.ERROR_CODES.SUCCESS] = "操作成功",
    [BagEventConfig.ERROR_CODES.PLAYER_NOT_FOUND] = "玩家不存在",
    [BagEventConfig.ERROR_CODES.ITEM_NOT_FOUND] = "物品不存在",
    [BagEventConfig.ERROR_CODES.INSUFFICIENT_QUANTITY] = "物品数量不足",
    [BagEventConfig.ERROR_CODES.BAG_FULL] = "背包已满",
    [BagEventConfig.ERROR_CODES.INVALID_OPERATION] = "无效操作",
    [BagEventConfig.ERROR_CODES.SYSTEM_ERROR] = "系统错误"
}

--- 获取错误消息
---@param errorCode number 错误码
---@return string 错误消息
function BagEventConfig.GetErrorMessage(errorCode)
    return BagEventConfig.ERROR_MESSAGES[errorCode] or "未知错误"
end

return BagEventConfig 