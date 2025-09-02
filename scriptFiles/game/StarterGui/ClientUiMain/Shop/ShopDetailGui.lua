-- ShopDetailGui.lua
-- 商城UI界面逻辑

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
    uiName = "ShopDetailGui",
    layer = 3, -- 根据实际情况调整
    hideOnInit = true,
}

---@class ShopDetailGui : ViewBase
local ShopDetailGui = ClassMgr.Class("ShopDetailGui", ViewBase)

---@override
function ShopDetailGui:OnInit(node, config)
        -- 2. 数据存储
    self:InitData()
    -- 1. 节点初始化
    self:InitNodes()


    -- 3. 事件注册
    self:RegisterEvents()

    -- 4. 按钮点击事件注册
    self:RegisterButtonEvents()

    -- 5. 初始化UI内容
    self:InitShop()

    ----gg.log("ShopDetailGui 商城界面初始化完成")
end

-- 节点初始化
function ShopDetailGui:InitNodes()
    self.shopPanel = self:Get("商城底图", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("商城底图/关闭", ViewButton) ---@type ViewButton
    self.titleLabel = self:Get("商城底图/商店标题", ViewComponent) ---@type ViewComponent

    -- 左侧分类栏
    self.categoryList = self:Get("商城底图/左侧主选框/左侧主栏位", ViewList) ---@type ViewList
    self.categoryDemo = self:Get("商城底图/左侧主选框/左侧主栏位/左侧主选中框", ViewComponent) ---@type ViewComponent
    
    -- 右侧物品栏
    self.itemList = self:Get("商城底图/右侧物品栏/物品右侧显示底图/物品模板栏位", ViewList) ---@type ViewList
    self.itemDemo = self:Get("商城底图/右侧物品栏/物品右侧显示底图/物品模板栏位/物品显示", ViewComponent) ---@type ViewComponent
    self.itemList:SetVisible(false)
    -- 物品详情
    self.itemDescription = self:Get("商城底图/右侧物品栏/物品显示", ViewComponent) ---@type ViewComponent
    
    -- 价格图节点 - 获取现有的ViewButton类型节点
    self.miniCoinPriceButton = self:Get("商城底图/右侧物品栏/物品显示/物品显示底图/迷你币价格图", ViewButton) ---@type ViewButton
    self.goldPriceButton = self:Get("商城底图/右侧物品栏/物品显示/物品显示底图/货币价格图", ViewButton) ---@type ViewButton
end

-- 数据初始化
function ShopDetailGui:InitData()
    self.shopCategories = {} -- 商城分类
    self.currencyMap = {}    -- 玩家货币缓存
    self.selectedCategory = nil -- 当前选中的分类
    self.selectedItem = nil     -- 当前选中的商品
    self.categoryButtons = {} -- 分类按钮
    self.categoryShopItems= {}
    self.shopData = nil -- 商城云端数据缓存
    -- "宠物"， "金币"
    -- 商品类型列表
    self.productTypes = {"伙伴", "翅膀", "尾迹", "宠物","特权",}
    
    -- 为每个商品类型创建对应的itemList
    self.categoryItemLists = {}
    
    -- 为每个商品类型创建对应的按钮表
    self.productTypesTable = {}
end

-- 注册客户端事件
function ShopDetailGui:RegisterEvents()
    ----gg.log("注册商城系统事件监听")
    ClientEventManager.Subscribe(ShopEventConfig.RESPONSE.SHOP_LIST_RESPONSE, function(data)
        self:OnShopListResponse(data)
    end)
    ClientEventManager.Subscribe(ShopEventConfig.RESPONSE.PURCHASE_RESPONSE, function(data)
        self:OnPurchaseResponse(data)
    end)
    -- 【新增】迷你币购买响应
    ClientEventManager.Subscribe(ShopEventConfig.RESPONSE.MINI_PURCHASE_RESPONSE, function(data)
        self:OnMiniPurchaseResponse(data)
    end)
    ClientEventManager.Subscribe(ShopEventConfig.RESPONSE.ERROR, function(data)
        self:OnShopErrorResponse(data)
    end)
    ClientEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, function(data)
        self:OnSyncInventoryItems(data)
    end)
    -- 监听商城数据同步，用于判断永久一次的商品是否已购买
    ClientEventManager.Subscribe(ShopEventConfig.NOTIFY.SHOP_DATA_SYNC, function(data)
        self:OnShopDataSync(data)
    end)
end

-- 注册按钮事件
function ShopDetailGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
    end
    
    -- 为迷你币价格图按钮绑定点击事件
    self.miniCoinPriceButton.clickCb = function()
        if self.selectedItem then
            self:SendMiniCoinPurchaseRequest(self.selectedItem, self.selectedCategory)
        end
    end
    
    -- 为货币价格图按钮绑定点击事件
    self.goldPriceButton.clickCb = function()
        if self.selectedItem then
            self:SendNormalPurchaseRequest(self.selectedItem, self.selectedCategory, "金币")
        end
    end
