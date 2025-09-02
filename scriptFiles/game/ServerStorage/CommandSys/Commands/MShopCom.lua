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
			--player:SendHoverText("缺少'迷你商品ID'或'商品ID'")
			return false
		end
		local shopItem = ConfigLoader.GetShopItem(shopItemId)
		if not shopItem then
			--player:SendHoverText("商品配置不存在：" .. tostring(shopItemId))
			return false
		end
		local special = shopItem.specialProperties
		miniId = special and special.miniItemId or 0
	end

	if not miniId or miniId <= 0 then
		--player:SendHoverText("迷你币商品ID无效，无法发放")
		return false
	end

	-- 直接走回调逻辑：发奖、更新记录、限购与客户端通知
	ShopMgr.HandleMiniPurchaseCallback(player.uin, miniId, num)
	gg.log("已模拟迷你币购买发放", player.name, "goodsid:", miniId, "数量:", num)
	--player:SendHoverText("已模拟迷你币购买发放")
	return true
end

-- 中文到处理器的映射
local operationMap = {
	["模拟迷你币购买"] = "simulateMiniGrant",
	["模拟迷你币发放"] = "simulateMiniGrant",
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


