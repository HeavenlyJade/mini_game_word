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
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig


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

-- 【新增】初始化方法中添加货币数据缓存初始化
function HudMoney:OnInit(node, config)
    gg.log("菜单按钮HudMoney初始化")
    self.selectingCard = 0
    
    -- 【新增】初始化货币数据缓存
    self.currentCurrencyData = {}
    
    -- 【新增】初始化玩家变量数据缓存
    self.playerVariableData = {}
    
    -- 初始化对象池
    MoneyAddPool.template = self:Get("货币增加").node ---@type UITextLabel
    MoneyAddPool.template.Visible = false

    self.moneyButtonList = self:Get("货币底图/货币",ViewList) ---@type ViewList<ViewButton>

    gg.log("self.moneyButtonList ",self.moneyButtonList ,self.moneyButtonList.node["金币"])
    ClientEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, function(data)
        self:OnSyncInventoryItems(data)
    end)
    
    -- 【新增】订阅玩家变量数据同步事件
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE, function(data)
        self:OnSyncPlayerVariables(data)
    end)
    
    gg.log("按钮初始化结束")
end

function HudMoney:OnSyncInventoryItems(data)

    local items = data.items
    if not items then 
        gg.log("警告：数据中没有items字段")
        return 
    end

    -- 初始化当前的货币数据缓存（如果不存在）
    if not self.currentCurrencyData then
        self.currentCurrencyData = {}
    end

    local currencyType = MConfig.ItemTypeEnum["货币"]
    
    -- 【关键修改】更新货币数据缓存
    local hasUpdateData = false
    for category, itemList in pairs(items) do
        if category == currencyType and itemList then
            hasUpdateData = true
            -- 【重要】这里要按位置索引更新，而不是按数组遍历
            for slotIndex, item in pairs(itemList) do
                if item and item.itemCategory == currencyType then
                    -- 直接使用服务端发送的最新数据
                    self.currentCurrencyData[item.name] = item
                    gg.log("更新货币缓存:", item.name, "数量:", item.amount, "位置:", slotIndex)
                end
            end
        end
    end

    -- 如果没有货币数据更新，直接返回，保持当前显示
    if not hasUpdateData then
        gg.log("本次同步没有货币数据变更，保持当前显示")
        return
    end

    -- 转换为数组格式以兼容原有的显示逻辑
    local currencyItems = {}
    for itemName, currencyItem in pairs(self.currentCurrencyData) do
        table.insert(currencyItems, currencyItem)
    end



    -- 【修改】如果缓存为空才清空显示，避免误清空
    if #currencyItems == 0 then
        gg.log("警告：货币数据缓存为空，可能存在数据同步问题")
        -- 暂时不清空显示，等待后续数据
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

--- 【新增】接收并处理玩家变量数据同步
---@param data table 包含variableData的数据表
function HudMoney:OnSyncPlayerVariables(data)
    gg.log("HudMoney收到玩家变量数据同步:", data)
    
    if not data or not data.variableData then
        gg.log("警告：玩家变量数据为空")
        return
    end
    
    -- 更新本地变量数据缓存
    self.playerVariableData = data.variableData
    
    -- 更新UI显示
    self:UpdateVariableDisplay()
end

--- 【修改后】更新变量相关的UI显示
function HudMoney:UpdateVariableDisplay()
    -- 更新重生次数显示
    local rebirthData = self.playerVariableData["数据_固定值_重生次数"]
    local rebirthCount = (rebirthData and rebirthData.base) or 0
    local rebirthButton = self.moneyButtonList:GetChildByName("重生次数")
    if rebirthButton then
        local textNode = rebirthButton:Get("Text").node ---@cast textNode UITextLabel
        textNode.Title = tostring(math.floor(rebirthCount))
        gg.log("更新重生次数显示:", rebirthCount)
    else
        gg.log("警告：找不到重生次数按钮节点")
    end
    
    -- 更新战力值显示（对应能量节点）
    local powerData = self.playerVariableData["数据_固定值_战力值"]
    gg.log("powerData", powerData)
    local powerValue =  powerData.base or 0
    local energyButton = self.moneyButtonList:GetChildByName("能量")
    if energyButton then
        local textNode = energyButton:Get("Text").node ---@cast textNode UITextLabel
        textNode.Title = gg.FormatLargeNumber(powerValue)
        gg.log("更新战力值显示:", powerValue)
    else
        gg.log("警告：找不到能量按钮节点")
    end
end

--- 【修改后】获取指定变量的base值
---@param variableName string 变量名
---@return number 变量的base值，如果不存在则返回0
function HudMoney:GetVariableValue(variableName)
    local varData = self.playerVariableData[variableName]
    return (varData and varData.base) or 0
end

return HudMoney.New(script.Parent, uiConfig)

