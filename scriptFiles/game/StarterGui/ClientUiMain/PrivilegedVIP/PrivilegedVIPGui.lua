-- PrivilegedVIPGui.lua
-- 特权VIP界面逻辑

local MainStorage = game:GetService("MainStorage")

-- 引入核心模块
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

-- 引入UI基类和组件
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon

-- 引入事件系统
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local ShopEventConfig = require(MainStorage.Code.Event.EventShop) ---@type ShopEventConfig
local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig

-- UI配置
local uiConfig = {
    uiName = "PrivilegedVIPGui",
    layer = 3,
    hideOnInit = true,
}

---@class PrivilegedVIPGui : ViewBase
local PrivilegedVIPGui = ClassMgr.Class("PrivilegedVIPGui", ViewBase)

---@override
function PrivilegedVIPGui:OnInit(node, config)
    -- 1. 节点初始化
    self:InitNodes()
    
    -- 2. 数据存储
    self:InitData()
    
    -- 3. 事件注册
    self:RegisterEvents()
    
    -- 4. 按钮点击事件注册
    self:RegisterButtonEvents()
    
    
    --gg.log("PrivilegedVIPGui 特权界面初始化完成")
end

-- 节点初始化
function PrivilegedVIPGui:InitNodes()
    -- 主界面
    self.privilegePanel = self:Get("特权界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("特权界面/关闭", ViewButton) ---@type ViewButton
    
    -- 特权描述区域
    self.privilegeDescription = self:Get("特权界面/模版界面描述/特权", ViewComponent) ---@type ViewComponent
    -- 特权商品区域
    self.productDemo = self:Get("特权界面/模版界面商品/特权", ViewComponent) ---@type ViewComponent
    
    
    -- 特权商品栏位 (ViewList)
    self.privilegeItemList = self:Get("特权界面/特权商品栏位", ViewList) ---@type ViewList
    self.descriptionPanel = self:Get("特权界面/特权描述栏位", ViewList) ---@type ViewList
    self.purchaseButton = self:Get("特权界面/价格栏", ViewButton) ---@type ViewButton
    self.priceFrame = self:Get("特权界面/价格栏/价格框", ViewComponent) ---@type ViewComponent
    self.vipShopItem = nil ---@type ShopItemType
    -- gachaPanel
    -- 将价格栏转换为购买按钮
end

-- 数据初始化
function PrivilegedVIPGui:InitData()
    self.privilegeData = {}
    self.selectedPrivilege = nil
    self.currencyMap = {}
    self.shopData = nil
    self.isVipPurchased = false

    -- 先尝试从配置中读取"会员特权"分类下 名称为"玩家特权卡"的商品
    local vipShopItem = nil ---@type ShopItemType

    local vipItems = ConfigLoader.GetShopItemsByCategory("会员特权") or {}
    for _, item in ipairs(vipItems) do
        if item and item.configName == "玩家特权卡" then
            vipShopItem = item
            break
        end
    end
    if not vipShopItem then
        return
    end
    
    -- 存储商品信息供购买时使用
    self.vipShopItem = vipShopItem
    self.priceFrame.node.Title = ""..vipShopItem.price.miniCoinAmount

    -- 根据rewards克隆节点
    if vipShopItem.rewards and #vipShopItem.rewards > 0 then
        for i, reward in ipairs(vipShopItem.rewards) do
            -- 克隆特权描述节点到特权商品栏位
            if self.privilegeDescription then
                local clonedDescription = self.privilegeDescription.node:Clone()
                clonedDescription["描述"].Title = reward.gainDescription 
                clonedDescription.Name = "特权描述_" .. i
                clonedDescription.Parent = self.descriptionPanel.node
                self.descriptionPanel:AppendChild(clonedDescription)
            end
            
            -- 克隆特权商品节点到特权描述栏位
            if self.productDemo then
                local clonedProduct = self.productDemo.node:Clone()
                clonedProduct.Name = "特权商品_" .. i
                clonedProduct.Parent = self.privilegeItemList.node
                clonedProduct["图标"].Icon = CardIcon.itemIconResources[reward.iconResource] or ""
                clonedProduct["描述"].Title =reward.simpleDescription  

                self.privilegeItemList:AppendChild(clonedProduct)

            end
        end
    end
    
    self.privilegeTypes = {}
    self.privilegeConfigs = {}

    -- 无静态兜底：当未找到配置时，保持空列表，界面自行处理为空态
end

-- 注册客户端事件
function PrivilegedVIPGui:RegisterEvents()
    --gg.log("注册特权系统事件监听")
    ClientEventManager.Subscribe(ShopEventConfig.RESPONSE.MINI_PURCHASE_RESPONSE, function(data)
        self:OnMiniPurchaseResponse(data)
    end)
    ClientEventManager.Subscribe(ShopEventConfig.RESPONSE.ERROR, function(data)
        self:OnShopErrorResponse(data)
    end)
    ClientEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, function(data)
        self:OnSyncInventoryItems(data)
    end)
    -- 监听商城数据同步，判断VIP是否已购买
    ClientEventManager.Subscribe(ShopEventConfig.NOTIFY.SHOP_DATA_SYNC, function(data)
        self:OnShopDataSync(data)
    end)
