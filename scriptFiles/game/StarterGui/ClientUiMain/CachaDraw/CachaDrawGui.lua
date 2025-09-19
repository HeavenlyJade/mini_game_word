local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local LotteryEventConfig = require(MainStorage.Code.Event.LotteryEvent) ---@type LotteryEvent
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "CachaDrawGui",
    layer = 3,
    hideOnInit = true,
}

---@class CachaDrawGui:ViewBase
local CachaDrawGui = ClassMgr.Class("CachaDrawGui", ViewBase)

---@override
function CachaDrawGui:OnInit(node, config)
    -- 1. 节点初始化
    self.lotteryPanel = self:Get("黑色底图", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("抽奖界面/关闭", ViewButton) ---@type ViewButton
    self.singleDrawButton = self:Get("抽奖界面/单抽", ViewButton) ---@type ViewButton
    self.TenDrawButton = self:Get("抽奖界面/十连抽", ViewButton) ---@type ViewButton
    self.singlePriceComponent = self:Get("抽奖界面/单抽/价格图", ViewComponent) ---@type ViewComponent
    self.TenPriceComponent = self:Get("抽奖界面/十连抽/价格图", ViewComponent) ---@type ViewComponent
    self.rewardTemplate = self:Get("抽奖界面/物品底图/模版界面/奖励模版", ViewComponent) ---@type ViewComponent
    self.rewardTemplatelist = self:Get("抽奖界面/物品底图/模版界面", ViewList) ---@type ViewList
    self.rewardTemplatelist:SetVisible(false)
    self.GachawithTicketList = self:Get("抽奖界面/物品底图/抽奖卷抽奖", ViewList) ---@type ViewList
    self.GachawithTicketList:SetVisible(true)
    self.AddGachaTicketButton =self:Get("抽奖界面/抽奖卷增加", ViewButton) ---@type ViewButton

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    -- 4. 设置所有ViewList的布局属性
    self:SetAllViewListsLayout()
    
    -- 5. 初始化抽奖物品列表
    self:InitializeLotteryItemLists()
    self:SyncAllViewListsToTemplate()

    -- 6. 刷新价格显示
    self:UpdatePriceDisplay()

    ----gg.log("LotteryGui 抽奖界面初始化完成，事件监听器已注册")
end

-- =================================
-- 事件注册
-- =================================

function CachaDrawGui:RegisterEvents()
    ----gg.log("注册抽奖系统事件监听")

    -- 监听抽奖数据响应
    ClientEventManager.Subscribe(LotteryEventConfig.RESPONSE.LOTTERY_DATA, function(data)
        self:OnLotteryDataResponse(data)
    end)
    -- 监听数据同步通知
    ClientEventManager.Subscribe(LotteryEventConfig.NOTIFY.DATA_SYNC, function(data)
        self:OnDataSyncNotify(data)
    end)



    -- 【更新】监听OpenLotteryUI事件：支持打开/关闭
    ClientEventManager.Subscribe("CachaDrawGui", function(args)
        if not args then return end
        if args.operation == "关闭界面" then
            self:Close()
            return
        end
        -- 默认/显式打开
        if args.lotteryType then
            self:OpenWithType(args)
        else
            self:Open()
        end
    end)
end

function CachaDrawGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function()
        self:Close()
    end

    -- 单抽按钮
    self.singleDrawButton.clickCb = function()
        self:OnClickSingleDraw()
    end

    -- 十连抽按钮
    if self.TenDrawButton then
        self.TenDrawButton.clickCb = function()
            self:OnClickTenDraw()
        end
    end

    if self.AddGachaTicketButton then
        self.AddGachaTicketButton.clickCb = function ()
            local shopGui = ViewBase.GetUI("ShopDetailGui")
            if shopGui then
                shopGui:OpenFromCommand({
                    categoryName = "飞行币",
                    shopItemId = "飞行币1.5万"
                })
                -- 进入商城后关闭当前抽奖界面
                self:Close()
            else
                --gg.log("错误：找不到ShopDetailGui界面")
            end
        end
    end

end

-- =================================
-- 界面生命周期
-- =================================

function CachaDrawGui:OnOpen()
    self:UpdatePriceDisplay()
    self:InitializeLotteryItemLists()
end

-- 兼容事件回调（占位，避免空方法报错）
function CachaDrawGui:OnLotteryDataResponse(data)
    -- 本界面主要做展示，不处理服务端数据
end

function CachaDrawGui:OnDataSyncNotify(data)
    -- 接收到同步时刷新展示
    self:UpdatePriceDisplay()
    self:InitializeLotteryItemLists()
end

-- 支持事件入参打开
function CachaDrawGui:OpenWithType(args)
    -- 保持简单：仅打开并刷新配置展示
    self:Open()
    self:UpdatePriceDisplay()
    self:InitializeLotteryItemLists()
end

-- =================================
-- 布局与同步
-- =================================

function CachaDrawGui:SetAllViewListsLayout()
    local templateSize = nil
    local templatePosition = nil
    if self.rewardTemplatelist and self.rewardTemplatelist.node then
        templateSize = self.rewardTemplatelist.node.Size
        templatePosition = self.rewardTemplatelist.node.Position
    end

    if self.GachawithTicketList and self.GachawithTicketList.node then
        pcall(function()
            if templateSize ~= nil then
                self.GachawithTicketList.node.Size = templateSize
            end
            if templatePosition ~= nil then
                self.GachawithTicketList.node.Position = templatePosition
            end
            self.GachawithTicketList.node.ScrollType = Enum.ListLayoutType.FLOW_VERTICAL
            self.GachawithTicketList.node.OverflowType = Enum.OverflowType.VERTICAL
            self.GachawithTicketList.node.IsNotifyEventStop = false
        end)
    end
end

function CachaDrawGui:SyncAllViewListsToTemplate()
    if not self.rewardTemplatelist or not self.rewardTemplatelist.node then
        return
    end
    local templateNode = self.rewardTemplatelist.node
    local templateSize = templateNode.Size
    local templateOverflowType = templateNode.OverflowType
    local templateScrollType = templateNode.ScrollType

    if self.GachawithTicketList and self.GachawithTicketList.node then
        pcall(function()
            self.GachawithTicketList.node.Size = templateSize
            self.GachawithTicketList.node.OverflowType = templateOverflowType
            self.GachawithTicketList.node.ScrollType = templateScrollType
            self.GachawithTicketList.node.IsNotifyEventStop = false
        end)
    end
end

-- =================================
-- 配置与显示
-- =================================

function CachaDrawGui:GetEggLottery()
    if not self._eggLottery then
        self._eggLottery = ConfigLoader.GetLottery("蛋蛋抽奖")
    end
    return self._eggLottery
end

function CachaDrawGui:UpdatePriceDisplay()
    local lottery = self:GetEggLottery()
    if not lottery then return end

    local singleCost = lottery:GetCost("single")
    if singleCost and self.singlePriceComponent and self.singlePriceComponent.node then
        local v = singleCost.costAmount or 0
        self.singlePriceComponent.node["价格框"].Title = gg.FormatLargeNumber(v)
    end

    local tenCost = lottery:GetCost("ten")
    if tenCost and self.TenPriceComponent and self.TenPriceComponent.node then
        local v = tenCost.costAmount or 0
        self.TenPriceComponent.node["价格框"].Title = gg.FormatLargeNumber(v)
    end
end

-- =================================
-- 抽奖物品列表
-- =================================

function CachaDrawGui:InitializeLotteryItemLists()
    self:LoadLotteryItemsToList("蛋蛋抽奖", self.GachawithTicketList)
end

function CachaDrawGui:LoadLotteryItemsToList(poolName, viewList)
    if not viewList then return end
    local lotteryConfig = ConfigLoader.GetLottery(poolName)
    if not lotteryConfig or not lotteryConfig.rewardPool then return end

    viewList:ClearChildren()
    for i, rewardItem in ipairs(lotteryConfig.rewardPool) do
        self:CreateLotteryItemNode(viewList, rewardItem, i, poolName)
    end
end

function CachaDrawGui:CreateLotteryItemNode(viewList, rewardItem, index, poolName)
    local rewardInfo = self:GetRewardInfo(rewardItem)
    if not rewardInfo then return end
    if not self.rewardTemplate or not self.rewardTemplate.node then return end

    local itemNode = self.rewardTemplate.node:Clone()
    if not itemNode then return end

    itemNode.Name = "奖励物品_" .. index

    local backgroundNode = itemNode:FindFirstChild("背景")
    if rewardInfo.rarity and CardIcon.qualityNoticeIcon[rewardInfo.rarity] then
        backgroundNode.Icon = CardIcon.qualityNoticeIcon[rewardInfo.rarity]
    end

    local iconNode = backgroundNode:FindFirstChild("图标")
    if iconNode and rewardInfo.icon then
        iconNode.Icon = rewardInfo.icon
    end

    local probabilityNode = backgroundNode:FindFirstChild("概率")
    if probabilityNode then
        local lotteryConfig = ConfigLoader.GetLottery(poolName)
        if lotteryConfig then
            local probabilityText = lotteryConfig:GetFormattedProbability(rewardItem)
            probabilityNode.Title = probabilityText
        end
    end

    -- 绑定悬停提示（使用工程通用的 ItemTooltipHud）
    local tooltipTarget = iconNode or backgroundNode
    if tooltipTarget then
        -- 简化：参考 LotteryGui:GetRewardInfo，先拿统一的展示信息
        local rewardType = rewardItem.rewardType
        local itemData = nil
        if rewardType == "物品" then
            itemData = ConfigLoader.GetItem(rewardItem.item)
        else
            local info = rewardInfo -- 已由 GetRewardInfo 解析出 name/icon/rarity
            local desc = ""
            if rewardType == "宠物" then
                local cfg = ConfigLoader.GetPet(rewardItem.petConfig); if cfg and cfg.description then desc = cfg.description end
            elseif rewardType == "伙伴" then
                local cfg = ConfigLoader.GetPartner(rewardItem.partnerConfig); if cfg and cfg.description then desc = cfg.description end
            elseif rewardType == "翅膀" then
                local cfg = ConfigLoader.GetWing(rewardItem.wingConfig); if cfg and cfg.description then desc = cfg.description end
            elseif rewardType == "尾迹" then
                local cfg = ConfigLoader.GetTrail(rewardItem.trailConfig); if cfg and cfg.description then desc = cfg.description end
            end
            itemData = {
                name = info.name,
                icon = info.icon,
                description = desc,
                amount = rewardItem.amount or 1,
                rarity = info.rarity,
                quality = info.rarity,
            }
        end


        tooltipTarget.RollOver:Connect(function(node, isOver, vector2)
            local hud = ViewBase.GetUI("ItemTooltipHud")
            if hud then
                hud:DisplayItem(itemData, vector2.x, vector2.y)
            end
        end)
        tooltipTarget.RollOut:Connect(function(node, isOver, vector2)
            local hud = ViewBase.GetUI("ItemTooltipHud")
            if hud then
                hud:Close()
            end
        end)
    end

    viewList:AppendChild(itemNode)
end

function CachaDrawGui:GetRewardInfo(rewardItem)
    if not rewardItem then return nil end
    local rewardType = rewardItem.rewardType
    local rewardName = nil

    if rewardType == "宠物" then
        rewardName = rewardItem.petConfig
    elseif rewardType == "伙伴" then
        rewardName = rewardItem.partnerConfig
    elseif rewardType == "翅膀" then
        rewardName = rewardItem.wingConfig
    elseif rewardType == "尾迹" then
        rewardName = rewardItem.trailConfig
    elseif rewardType == "物品" then
        rewardName = rewardItem.item
    end

    if not rewardName then return nil end

    local rewardInfo = {}
    if rewardType == "宠物" then
        local petConfig = ConfigLoader.GetPet(rewardName)
        if petConfig then
            rewardInfo.name = petConfig.name or rewardName
            rewardInfo.icon = petConfig.avatarResource
            rewardInfo.rarity = petConfig.rarity or "N"
        end
    elseif rewardType == "伙伴" then
        local partnerConfig = ConfigLoader.GetPartner(rewardName)
        if partnerConfig then
            rewardInfo.name = partnerConfig.name or rewardName
            rewardInfo.icon = partnerConfig.avatarResource
            rewardInfo.rarity = partnerConfig.rarity or "N"
        end
    elseif rewardType == "翅膀" then
        local wingConfig = ConfigLoader.GetWing(rewardName)
        if wingConfig then
            rewardInfo.name = wingConfig.name or rewardName
            rewardInfo.icon = wingConfig.avatarResource
            rewardInfo.rarity = wingConfig.rarity or "N"
        end
    elseif rewardType == "尾迹" then
        local trailConfig = ConfigLoader.GetTrail(rewardName)
        if trailConfig then
            rewardInfo.name = trailConfig.name or rewardName
            rewardInfo.icon = trailConfig.avatarResource
            rewardInfo.rarity = trailConfig.rarity or "N"
        end
    elseif rewardType == "物品" then
        local itemConfig = ConfigLoader.GetItem(rewardName)
        if itemConfig then
            rewardInfo.name = itemConfig.name or rewardName
            rewardInfo.icon = itemConfig.icon
            rewardInfo.rarity = itemConfig.rarity or "N"
        end
    else
        rewardInfo.name = rewardName
        rewardInfo.icon = nil
        rewardInfo.rarity = "N"
    end

    return rewardInfo
end

function CachaDrawGui:GetRarityBonusText(rarity)
    local bonusMap = {
        N = "普通",
        R = "稀有",
        SR = "超稀有",
        SSR = "极稀有",
        UR = "终极稀有",
        LR = "传说稀有"
    }
    return bonusMap[rarity] or "普通"
end

-- =================================
-- 按钮操作
-- =================================

function CachaDrawGui:OnClickSingleDraw()
    -- 发送单抽请求到服务端（抽奖池固定为：蛋蛋抽奖）
    self:SendLotteryRequest(LotteryEventConfig.REQUEST.SINGLE_DRAW)
end

function CachaDrawGui:OnClickTenDraw()
    -- 发送十连抽请求到服务端（抽奖池固定为：蛋蛋抽奖）
    self:SendLotteryRequest(LotteryEventConfig.REQUEST.TEN_DRAW)
end

-- 统一的请求发送方法（与 LotteryGui 一致的调用方式）
function CachaDrawGui:SendLotteryRequest(cmd)
    local requestData = {
        cmd = cmd,
        args = {
            poolName = "蛋蛋抽奖"
        }
    }
    gg.network_channel:FireServer(requestData)
end

return CachaDrawGui.New(script.Parent, uiConfig)