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
    --gg.log("菜单按钮HudMoney初始化")
    self.selectingCard = 0

    -- 【新增】初始化货币数据缓存
    self.currentCurrencyData = {}

    -- 【新增】初始化玩家变量数据缓存
    self.playerVariableData = {}

    -- 初始化对象池
    MoneyAddPool.template = self:Get("货币增加").node ---@type UITextLabel
    MoneyAddPool.template.Visible = false

    self.moneyButtonList = self:Get("货币底图/货币",ViewList) ---@type ViewList<ViewButton>

    --gg.log("self.moneyButtonList ",self.moneyButtonList ,self.moneyButtonList.node["金币"])
    ClientEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, function(data)
        self:OnSyncInventoryItems(data)
    end)

    -- 【新增】订阅玩家变量数据同步事件
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE, function(data)
        self:OnSyncPlayerVariables(data)
    end)

    --gg.log("按钮初始化结束")
end

function HudMoney:OnSyncInventoryItems(data)
    gg.log("HudMoney:OnSyncInventoryItems", data)
    local items = data.items
    if not items then
        return
    end

    local currencyType = MConfig.ItemTypeEnum["货币"]

    -- 1. 检查更新中是否包含货币数据
    local incomingCurrencyList = nil
    for category, itemList in pairs(items) do
        if tonumber(category) == currencyType and itemList then
            incomingCurrencyList = itemList
            break
        end
    end

    -- 如果此数据包中没有货币信息，则不进行任何操作
    if not incomingCurrencyList then
        return
    end

    -- 2. 使用新数据建立一个临时的货币数据映射
    local newCurrencyData = {}
    for _, item in pairs(incomingCurrencyList) do
        if item and item.name then
            newCurrencyData[item.name] = item
        end
    end
    
    -- 更新主数据缓存
    self.currentCurrencyData = newCurrencyData

    -- 3. 遍历所有UI上的货币按钮，并用新数据更新它们
    for i = 1, self.moneyButtonList:GetChildCount() do
        local button = self.moneyButtonList:GetChild(i)
        if button and button.node then
            local currencyName = button.node.Name
            local currencyItem = self.currentCurrencyData[currencyName] -- 如果货币不存在，这里会是nil
            local newAmount = (currencyItem and currencyItem.amount) or 0

            local textNode = button:Get("Text").node ---@cast textNode UITextLabel

            -- 仅当物品真实存在时，才可能触发增加动画
            if currencyItem and self:ShouldShowMoneyAddition(currencyName, newAmount) then
                self:ShowMoneyAddAnimation(currencyItem, newAmount, textNode)
            end
            
            -- 更新显示文本
            if currencyItem then
                textNode.Title = self:GenerateDisplayText(currencyItem)
            else
                -- 如果新数据中没有这个货币，显示为0
                textNode.Title = gg.FormatLargeNumber(0)
            end

            -- 更新用于动画的缓存值
            if not self.lastMoneyValues then self.lastMoneyValues = {} end
            self.lastMoneyValues[currencyName] = newAmount
        end
    end
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
        --gg.log("警告：无法从对象池获取货币增加标签")
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
    --gg.log("HudMoney收到玩家变量数据同步:", data)

    if not data or not data.variableData then
        --gg.log("警告：玩家变量数据为空")
        return
    end

    -- 检查战力值是否有变化
    local powerData = data.variableData["数据_固定值_战力值"]
    if powerData then
        local newPowerValue = (powerData and powerData.base) or 0
        local oldPowerValue = (self.playerVariableData and self.playerVariableData["数据_固定值_战力值"] and self.playerVariableData["数据_固定值_战力值"].base) or 0
        
        -- 如果战力值增加了，显示动画
        if newPowerValue > oldPowerValue then
            local energyButton = self.moneyButtonList:GetChildByName("能量")
            if energyButton then
                local textNode = energyButton:Get("Text").node ---@cast textNode UITextLabel
                self:ShowVariableAddAnimation("数据_固定值_战力值", oldPowerValue, newPowerValue, textNode)
            end
        end
    end

    -- 检查重生次数是否有变化
    local rebirthData = data.variableData["数据_固定值_重生次数"]
    if rebirthData then
        local newRebirthValue = (rebirthData and rebirthData.base) or 0
        local oldRebirthValue = (self.playerVariableData and self.playerVariableData["数据_固定值_重生次数"] and self.playerVariableData["数据_固定值_重生次数"].base) or 0
        
        -- 如果重生次数增加了，显示动画
        if newRebirthValue > oldRebirthValue then
            local rebirthButton = self.moneyButtonList:GetChildByName("重生次数")
            if rebirthButton then
                local textNode = rebirthButton:Get("Text").node ---@cast textNode UITextLabel
                self:ShowVariableAddAnimation("数据_固定值_重生次数", oldRebirthValue, newRebirthValue, textNode)
            end
        end
    end

    -- 更新本地变量数据缓存
    self.playerVariableData = data.variableData

    -- 更新UI显示
    self:UpdateVariableDisplay()
end

--- 【新增】显示变量增加动画
---@param variableName string 变量名
---@param oldValue number 旧值
---@param newValue number 新值
---@param targetNode UITextLabel 目标文本节点
function HudMoney:ShowVariableAddAnimation(variableName, oldValue, newValue, targetNode)
    local moneyAdd = MoneyAddPool:Get()
    if not moneyAdd then
        --gg.log("警告：无法从对象池获取变量增加标签")
        return
    end

    -- 计算增加值
    local diff = newValue - oldValue
    moneyAdd.Title = "+" .. gg.FormatLargeNumber(diff)

    -- 根据变量名设置不同的图标（这里可以根据需要扩展）
    if variableName == "数据_固定值_战力值" then
        -- 可以设置战力值相关的图标
        -- moneyAdd["资源图标"].Icon = "战力值图标路径"
    elseif variableName == "数据_固定值_重生次数" then
        -- 可以设置重生次数相关的图标
        -- moneyAdd["资源图标"].Icon = "重生次数图标路径"
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

--- 【修改后】更新变量相关的UI显示
function HudMoney:UpdateVariableDisplay()
    -- 更新重生次数显示
    local rebirthData = self.playerVariableData["数据_固定值_重生次数"]
    local rebirthCount = (rebirthData and rebirthData.base) or 0
    local rebirthButton = self.moneyButtonList:GetChildByName("重生次数")
    if rebirthButton then
        local textNode = rebirthButton:Get("Text").node ---@cast textNode UITextLabel
        textNode.Title = tostring(math.floor(rebirthCount))
        --gg.log("更新重生次数显示:", rebirthCount)
    else
        --gg.log("警告：找不到重生次数按钮节点")
    end

    -- 更新战力值显示（对应能量节点）
    local powerData = self.playerVariableData["数据_固定值_战力值"]
    --gg.log("powerData", powerData)
    local powerValue = (powerData and powerData.base) or 0
    local energyButton = self.moneyButtonList:GetChildByName("能量")
    if energyButton then
        local textNode = energyButton:Get("Text").node ---@cast textNode UITextLabel
        textNode.Title = gg.FormatLargeNumber(powerValue)
        --gg.log("更新战力值显示:", powerValue)
    else
        --gg.log("警告：找不到能量按钮节点")
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


