--- 迷你商店相关命令处理器
--- 用于查询玩家购买的商品列表

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local MiniShopManager = require(ServerStorage.MiniGameMgr.MiniShopManager) ---@type MiniShopManager

---@class MiniShopCommand
local MiniShopCommand = {}

--- 查询指定玩家的购买商品列表
---@param params table 指令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function MiniShopCommand.queryPlayerPurchases(params, player)
    if not player then
        gg.log("错误：找不到玩家对象，无法查询购买列表")
        return false
    end

    -- 获取目标玩家UIN（默认为当前玩家）
    local targetUin = tonumber(params["玩家UID"]) or player.uin
    local targetPlayer = MServerDataManager.getPlayerByUin(targetUin)
    
    if not targetPlayer then
        player:SendHoverText("找不到目标玩家，UIN: " .. tostring(targetUin))
        return false
    end

    -- 获取玩家购买列表
    local purchaseList = MiniShopManager:GetPlayerPurchasedList(targetUin)
    
    -- 构建显示信息
    local displayInfo = {}
    table.insert(displayInfo, "=== 玩家购买商品列表 ===")
    table.insert(displayInfo, "玩家: " .. (targetPlayer.name or "未知"))
    table.insert(displayInfo, "UIN: " .. tostring(targetUin))
    table.insert(displayInfo, "")
    
    if not purchaseList or #purchaseList == 0 then
        table.insert(displayInfo, "该玩家暂无购买记录")
    else
        table.insert(displayInfo, "=== 购买商品详情 ===")
        table.insert(displayInfo, "总购买商品数: " .. tostring(#purchaseList))
        table.insert(displayInfo, "")
        
        for i, item in ipairs(purchaseList) do
            gg.log("xxxxxx",i, item)
            table.insert(displayInfo, string.format("%d. 商品ID: %s", i, tostring(item.goodId or item.goodsId or "未知")))
            table.insert(displayInfo, string.format("   商品名称: %s", tostring(item.name or "未知")))
            table.insert(displayInfo, string.format("   购买时间: %s", tostring(item.buyTime or item.purchaseTime or "未知")))
            table.insert(displayInfo, string.format("   购买数量: %s", tostring(item.num or item.quantity or 1)))
            if item.costType then
                table.insert(displayInfo, string.format("   消费类型: %s", tostring(item.costType)))
            end
            if item.costNum then
                table.insert(displayInfo, string.format("   消费数量: %s", tostring(item.costNum)))
            end
            -- 显示所有可用的字段信息（用于调试）
            table.insert(displayInfo, "   详细信息:")
            for key, value in pairs(item) do
                if key ~= "goodId" and key ~= "goodsId" and key ~= "name" and key ~= "buyTime" and key ~= "purchaseTime" and key ~= "num" and key ~= "quantity" and key ~= "costType" and key ~= "costNum" then
                    table.insert(displayInfo, string.format("     %s: %s", tostring(key), tostring(value)))
                end
            end
            table.insert(displayInfo, "")
        end
    end

    -- 发送显示信息
    local fullMessage = table.concat(displayInfo, "\n")
    player:SendHoverText(fullMessage)
    gg.log("查询玩家的购买商品列表",fullMessage)
    -- gg.log("查询玩家购买商品列表", "执行者:", player.name, "目标玩家:", targetPlayer.name, "UIN:", targetUin, "购买商品数:", #purchaseList)
    
    return true
end

--- 查询商店商品列表
---@param params table 指令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function MiniShopCommand.queryStoreList(params, player)
    if not player then
        gg.log("错误：找不到玩家对象，无法查询商店列表")
        return false
    end

    -- 获取商店商品列表
    local storeList = MiniShopManager:GetStoreList()
    
    -- 构建显示信息
    local displayInfo = {}
    table.insert(displayInfo, "=== 商店商品列表 ===")
    table.insert(displayInfo, "")
    
    if not storeList or #storeList == 0 then
        table.insert(displayInfo, "商店暂无商品")
    else
        table.insert(displayInfo, "=== 商品详情 ===")
        table.insert(displayInfo, "总商品数: " .. tostring(#storeList))
        table.insert(displayInfo, "")
        
        for i, item in ipairs(storeList) do
            table.insert(displayInfo, string.format("%d. 商品ID: %s", i, tostring(item.goodId or item.goodsId or "未知")))
            table.insert(displayInfo, string.format("   商品名称: %s", tostring(item.name or "未知")))
            table.insert(displayInfo, string.format("   商品描述: %s", tostring(item.desc or "无描述")))
            if item.costType then
                table.insert(displayInfo, string.format("   消费类型: %s", tostring(item.costType)))
            end
            if item.costNum then
                table.insert(displayInfo, string.format("   消费数量: %s", tostring(item.costNum)))
            end
            -- 显示所有可用的字段信息（用于调试）
            table.insert(displayInfo, "   详细信息:")
            for key, value in pairs(item) do
                if key ~= "goodId" and key ~= "goodsId" and key ~= "name" and key ~= "desc" and key ~= "costType" and key ~= "costNum" then
                    table.insert(displayInfo, string.format("     %s: %s", tostring(key), tostring(value)))
                end
            end
            table.insert(displayInfo, "")
        end
    end

    -- 发送显示信息
    local fullMessage = table.concat(displayInfo, "\n")
    player:SendHoverText(fullMessage)
    gg.log("查询商店商品列表", "执行者:", player.name, "商品数:", #storeList)
    
    return true
end


--- 检查玩家是否已购买指定商品
---@param params table 指令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function MiniShopCommand.checkPlayerPurchase(params, player)
    if not player then
        gg.log("错误：找不到玩家对象，无法检查购买状态")
        return false
    end

    local targetUin = tonumber(params["玩家UID"]) or player.uin
    local goodsId = params["商品ID"]
    
    if not goodsId then
        player:SendHoverText("缺少'商品ID'参数")
        return false
    end

    local targetPlayer = MServerDataManager.getPlayerByUin(targetUin)
    if not targetPlayer then
        player:SendHoverText("找不到目标玩家，UIN: " .. tostring(targetUin))
        return false
    end

    -- 检查购买状态
    local hasPurchased = MiniShopManager:HasPlayerPurchasedGoods(targetUin, goodsId)
    local purchaseCount = MiniShopManager:GetPlayerPurchasedCount(targetUin)
    
    -- 构建显示信息
    local displayInfo = {}
    table.insert(displayInfo, "=== 购买状态检查 ===")
    table.insert(displayInfo, "玩家: " .. (targetPlayer.name or "未知"))
    table.insert(displayInfo, "UIN: " .. tostring(targetUin))
    table.insert(displayInfo, "商品ID: " .. tostring(goodsId))
    table.insert(displayInfo, "购买状态: " .. (hasPurchased and "已购买" or "未购买"))
    table.insert(displayInfo, "总购买商品数: " .. tostring(purchaseCount))
    table.insert(displayInfo, "")

    -- 发送显示信息
    local fullMessage = table.concat(displayInfo, "\n")
    player:SendHoverText(fullMessage)
    gg.log("检查玩家购买状态", "执行者:", player.name, "目标玩家:", targetPlayer.name, "商品ID:", goodsId, "已购买:", hasPurchased)
    
    return true
end

-- 中文到处理器的映射
local operationMap = {
    ["查询购买列表"] = "queryPlayerPurchases",
    ["购买列表"] = "queryPlayerPurchases",
    ["玩家购买"] = "queryPlayerPurchases",
    ["查询商店列表"] = "queryStoreList",
    ["商店列表"] = "queryStoreList",
    ["商品列表"] = "queryStoreList",
    ["检查购买状态"] = "checkPlayerPurchase",
    ["购买状态"] = "checkPlayerPurchase"
}

--- 指令入口
---@param params table 指令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function MiniShopCommand.main(params, player)
    local operationType = params["操作类型"]
    if not operationType then
        gg.log("缺少'操作类型'字段。有效类型: '查询购买列表', '查询商店列表', '检查购买状态'")
        return false
    end

    local handlerName = operationMap[operationType]
    if not handlerName or not MiniShopCommand[handlerName] then
        gg.log("未知的操作类型: " .. tostring(operationType))
        return false
    end

    gg.log("迷你商店命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
    return MiniShopCommand[handlerName](params, player)
end

return MiniShopCommand