end

-- 注册按钮事件
function PrivilegedVIPGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
    end
    
    -- 为购买按钮绑定点击事件
    self.purchaseButton.clickCb = function()
        self:OnClickPurchase()
    end
end




-- 添加特权
function PrivilegedVIPGui:OnAddPrivilege()
    --gg.log("添加特权")
    -- 这里可以实现添加新特权的逻辑
    -- 比如打开特权选择界面或者直接购买某个特权
end

-- 特权商品点击
function PrivilegedVIPGui:OnPrivilegeProductClick()
    --gg.log("特权商品被点击")
    -- 这里可以实现特权详情的展示逻辑
    -- 比如显示特权列表、购买界面等
end

--- 点击购买按钮
function PrivilegedVIPGui:OnClickPurchase()
    if not self.vipShopItem then
        --gg.log("错误：未找到VIP商品数据")
        return
    end
    
    local shopItemId = self.vipShopItem.configName
    local categoryName = self.vipShopItem.category -- 从ShopItemType实例获取分类
    
    if not self.vipShopItem.price.miniCoinAmount or self.vipShopItem.price.miniCoinAmount <= 0 then
        gg.log("错误：该商品迷你币数量无效")
        return
    end
    
    gg.log("点击购买VIP特权卡: " .. shopItemId .. "，分类: " .. categoryName .. "，迷你币数量: " .. self.vipShopItem.price.miniCoinAmount)
    
    -- 发送迷你币购买请求
    self:SendMiniCoinPurchaseRequest(shopItemId, categoryName)
end

--- 发送迷你币购买请求
function PrivilegedVIPGui:SendMiniCoinPurchaseRequest(shopItemId, categoryName)
    gg.log("发送迷你币购买请求, 商品ID: " .. shopItemId .. ", 分类: " .. categoryName)
    gg.network_channel:fireServer({
        cmd = ShopEventConfig.REQUEST.PURCHASE_MINI_ITEM,
        args = { shopItemId = shopItemId, categoryName = categoryName }
    })
end

--- UI打开时调用
function PrivilegedVIPGui:OnOpen()
    --gg.log("PrivilegedVIPGui 打开")
    -- 可以在这里刷新特权数据
end

--- UI关闭时调用
function PrivilegedVIPGui:OnClose()
    --gg.log("PrivilegedVIPGui 关闭")
end

-------------------------------------------------------------------
-- 事件响应
-------------------------------------------------------------------

