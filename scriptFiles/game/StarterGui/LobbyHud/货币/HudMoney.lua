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

--- 【新增】按钮类型配置表
---@class ButtonTypeConfig
local ButtonTypeConfig = {
    -- 货币类型按钮
    CURRENCY = {
        "金币",
        "奖杯"
        -- 可以在这里添加更多货币类型
    },
    
    -- 变量类型按钮
    VARIABLE = {
        -- 按钮名称 -> 对应的变量名
        ["能量"] = "数据_固定值_战力值",
        ["重生次数"] = "数据_固定值_重生次数"
        -- 可以在这里添加更多变量类型
    }
}

--- 【新增】判断按钮类型的工具函数
---@param buttonName string 按钮名称
---@return string|nil 按钮类型 ("CURRENCY" 或 "VARIABLE" 或 nil)
function ButtonTypeConfig.GetButtonType(buttonName)
    -- 检查是否为货币按钮
    for _, currencyName in ipairs(ButtonTypeConfig.CURRENCY) do
        if buttonName == currencyName then
            return "CURRENCY"
        end
    end
    
    -- 检查是否为变量按钮
    for variableButtonName, _ in pairs(ButtonTypeConfig.VARIABLE) do
        if buttonName == variableButtonName then
            return "VARIABLE"
        end
    end
    
    return nil
end

--- 【新增】获取变量按钮对应的变量名
---@param buttonName string 按钮名称
---@return string|nil 对应的变量名
function ButtonTypeConfig.GetVariableName(buttonName)
    return ButtonTypeConfig.VARIABLE[buttonName]
end

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

    -- 【新增】初始化动画缓存值
    self.lastMoneyValues = {}

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

    -- 2. 初始化缓存
    if not self.currentCurrencyData then
        self.currentCurrencyData = {}
    end
    
    if not self.lastMoneyValues then
        self.lastMoneyValues = {}
    end
    
    -- 3. 将传入的货币列表转换为以名称为键的映射
    local newCurrencyMap = {}
    for _, item in pairs(incomingCurrencyList) do
        if item and item.name then
            newCurrencyMap[item.name] = item
        end
    end

    -- 4. 遍历UI中的所有货币按钮，进行更新
    for i = 1, self.moneyButtonList:GetChildCount() do
        local button = self.moneyButtonList:GetChild(i)
        if button and button.node then
            local currencyName = button.node.Name
            if self:IsCurrencyButton(currencyName) then
                local currencyItem = newCurrencyMap[currencyName]
                local textNode = button:Get("Text").node ---@cast textNode UITextLabel
                
                -- 【关键修复】只对同步包中存在的货币进行处理
                if currencyItem then
                    local newAmount = math.floor(currencyItem.amount or 0)
                    local oldAmount = math.floor(self.lastMoneyValues[currencyName] or 0)
                    local diff = newAmount - oldAmount
                    
                    -- 【修复核心】只有当差值大于0时才播放动画
                    if diff > 0 then
                        self:ShowMoneyAddAnimation(currencyItem, newAmount, textNode)
                    end
                    
                    -- 更新显示文本
                    textNode.Title = gg.FormatLargeNumber(newAmount)
                    
                    -- 更新用于动画的缓存值
                    self.lastMoneyValues[currencyName] = newAmount
                    
                    -- 更新货币数据缓存
                    self.currentCurrencyData[currencyName] = currencyItem
                end
                -- 【删除】不再处理未在同步包中的货币，避免误触发动画
            end
        end
    end
end


function HudMoney:ClearMoneyDisplay()
    for i = 1, self.moneyButtonList:GetChildCount() do
        local button = self.moneyButtonList:GetChild(i)
        if button and button.node then
            local buttonName = button.node.Name
            -- 【修改】只清除货币相关的按钮
            if self:IsCurrencyButton(buttonName) then
                local node = button:Get("Text").node ---@cast node UITextLabel
                node.Title = "0"
            end
        end
    end
end

--- 【修改】判断是否为货币相关的按钮
---@param buttonName string 按钮名称
---@return boolean 是否为货币按钮
function HudMoney:IsCurrencyButton(buttonName)
    return ButtonTypeConfig.GetButtonType(buttonName) == "CURRENCY"
end

--- 【新增】判断是否为变量相关的按钮
---@param buttonName string 按钮名称
---@return boolean 是否为变量按钮
function HudMoney:IsVariableButton(buttonName)
    return ButtonTypeConfig.GetButtonType(buttonName) == "VARIABLE"
end

function HudMoney:GenerateDisplayText(currencyItem)
    local mainAmount = currencyItem.amount or 0
    local intAmount = math.floor(mainAmount)
    return gg.FormatLargeNumber(intAmount)
  
end

function HudMoney:ShouldShowMoneyAddition(itemName, currentAmount)
    if not self.lastMoneyValues then
        return false
    end

    local lastAmount = math.floor(self.lastMoneyValues[itemName] or 0)
    return math.floor(currentAmount) > lastAmount
end

