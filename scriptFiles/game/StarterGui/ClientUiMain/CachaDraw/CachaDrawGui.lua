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

    -- 五连抽按钮
    self.fiveDrawButton.clickCb = function()
        self:OnClickFiveDraw()
    end

end

return CachaDrawGui.New(script.Parent, uiConfig)