function PrivilegedVIPGui:OnMiniPurchaseResponse(data)
    if data and data.success then
        if data.data.status == "pending" then
            --gg.log("迷你币支付弹窗已拉起: " .. (data.data.message or ""))
        elseif data.data.status == "success" then
            --gg.log("迷你币购买成功: " .. (data.data.message or ""))
            -- 刷新界面数据
            self:RefreshInterface()
            -- 如果返回的商品是VIP特权卡，则隐藏购买按钮
            local pr = data.data and data.data.purchaseResult
            if pr and self.vipShopItem and pr.shopItemId == self.vipShopItem.configName then
                self.isVipPurchased = true
                self:UpdatePurchaseButtonVisibility()
            end
        end
    else
        --gg.log("迷你币购买失败: " .. (data and data.errorMsg or "未知错误"))
    end
end

function PrivilegedVIPGui:OnShopErrorResponse(data)
    --gg.log("收到商城系统错误: ", data and data.errorMsg)
end

function PrivilegedVIPGui:OnSyncInventoryItems(data)
    local items = data and data.items
    if not items then return end
    
    local MConfig = require(MainStorage.Code.Common.GameConfig.MConfig) ---@type common_config
    local currencyType = MConfig.ItemTypeEnum["货币"]

    local hasCurrencyUpdate = false
    local currencyItems = items[tostring(currencyType)]
    if currencyItems then
        hasCurrencyUpdate = true
        for _, itemData in pairs(currencyItems) do
             if itemData and itemData.name and itemData.amount then
                self.currencyMap[itemData.name] = itemData.amount
             end
        end
    end

    if hasCurrencyUpdate then
        --gg.log("特权界面已同步货币数据", self.currencyMap)
        self:RefreshPurchaseButtons()
    end
end

-------------------------------------------------------------------
-- UI 更新
------------------------------------PrivilegedVIPGui-------------------------------

function PrivilegedVIPGui:RefreshInterface()
    -- 刷新特权描述和商品显示
    self:RefreshPrivilegeDisplay()
end

function PrivilegedVIPGui:RefreshPrivilegeDisplay()
    -- 刷新特权描述和商品显示
    if not self.vipShopItem then return end
    
    -- 刷新价格显示
    if self.priceFrame and self.vipShopItem.price then
        self.priceFrame.node.Title = tostring(self.vipShopItem.price.miniCoinAmount or 0)
    end
    
    -- 刷新购买按钮状态
    self:RefreshPurchaseButtons()
    self:UpdatePurchaseButtonVisibility()
end

function PrivilegedVIPGui:RefreshPurchaseButtons()
    -- 刷新购买按钮状态
    if not self.vipShopItem or not self.purchaseButton then return end
    if self.isVipPurchased then
        self.purchaseButton:SetVisible(false)
        if self.priceFrame then self.priceFrame:SetVisible(false) end
        return
    end
    
    -- 获取商品价格信息
    local cost = self.vipShopItem:GetCost()
    if not cost then return end
    
    local have = self.currencyMap[cost.item] or 0
    local enough = have >= cost.amount
    self.purchaseButton:SetGray(not enough)
    self.purchaseButton:SetTouchEnable(enough, nil)
end

-------------------------------------------------------------------
-- 商城数据同步与按钮显示控制
-------------------------------------------------------------------

function PrivilegedVIPGui:OnShopDataSync(data)
    -- data.data.shopData 为完整商城数据
    local payload = data and data.data
    if not payload or not payload.shopData then return end
    self.shopData = payload.shopData

    -- 判断VIP是否已购买：以 configName 作为购买记录键
    if self.vipShopItem and self.shopData.purchaseRecords then
        local record = self.shopData.purchaseRecords[self.vipShopItem.configName]
        if record and (record.purchaseCount or 0) > 0 then
            self.isVipPurchased = true
        else
            self.isVipPurchased = false
        end
        self:UpdatePurchaseButtonVisibility()
    end
end

function PrivilegedVIPGui:UpdatePurchaseButtonVisibility()
    if not self.purchaseButton then return end
    local visible = not self.isVipPurchased
    self.purchaseButton:SetVisible(visible)
    if self.priceFrame then self.priceFrame:SetVisible(visible) end
end

return PrivilegedVIPGui.New(script.Parent, uiConfig)
