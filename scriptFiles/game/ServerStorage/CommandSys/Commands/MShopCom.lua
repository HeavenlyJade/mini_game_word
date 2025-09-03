--- 商城相关命令处理器
--- 用于模拟迷你币支付的最终发放阶段（跳过支付，直接发奖与记录）

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class ShopCommand
local ShopCommand = {}

--- 模拟迷你币购买的最终发放
---@param params table 指令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function ShopCommand.simulateMiniGrant(params, player)
    local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr

	if not player then
		gg.log("错误：找不到玩家对象，无法模拟迷你币发放")
		return false
	end

	-- 优先使用迷你商品ID，其次根据商品ID反查
	local miniId = tonumber(params["迷你商品ID"]) or 0
	local shopItemId = params["商品ID"]
	local num = tonumber(params["数量"]) or 1

	if miniId <= 0 then
		if not shopItemId or shopItemId == "" then
			player:SendHoverText("缺少'迷你商品ID'或'商品ID'")
			return false
		end
		local shopItem = ConfigLoader.GetShopItem(shopItemId)
		if not shopItem then
			player:SendHoverText("商品配置不存在：" .. tostring(shopItemId))
			return false
		end
		local special = shopItem.specialProperties
		miniId = special and special.miniItemId or 0
	end

	if not miniId or miniId <= 0 then
		player:SendHoverText("迷你币商品ID无效，无法发放")
		return false
	end

	-- 直接走回调逻辑：发奖、更新记录、限购与客户端通知
	ShopMgr.HandleMiniPurchaseCallback(player.uin, miniId, num)
	gg.log("已模拟迷你币购买发放", player.name, "goodsid:", miniId, "数量:", num)
	--player:SendHoverText("已模拟迷你币购买发放")
	return true
end

--- 查看玩家商城记录
---@param params table 指令参数
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function ShopCommand.viewShopRecords(params, player)
    local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

    if not player then
        gg.log("错误：找不到玩家对象，无法查看商城记录")
        return false
    end

    -- 获取目标玩家UIN（默认为当前玩家）
    local targetUin = tonumber(params["目标玩家UIN"]) or player.uin
    local targetPlayer = MServerDataManager.getPlayerByUin(targetUin)
    
    if not targetPlayer then
        player:SendHoverText("找不到目标玩家，UIN: " .. tostring(targetUin))
        return false
    end

    -- 获取玩家商城实例
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(targetPlayer)
    if not shopInstance then
        player:SendHoverText("目标玩家商城数据不存在")
        return false
    end

    -- 获取购买记录
    local purchaseRecords = shopInstance:GetPurchaseRecords()
    local shopStats = shopInstance:GetShopStats()

    -- 构建显示信息
    local displayInfo = {}
    table.insert(displayInfo, "=== 玩家商城记录 ===")
    table.insert(displayInfo, "玩家: " .. (targetPlayer.name or "未知"))
    table.insert(displayInfo, "UIN: " .. tostring(targetUin))
    table.insert(displayInfo, "")
    
    -- 显示统计信息
    table.insert(displayInfo, "=== 消费统计 ===")
    table.insert(displayInfo, "累计迷你币消费: " .. gg.FormatLargeNumber(shopStats.totalMiniCoinSpent or 0))
    table.insert(displayInfo, "累计金币消费: " .. gg.FormatLargeNumber(shopStats.totalCoinSpent or 0))
    table.insert(displayInfo, "总购买次数: " .. tostring(shopStats.totalPurchases or 0))
    table.insert(displayInfo, "")

    -- 显示购买记录
    if next(purchaseRecords) then
        table.insert(displayInfo, "=== 购买记录 ===")
        local recordCount = 0
        for shopItemId, record in pairs(purchaseRecords) do
            if record and record.purchaseCount > 0 then
                recordCount = recordCount + 1
                local shopItem = ConfigLoader.GetShopItem(shopItemId)
                local itemName = shopItem and shopItem.configName or shopItemId
                
                table.insert(displayInfo, string.format("%d. %s", recordCount, itemName))
                table.insert(displayInfo, string.format("   购买次数: %d", record.purchaseCount))
                table.insert(displayInfo, string.format("   累计消费: %s", gg.FormatLargeNumber(record.totalSpent or 0)))
                if record.lastPurchaseTime and record.lastPurchaseTime > 0 then
                    local timeStr = os.date("%Y-%m-%d %H:%M:%S", record.lastPurchaseTime)
                    table.insert(displayInfo, string.format("   最后购买: %s", timeStr))
                end
                table.insert(displayInfo, "")
            end
        end
        
        if recordCount == 0 then
            table.insert(displayInfo, "暂无购买记录")
        end
    else
        table.insert(displayInfo, "=== 购买记录 ===")
        table.insert(displayInfo, "暂无购买记录")
    end

    -- 显示限购状态
    table.insert(displayInfo, "")
    table.insert(displayInfo, "=== 限购状态 ===")
    local limitCount = 0
    for shopItemId, _ in pairs(purchaseRecords) do
        local limitStatus = shopInstance:GetLimitStatus(shopItemId)
        if limitStatus and limitStatus.limitType ~= "无限制" then
            limitCount = limitCount + 1
            local shopItem = ConfigLoader.GetShopItem(shopItemId)
            local itemName = shopItem and shopItem.configName or shopItemId
            
            table.insert(displayInfo, string.format("%d. %s", limitCount, itemName))
            table.insert(displayInfo, string.format("   限购类型: %s", limitStatus.limitType))
            table.insert(displayInfo, string.format("   限购次数: %d", limitStatus.limitCount))
            table.insert(displayInfo, string.format("   已购买: %d", limitStatus.currentCount))
            table.insert(displayInfo, string.format("   状态: %s", limitStatus.isReached and "已达上限" or "可购买"))
            if limitStatus.resetTime and limitStatus.resetTime > 0 then
                local timeStr = os.date("%Y-%m-%d %H:%M:%S", limitStatus.resetTime)
                table.insert(displayInfo, string.format("   重置时间: %s", timeStr))
            end
            table.insert(displayInfo, "")
        end
    end
    
    if limitCount == 0 then
        table.insert(displayInfo, "无限购商品")
    end

    -- 发送显示信息
    local fullMessage = table.concat(displayInfo, "\n")
    player:SendHoverText(fullMessage)
	gg.log("fullMessage",fullMessage)
    
    gg.log("查看玩家商城记录", "执行者:", player.name, "目标玩家:", targetPlayer.name, "UIN:", targetUin)
    return true
end

-- 中文到处理器的映射
local operationMap = {
	["模拟迷你币购买"] = "simulateMiniGrant",
	["模拟迷你币发放"] = "simulateMiniGrant",
	["查看商城记录"] = "viewShopRecords",
	["查看购买记录"] = "viewShopRecords",
	["商城记录"] = "viewShopRecords",
}

--- 指令入口
---@param params table 指令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function ShopCommand.main(params, player)
	local operationType = params["操作类型"]
	if not operationType then
		--player:SendHoverText("缺少'操作类型'字段。有效类型: '模拟迷你币购买'")
		return false
	end

	local handlerName = operationMap[operationType]
	if not handlerName or not ShopCommand[handlerName] then
		--player:SendHoverText("未知的操作类型: " .. tostring(operationType))
		return false
	end

	gg.log("商城命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
	return ShopCommand[handlerName](params, player)
end

return ShopCommand