function HudMoney:ShowMoneyAddAnimation(currencyItem, currentAmount, targetNode)
    local moneyAdd = MoneyAddPool:Get()
    if not moneyAdd then
        --gg.log("警告：无法从对象池获取货币增加标签")
        return
    end

    -- 【修复】添加安全检查
    if not self.lastMoneyValues then
        self.lastMoneyValues = {}
    end

    -- 计算增加值
    local lastAmount = math.floor(self.lastMoneyValues[currencyItem.name] or 0)
    local diff = math.floor(currentAmount) - lastAmount
    moneyAdd.Title = "+" .. gg.FormatLargeNumber(math.floor(diff))
    -- 设置图标
    local itemType = ConfigLoader.GetItem(currencyItem.name) ---@type ItemType
    --gg.log("itemType.icon",itemType.icon)
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
        self.lastMoneyValues[currencyItem.name] = math.floor(currencyItem.amount or 0)
    end
end

--- 【新增】玩家变量数据同步处理（应用相同的修复逻辑）
---@param data table 包含variableData的数据表
function HudMoney:OnSyncPlayerVariables(data)
    if not data or not data.variableData then
        return
    end

    -- 初始化缓存
    if not self.playerVariableData then
        self.playerVariableData = {}
    end

    -- 【修复】先检查变化并播放动画，再更新缓存
    for buttonName, variableName in pairs(ButtonTypeConfig.VARIABLE) do
        local variableData = data.variableData[variableName]
        if variableData then
            -- 获取新值
            local newValue = 0
            if type(variableData) == "table" and variableData.base then
                newValue = variableData.base
            elseif type(variableData) == "number" then
                newValue = variableData
            elseif type(variableData) == "string" then
                newValue = tonumber(variableData) or 0
            end
            
            -- 获取旧值
            local oldValue = 0
            local oldVarData = self.playerVariableData[variableName]
            if oldVarData then
                if type(oldVarData) == "table" and oldVarData.base then
                    oldValue = oldVarData.base
                elseif type(oldVarData) == "number" then
                    oldValue = oldVarData
                elseif type(oldVarData) == "string" then
                    oldValue = tonumber(oldVarData) or 0
                end
            end
            
            local diff = math.floor(newValue) - math.floor(oldValue)
            
            -- 【修复核心】只有当差值大于0时才播放动画
            if diff > 0 then
                local button = self.moneyButtonList:GetChildByName(buttonName)
                if button then
                    local textNode = button:Get("Text").node ---@cast textNode UITextLabel
                    self:ShowVariableAddAnimation(variableName, oldValue, newValue, textNode)
                end
            end
        end
    end

    -- 合并新数据到现有缓存中
    for variableName, variableData in pairs(data.variableData) do
        self.playerVariableData[variableName] = variableData
    end

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
    local diff = math.floor(newValue) - math.floor(oldValue)
    moneyAdd.Title = "+" .. gg.FormatLargeNumber(math.floor(diff))

    -- 【修改】根据变量名设置对应的图标
    if variableName == "数据_固定值_战力值" then
        -- 战力值使用能力值图标
        moneyAdd["资源图标"].Icon = "sandboxId://FlyUi/迷你界面/物品图标/能力值.png"
    elseif variableName == "数据_固定值_重生次数" then
        -- 重生次数使用重生档位图标
        moneyAdd["资源图标"].Icon = "sandboxId://FlyUi/迷你界面/物品图标/重生档位.png"
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
    -- 遍历所有按钮，更新变量类型的按钮
    for i = 1, self.moneyButtonList:GetChildCount() do
        local button = self.moneyButtonList:GetChild(i)
        if button and button.node then
            local buttonName = button.node.Name
            
            -- 只处理变量类型的按钮
            if self:IsVariableButton(buttonName) then
                local variableName = ButtonTypeConfig.GetVariableName(buttonName)
                if variableName then
                                    local variableData = self.playerVariableData[variableName]
                -- 【优化】安全地获取变量值，支持多种数据格式
                local value = 0
                if variableData then
                    if type(variableData) == "table" and variableData.base then
                        value = variableData.base
                    elseif type(variableData) == "number" then
                        value = variableData
                    elseif type(variableData) == "string" then
                        value = tonumber(variableData) or 0
                    end
                end
                    local textNode = button:Get("Text").node ---@cast textNode UITextLabel
                    
                    -- 根据变量类型设置不同的显示格式
                    if variableName == "数据_固定值_战力值" then
                        textNode.Title = gg.FormatLargeNumber(math.floor(value))
                        --gg.log("更新战力值显示:", value)
                    elseif variableName == "数据_固定值_重生次数" then
                        textNode.Title = gg.FormatLargeNumber(math.floor(value))
                        --gg.log("更新重生次数显示:", value)
                    else
                        -- 默认显示格式
                        textNode.Title = gg.FormatLargeNumber(math.floor(value))
                    end
                end
            end
        end
    end
end

--- 【修改后】获取指定变量的base值
---@param variableName string 变量名
---@return number 变量的base值，如果不存在则返回0
function HudMoney:GetVariableValue(variableName)
    local varData = self.playerVariableData[variableName]
    -- 【优化】安全地获取变量值，支持多种数据格式
    if varData then
        if type(varData) == "table" and varData.base then
            return varData.base
        elseif type(varData) == "number" then
            return varData
        elseif type(varData) == "string" then
            return tonumber(varData) or 0
        end
    end
    return 0
end

return HudMoney.New(script.Parent, uiConfig)