end

-- 初始化商城
function ShopDetailGui:InitShop()
    -- 使用预定义的商品类型列表
    self:SetupCategories(self.productTypes)
    
    -- -- 预加载所有分类的商品数据
    self.categoryShopItems = {}
    for _, categoryName in ipairs(self.productTypes) do
        self.categoryShopItems[categoryName] = ConfigLoader.GetShopItemsByCategory(categoryName)
    end
    
    -- 预加载完成后，默认选中第一个分类并填充对应的物品list
    local firstCategory = self.productTypes[1]
    if firstCategory then
        self:SelectCategory(firstCategory)
    end
end

--- UI打开时调用
function ShopDetailGui:OnOpen()
    ----gg.log("ShopDetailGui 打开，请求默认商品列表")
    -- 默认选中第一个分类并请求数据
    -- if self.selectedCategory then
    --     self:RequestShopList(self.selectedCategory)
    -- elseif #self.shopCategories > 0 then
    --     self:SelectCategory(self.shopCategories[1].name) 
    -- end
end

--- UI关闭时调用
function ShopDetailGui:OnClose()
    ----gg.log("ShopDetailGui 关闭")
end

-------------------------------------------------------------------
-- 分类处理
-------------------------------------------------------------------

--- 设置商品分类
function ShopDetailGui:SetupCategories(categories)
    self.categoryList:SetElementSize(#categories)
    for i, categoryName in ipairs(categories) do
        local categoryNode = self.categoryList:GetChild(i)
        categoryNode.node["标题"].Title = categoryName
        categoryNode.node.Visible = true
        categoryNode.node.Name = categoryName
        
        local button = ViewButton.New(categoryNode.node, self, "CategoryButton" .. i)
        button.clickCb = function()
            self:SelectCategory(categoryName)
        end
        table.insert(self.shopCategories, { name = categoryName, node = categoryNode.node })
        self.categoryButtons[categoryName] = categoryNode.node
        
        -- 为每个分类创建对应的itemList克隆
        local itemListClone = self.itemList.node:Clone()
        itemListClone:ClearAllChildren()
        itemListClone.Name = categoryName .."_栏位"
        itemListClone.Parent = self.itemList.node.Parent
        local categoryItemList = ViewList.New(itemListClone, self, "CategoryList" .. i, function(child)
            return ViewComponent.New(child, self, child.Name)
        end)
        categoryItemList.node.Visible = false
        self.categoryItemLists[categoryName] = categoryItemList
        --gg.log("categoryItemLists", self.categoryItemLists)
        self:AppendShopItemList(categoryName)
    end
    
    -- 移除这里的SelectCategory调用，改为在InitShop完成后调用
end

--- 选中分类
function ShopDetailGui:SelectCategory(categoryName)
    if self.selectedCategory == categoryName then
        return 
    end
    self.selectedCategory = categoryName
    ----gg.log("选中分类: " .. categoryName)
    
    -- 更新分类按钮的选中状态
    for name, node in pairs(self.categoryButtons) do
        local selectionFrame = node:FindFirstChild("左侧主选中框") 
        if selectionFrame then
             selectionFrame.Visible = (name == self.selectedCategory)
        end
    end
    
    -- 隐藏所有分类的itemList
    for name, itemList in pairs(self.categoryItemLists) do
        if itemList and itemList.node then
            itemList.node.Visible = false
        end
    end
    
    -- 显示当前选中分类的itemList
    local currentItemList = self.categoryItemLists[categoryName]
    if currentItemList and currentItemList.node then
        currentItemList.node.Visible = true
        ----gg.log("显示分类: " .. categoryName .. " 的itemList")
        
        -- 切换分类后，默认选中第一个商品
        local shopItems = ConfigLoader.GetShopItemsByCategory(categoryName)
        if shopItems and #shopItems > 0 then
            local firstItem = shopItems[1]
            self:SelectItem(firstItem.configName)
        end
    else
        ----gg.log("错误：找不到分类 " .. categoryName .. " 的itemList")
    end
end

--- 加载指定分类的商品数据


-------------------------------------------------------------------
-- 商品处理
-------------------------------------------------------------------

--- 刷新商品列表UI
function ShopDetailGui:AppendShopItemList(categoryName)

    local shopItems = ConfigLoader.GetShopItemsByCategory(categoryName)
    --gg.log("categoryName",categoryName)
    --gg.log("shopItems",shopItems)
    
    --gg.log("刷新商品列表，数量: " .. #shopItems)
    
    -- 按照价格排序权重由小到大排序
    table.sort(shopItems, function(a, b)
        local aSortWeight = tonumber(a.uiConfig.sortWeight) or 0
        local bSortWeight = tonumber(b.uiConfig.sortWeight) or 0
        return aSortWeight < bSortWeight
    end)
    
    local currentItemList = self.categoryItemLists[categoryName] ---@type ViewList
    if not currentItemList then return end
    -- 清空现有内容
    currentItemList.node:ClearAllChildren()
    
    -- 初始化该分类的按钮表
    self.productTypesTable[categoryName] = {}
    
    --- @type ShopItemType
    for i, shopItemTypeData in ipairs(shopItems) do
        local itemNodeClone = self.itemDemo.node:Clone()
        itemNodeClone.Name = shopItemTypeData.configName
        itemNodeClone.Parent = currentItemList.node
        currentItemList:AppendChild(itemNodeClone) -- 使用用户指定的AppendChild
        
        local iconPath = shopItemTypeData.uiConfig.iconPath
        local backgroundStyle = shopItemTypeData:GetBackgroundStyle()
        if iconPath and iconPath ~="" then
            itemNodeClone["物品图标"].Icon = shopItemTypeData.uiConfig.iconPath
        end
   
        itemNodeClone.Icon= CardIcon.qualityBackGroundIcon[backgroundStyle]
        itemNodeClone:SetAttribute("图片-点击", shopItemTypeData.uiConfig.iconPath)
        itemNodeClone:SetAttribute("图片-悬浮", CardIcon.qualityBackGroundIcon[backgroundStyle])
        -- 为每个商品创建购买按钮
        local purchaseButton = ViewButton.New(itemNodeClone, self)
        purchaseButton.clickCb = function()
            self:SelectItem(shopItemTypeData.configName)
        end
        
        -- 将按钮存储到productTypesTable中
        self.productTypesTable[categoryName][shopItemTypeData.configName] = {
            button = purchaseButton,
            shopItem = shopItemTypeData
        }
    end
    
    -- 默认选中第一个商品
    if #shopItems > 0 then
        local firstItem = shopItems[1]
        self:SelectItem(firstItem.configName)
    end
    
end





--- 选中某个商品，显示详情
function ShopDetailGui:SelectItem(configName)
    self.selectedItem = configName
    
    local shopItemTypeData = ConfigLoader.GetShopItem(configName)
    if not shopItemTypeData then return end
    
    local itemDescription = self.itemDescription.node
    itemDescription["物品介绍"]["物品名称"].Title = shopItemTypeData.configName
    itemDescription["物品介绍"]["描述"].Title = shopItemTypeData.description

    
    local iconPath = shopItemTypeData.uiConfig.iconPath
    local miniCoinAmount = shopItemTypeData.price.miniCoinAmount
    local goldAmount = shopItemTypeData.price.amount
    local currencyType = shopItemTypeData.price.currencyType
    
    if iconPath and iconPath ~="" then
        itemDescription["物品显示底图"]["物品图标"].Icon = shopItemTypeData.uiConfig.iconPath
    end
    
    -- 使用ViewButton节点设置迷你币价格
    if miniCoinAmount and miniCoinAmount > 0 then
        self.miniCoinPriceButton.node.Visible = true
        self.miniCoinPriceButton.node["价格框"].Title = "" .. miniCoinAmount
    else
        self.miniCoinPriceButton.node.Visible = false
    end
    
    -- 根据金币配置决定是否显示金币购买按钮
    if goldAmount and goldAmount > 0 and currencyType == "金币" then
        self.goldPriceButton.node.Visible = true
        self.goldPriceButton.node["价格框"].Title = gg.FormatLargeNumber(goldAmount)
    else
        self.goldPriceButton.node.Visible = false
    end

    -- 选中后基于限购与购买记录控制按钮可见性
    self:UpdateSelectedItemButtonsVisibility()
end

--- 清空选中的商品详情
function ShopDetailGui:ClearSelectedItem()
    self.selectedItem = nil
    -- 清空商品详情显示
    local itemDescription = self.itemDescription.node
    if itemDescription["物品介绍"] and itemDescription["物品介绍"]["物品名称"] then
        itemDescription["物品介绍"]["物品名称"].Title = ""
    end
end

-------------------------------------------------------------------
-- 网络请求
-------------------------------------------------------------------

-- 【新增】迷你币购买请求
function ShopDetailGui:SendMiniCoinPurchaseRequest(shopItemId, categoryName)
    local args = { shopItemId = shopItemId, categoryName = categoryName }
    --gg.log("发送迷你币购买请求, 商品ID: " .. shopItemId .. ", 事件: " .. ShopEventConfig.REQUEST.PURCHASE_MINI_ITEM)
    gg.network_channel:FireServer({
        cmd = ShopEventConfig.REQUEST.PURCHASE_MINI_ITEM,
        args = args
    })
end

-- 【新增】普通货币购买请求
function ShopDetailGui:SendNormalPurchaseRequest(shopItemId, categoryName, currencyType)
    --gg.log("发送普通货币购买请求, 商品ID: " .. shopItemId .. ", 货币类型: " .. currencyType)
    gg.network_channel:FireServer({
        cmd = ShopEventConfig.REQUEST.PURCHASE_ITEM,
        args = { shopItemId = shopItemId, categoryName = categoryName, currencyType = currencyType }
    })
end


-------------------------------------------------------------------
-- 事件响应
-------------------------------------------------------------------

function ShopDetailGui:OnShopListResponse(data)
    if data and data.success and data.data and data.data.category == self.selectedCategory then
        ----gg.log("收到商品列表响应: ", data)
        self:RefreshItemList(data.data.itemList)
    else
        ----gg.log("获取商品列表失败: " .. (data and data.errorMsg or "未知错误"))
    end
end

function ShopDetailGui:OnPurchaseResponse(data)
    if data and data.success then
        ----gg.log("普通货币购买成功: " .. (data.data and data.data.message or ""))
        self:UpdateSelectedItemButtonsVisibility()
    else
        ----gg.log("普通货币购买失败: " .. (data and data.errorMsg or "未知错误"))
    end
end

-- 【新增】迷你币购买响应处理
function ShopDetailGui:OnMiniPurchaseResponse(data)
    if data and data.success then
        if data.data.status == "pending" then
            ----gg.log("迷你币支付弹窗已拉起: " .. (data.data.message or ""))
        elseif data.data.status == "success" then
            ----gg.log("迷你币购买成功: " .. (data.data.message or ""))
            self:UpdateSelectedItemButtonsVisibility()
        end
    else
        ----gg.log("迷你币购买失败: " .. (data and data.errorMsg or "未知错误"))
    end
end

function ShopDetailGui:OnShopErrorResponse(data)
    ----gg.log("收到商城系统错误: ", data and data.errorMsg)
end

function ShopDetailGui:OnSyncInventoryItems(data)
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
        ----gg.log("商城界面已同步货币数据", self.currencyMap)
        self:RefreshAllPurchaseButtons()
    end
end

-------------------------------------------------------------------
-- UI 更新
-------------------------------------------------------------------

function ShopDetailGui:UpdatePurchaseButtonState(button, shopItemTypeData)
    if not button or not shopItemTypeData then return end
    
    -- 获取商品价格信息
    local cost = shopItemTypeData:GetCost()
    if not cost then return end
    
    local have = self.currencyMap[cost.item] or 0
    local enough = have >= cost.amount
    button:SetGray(not enough)
    button:SetTouchEnable(enough, nil)
end

function ShopDetailGui:RefreshAllPurchaseButtons()
    -- 刷新当前选中分类的所有购买按钮
    if self.selectedCategory and self.productTypesTable[self.selectedCategory] then
        for _, buttonData in pairs(self.productTypesTable[self.selectedCategory]) do
            self:UpdatePurchaseButtonState(buttonData.button, buttonData.shopItem)
        end
    end
end

-------------------------------------------------------------------
-- 商城数据同步与限购判断
-------------------------------------------------------------------

function ShopDetailGui:OnShopDataSync(data)
    local payload = data and data.data
    if not payload or not payload.shopData then return end
    self.shopData = payload.shopData

    -- 当前商品刷新按钮可见性
    self:UpdateSelectedItemButtonsVisibility()
end

--- 判断指定商品是否已购买（根据purchaseRecords）
---@param itemId string
---@return boolean
function ShopDetailGui:IsItemPurchased(itemId)
    if not self.shopData or not self.shopData.purchaseRecords then return false end
    local record = self.shopData.purchaseRecords[itemId]
    return record and (record.purchaseCount or 0) > 0 or false
end

--- 基于限购类型（永久一次）与购买记录，控制当前选中商品的购买按钮显示
function ShopDetailGui:UpdateSelectedItemButtonsVisibility()
    if not self.selectedItem then return end
    local shopItemTypeData = ConfigLoader.GetShopItem(self.selectedItem)
    if not shopItemTypeData then return end

    local isPermanentOnce = (shopItemTypeData.limitConfig and shopItemTypeData.limitConfig.limitType == "永久一次")
    local purchased = self:IsItemPurchased(shopItemTypeData.configName)

    if isPermanentOnce and purchased then
        if self.miniCoinPriceButton and self.miniCoinPriceButton.node then
            self.miniCoinPriceButton.node.Visible = false
        end
        if self.goldPriceButton and self.goldPriceButton.node then
            self.goldPriceButton.node.Visible = false
        end
    end
end

return ShopDetailGui.New(script.Parent, uiConfig)
