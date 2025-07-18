local MainStorage = game:GetService("MainStorage")
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.Code.Client.ClientScheduler)
local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local MConfig = require(MainStorage.Code.Common.GameConfig.MConfig) ---@type common_config


---@class HudMoney:ViewBase
local HudMoney = ClassMgr.Class("HudMoney", ViewBase)

local uiConfig = {
    uiName = "HudMoney",
    layer = -1,
    hideOnInit = false,
    closeHuds = false
}

---@class MoneyAddPool
---@field pool UITextLabel[] 对象池
---@field template UITextLabel 模板对象
local MoneyAddPool = {
    pool = {},
    template = nil
}

--- 从对象池获取一个文本标签
---@return UITextLabel
function MoneyAddPool:Get()
    local label = table.remove(self.pool)
    if not label then
        -- 如果对象池为空，创建新对象
        label = self.template:Clone()
        label.Parent = self.template.Parent
    end
    return label
end

--- 将文本标签放回对象池
---@param label UITextLabel
function MoneyAddPool:Return(label)
    label.Visible = false
    label.Scale = Vector2.New(1, 1)
    table.insert(self.pool, label)
end

function OnMoneyClick(ui, viewButton)
end

function HudMoney:OnInit(node, config)
    gg.log("菜单按钮HudMoney初始化")
    self.selectingCard = 0
    -- 初始化对象池
    MoneyAddPool.template = self:Get("货币增加").node ---@type UITextLabel
    MoneyAddPool.template.Visible = false

    self.moneyButtonList = self:Get("货币",ViewList) ---@type ViewList<ViewButton>


    gg.log("self.moneyButtonList ",self.moneyButtonList ,self.moneyButtonList.node["金币"])
    ClientEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, function(data)

        self:OnSyncInventoryItems(data)
    end)
    gg.log("按钮初始化结束")

end

function HudMoney:OnSyncInventoryItems(data)
    gg.log("背包数据更新")

    local items = data.items
    if not items then 
        gg.log("警告：数据中没有items字段")
        return 
    end

    -- 获取货币类型物品
    local currencyItems = {}
    local currencyType = MConfig.ItemTypeEnum["货币"]
    gg.log("服务的背包数据",items)
    -- 遍历所有分类，查找货币类型的物品
    for category, itemList in pairs(items) do
        if tonumber(category) == currencyType and itemList then
            for _, item in ipairs(itemList) do
                if item.itemCategory == currencyType then
                    table.insert(currencyItems, item)
                end
            end
        end
    end

    gg.log("客户端加载的货币的数量:", currencyItems)

    -- 如果没有货币物品，清空显示
    if #currencyItems == 0 then
        self:ClearMoneyDisplay()
        return
    end

    -- 更新货币显示，使用名称查找按钮
    for _, currencyItem in ipairs(currencyItems) do
        local button = self.moneyButtonList:GetChildByName(currencyItem.name)
        if button then
            local node = button:Get("Text").node ---@cast node UITextLabel
            local currentAmount = currencyItem.amount or 0

            -- 检查是否需要显示货币增加动画
            if self:ShouldShowMoneyAddition(currencyItem.name, currentAmount) then
                self:ShowMoneyAddAnimation(currencyItem, currentAmount, node)
            end

            -- 更新显示文本
            local displayText = self:GenerateDisplayText(currencyItem)
            node.Title = displayText

            gg.log("更新货币显示:", currencyItem.name, "数量:", currentAmount, "显示:", displayText)
        else
            gg.log("警告：找不到货币按钮，名称=", currencyItem.name)
        end
    end

    -- 更新记录的货币值
    self:UpdateLastMoneyValues(currencyItems)
end

function HudMoney:ClearMoneyDisplay()
    for i = 1, self.moneyButtonList:GetChildCount() do
        local button = self.moneyButtonList:GetChild(i)
        if button then
            local node = button:Get("Text").node ---@cast node UITextLabel
            node.Title = "0"
        end
    end
end

function HudMoney:GenerateDisplayText(currencyItem)
    local itemType = ConfigLoader.GetItem(currencyItem.name)
    local mainAmount = currencyItem.amount or 0

    -- 检查是否有进位关系
    if itemType and itemType.minorPrice and itemType.minorPriceAmount and itemType.minorPriceAmount > 0 then
        -- 这里需要从当前的currencyItems中查找对应的次级货币
        -- 暂时简化处理，直接显示主货币
        return gg.FormatLargeNumber(mainAmount)
    else
        -- 没有进位关系，直接显示
        return gg.FormatLargeNumber(mainAmount)
    end
end

function HudMoney:ShouldShowMoneyAddition(itemName, currentAmount)
    if not self.lastMoneyValues then
        return false
    end

    local lastAmount = self.lastMoneyValues[itemName] or 0
    return currentAmount > lastAmount
end

function HudMoney:ShowMoneyAddAnimation(currencyItem, currentAmount, targetNode)
    local moneyAdd = MoneyAddPool:Get()
    if not moneyAdd then 
        gg.log("警告：无法从对象池获取货币增加标签")
        return 
    end

    -- 计算增加值
    local lastAmount = self.lastMoneyValues[currencyItem.name] or 0
    local diff = currentAmount - lastAmount
    moneyAdd.Title = "+" .. gg.FormatLargeNumber(diff)

    -- 设置图标
    local itemType = ConfigLoader.GetItem(currencyItem.name)
    if itemType and itemType.icon then
        moneyAdd["资源图标"].Icon = itemType.icon
    end

    -- 设置初始状态
    moneyAdd.Scale = Vector2.New(2, 2)
    moneyAdd.Visible = true

    local screenSize = gg.get_ui_size()
    local randomOffsetX = (math.random() * 0.4 - 0.2) * screenSize.x
    local randomOffsetY = (math.random() * 0.4 - 0.2) * screenSize.y
    moneyAdd.Position = Vector2.New(
        screenSize.x/2 + randomOffsetX,
        screenSize.y/2 + randomOffsetY
    )

    -- 执行动画
    local tweenInfo = TweenInfo.New(1, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    local tween = TweenService:Create(moneyAdd, tweenInfo, {
        Position = targetNode:GetGlobalPos(),
        Scale = Vector2.New(1, 1)
    })

    tween:Play()
    tween.Completed:Connect(function()
        MoneyAddPool:Return(moneyAdd)
    end)
end

function HudMoney:UpdateLastMoneyValues(currencyItems)
    if not self.lastMoneyValues then
        self.lastMoneyValues = {}
    end

    -- 使用物品名称作为键来记录
    for _, currencyItem in ipairs(currencyItems) do
        self.lastMoneyValues[currencyItem.name] = currencyItem.amount or 0
    end
end

return HudMoney.New(script.Parent, uiConfig)
