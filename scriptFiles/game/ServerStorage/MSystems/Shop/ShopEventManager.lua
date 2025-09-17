-- ShopEventManager.lua
-- 商城事件管理器（静态类）
-- 负责处理客户端请求和服务器响应事件

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local ShopEventConfig = require(MainStorage.Code.Event.EventShop) ---@type ShopEventConfig
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

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
    
    -- 购买商品（金币/其他货币）
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.PURCHASE_ITEM, function(evt)
        ShopEventManager.HandlePurchaseItem(evt)
    end, 100)
    
    -- 【新增】迷你币专用购买事件
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.PURCHASE_MINI_ITEM, function(evt)
        ShopEventManager.HandlePurchaseMiniItem(evt)
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
    
    -- 【新增】动态价格购买事件
    ServerEventManager.Subscribe(ShopEventConfig.REQUEST.PURCHASE_DYNAMIC_ITEM, function(evt)
        ShopEventManager.HandleDynamicPricePurchase(evt)
    end, 100)
    
    gg.log("商城事件处理器注册完成")
end

-- 事件处理函数 --------------------------------------------------------

--- 【修改】处理非迷你币购买请求
---@param evt table 事件对象
function ShopEventManager.HandlePurchaseItem(evt)
    gg.log("处理非迷你币购买请求", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    local args = evt.args or {}
    
    if not player then
        return
    end
    
    local shopItemId = args.shopItemId
    local currencyType = args.currencyType
    local categoryName = args.categoryName
    
    if not shopItemId then
        --player:SendHoverText("商品ID不能为空")
        return
    end
    
    if not currencyType then
        --player:SendHoverText("货币类型不能为空")
        return
    end
    
    -- 拒绝迷你币购买请求，引导使用专用接口
    if currencyType == "迷你币" then
        gg.log("迷你币购买请求被拒绝，请使用专用接口", player.name, shopItemId)
        --player:SendHoverText("请使用迷你币专用购买接口")
        return
    end
    
    -- 执行非迷你币购买
    local success, message, purchaseResult = ShopMgr.ProcessNormalPurchase(player, shopItemId, currencyType, categoryName)
    
    if success then
        gg.log("商品购买成功", player.name, shopItemId, currencyType)
        ShopEventManager.SendShopItemAcquiredNotification(player.uin, purchaseResult.rewards, "商城购买")

        -- 发送成功响应
        gg.network_channel:fireClient(player.uin, {
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
        --player:SendHoverText(message)
    end
end

--- 【新增】迷你币专用购买事件处理器
---@param evt table 事件对象
function ShopEventManager.HandlePurchaseMiniItem(evt)
    gg.log("处理迷你币购买请求", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    local args = evt.args or {}
    
    if not player then
        return
    end
    
    local shopItemId = args.shopItemId
    local categoryName = args.categoryName
    
    if not shopItemId then
        --player:SendHoverText("商品ID不能为空")
        return
    end
    
    -- 执行迷你币购买（自动弹出支付窗口）
    local status, message, data = ShopMgr.ProcessMiniCoinPurchase(player, shopItemId, categoryName)
    
    if status == "pending" then
        gg.log("迷你币支付弹窗已拉起", player.name, shopItemId)
        -- 发送pending状态响应
        gg.network_channel:fireClient(player.uin, {
            cmd = ShopEventConfig.RESPONSE.MINI_PURCHASE_RESPONSE,
            success = true,
            data = {
                status = "pending",
                message = message,
                shopItemId = shopItemId,
                categoryName = categoryName
            },
            errorMsg = nil
        })
    else
        gg.log("迷你币购买失败", player.name, shopItemId, message)
        --player:SendHoverText(message)
    end
end

--- 【新增】处理动态价格购买请求
---@param evt table 事件对象
function ShopEventManager.HandleDynamicPricePurchase(evt)
    gg.log("处理动态价格购买请求", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    local args = evt.args or {}
    
    if not player then
        return
    end
    
    local shopItemId = args.shopItemId
    local currencyType = args.currencyType
    local categoryName = args.categoryName
    
    if not shopItemId then
        --player:SendHoverText("商品ID不能为空")
        return
    end
    
    if not currencyType then
        --player:SendHoverText("货币类型不能为空")
        return
    end
    
    -- 拒绝迷你币购买请求，引导使用专用接口
    if currencyType == "迷你币" then
        gg.log("动态价格购买请求被拒绝，迷你币请使用专用接口", player.name, shopItemId)
        --player:SendHoverText("请使用迷你币专用购买接口")
        return
    end
    
    -- 执行动态价格购买
    local success, message, purchaseResult = ShopMgr.ProcessDynamicPricePurchase(player, shopItemId, currencyType, categoryName)
    
    if success then
        gg.log("动态价格商品购买成功", player.name, shopItemId, currencyType)
        ShopEventManager.SendShopItemAcquiredNotification(player.uin, purchaseResult.rewards, "商城购买")

        -- 发送成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = ShopEventConfig.RESPONSE.PURCHASE_RESPONSE,
            success = true,
            data = {
                message = message,
                purchaseResult = purchaseResult,
                currencyType = currencyType,
                categoryName = categoryName,
                isDynamicPrice = true
            },
            errorMsg = nil
        })
    else
        gg.log("动态价格商品购买失败", player.name, shopItemId, currencyType, message)
        --player:SendHoverText(message)
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
        --player:SendHoverText("商品ID不能为空")
        return
    end
    
    -- 验证购买条件
    local canPurchase, reason = ShopMgr.ValidatePurchase(player, shopItemId)
    
    gg.log("验证购买条件", player.name, shopItemId, canPurchase, reason)
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.uin, {
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
    gg.network_channel:fireClient(player.uin, {
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
        --player:SendHoverText("商品ID不能为空")
        return
    end
    
    local shopInstance = ShopMgr.GetOrCreatePlayerShop(player)
    if not shopInstance then
        --player:SendHoverText("商城系统异常")
        return
    end
    
    local limitStatus = shopInstance:GetLimitStatus(shopItemId)
    
    gg.log("获取限购状态", player.name, shopItemId)
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.uin, {
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
    gg.network_channel:fireClient(player.uin, {
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
    -- ShopMgr.SavePlayerShopData(player.uin)
    
    -- 推送最新数据到客户端
    local success = ShopMgr.PushShopDataToClient(player.uin)
    
    if success then
        gg.log("刷新商城数据", player.name)
        
        -- 发送成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = ShopEventConfig.RESPONSE.REFRESH_RESPONSE,
            success = true,
            data = {
                message = "商城数据刷新成功"
            },
            errorMsg = nil
        })
    else
        --player:SendHoverText("商城数据刷新失败")
    end
end

-- 发送商城物品获得通知给NoticeGui
---@param uin number 玩家UIN
---@param rewards table[] 奖励列表
---@param source string 来源说明
function ShopEventManager.SendShopItemAcquiredNotification(uin, rewards, source)
    if not rewards or #rewards == 0 then
        return
    end
    
    -- 转换奖励数据格式为NoticeGui需要的格式
    local noticeRewards = {}
    for _, reward in ipairs(rewards) do
        -- 商城奖励配置结构：{itemType="物品", itemName="具体名称", amount=1}
        local itemType = reward.itemType or "物品"
        local itemName = reward.itemName or "未知物品"
        
        -- 确保itemType是中文格式
        if itemType == "pet" then
            itemType = "宠物"
        elseif itemType == "partner" then
            itemType = "伙伴"  
        elseif itemType == "wing" then
            itemType = "翅膀"
        elseif itemType == "trail" then
            itemType = "尾迹"
        elseif itemType == "item" then
            itemType = "物品"
        end
        
        table.insert(noticeRewards, {
            itemType = itemType,
            itemName = itemName,
            amount = reward.amount or 1
        })
    end
    
    -- 发送物品获得通知
    gg.network_channel:fireClient(uin, {
        cmd = EventPlayerConfig.NOTIFY.ITEM_ACQUIRED_NOTIFY,
        data = {
            rewards = noticeRewards,
            source = source,
            message = string.format("恭喜通过%s获得了以下物品！", source or "商城购买")
        }
    })
    
    -- 播放物品获得音效（客户端 SoundPool 监听 PlaySound 事件）
    local itemGetSound = CardIcon.soundResources["物品获得音效"]
    gg.network_channel:fireClient(uin, {
        cmd = "PlaySound",
        soundAssetId = itemGetSound
    })
    
    gg.log("已发送商城物品获得通知给玩家", uin, "奖励数量:", #noticeRewards)
end
return ShopEventManager