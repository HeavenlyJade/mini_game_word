local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "TrailGui",
    layer = 3,
    hideOnInit = true,
}

---@class TrailGui:ViewBase
local TrailGui = ClassMgr.Class("TrailGui", ViewBase)

---@override
function TrailGui:OnInit(node, config)
    -- 1. 节点初始化
    self.trailPanel = self:Get("尾迹界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("尾迹界面/关闭", ViewButton) ---@type ViewButton

    -- 尾迹显示栏
    self.displayBar = self:Get("尾迹界面/尾迹显示栏", ViewComponent) ---@type ViewComponent
    self.attributeIntro = self:Get("尾迹界面/尾迹显示栏/属性介绍", ViewComponent) ---@type ViewComponent

    -- 尾迹栏位
    self.trailSlotList = self:Get("尾迹界面/尾迹显示栏/属性介绍/尾迹栏位", ViewList) ---@type ViewList
    self.trailSlot = self:Get("尾迹界面/尾迹显示栏/属性介绍/尾迹栏位/尾迹属性", ViewComponent) ---@type ViewComponent
    self.currentAttribute = self:Get("尾迹界面/尾迹显示栏/属性介绍/尾迹栏位/尾迹属性/当前属性", ViewComponent) ---@type ViewComponent
    self.upgradeAttribute = self:Get("尾迹界面/尾迹显示栏/属性介绍/尾迹栏位/尾迹属性/升星属性", ViewComponent) ---@type ViewComponent

    -- 功能按钮
    self.upgradeButton = self:Get("尾迹界面/尾迹显示栏/升星", ViewButton) ---@type ViewButton
    self.equipButton = self:Get("尾迹界面/尾迹显示栏/装备", ViewButton) ---@type ViewButton
    self.unequipButton = self:Get("尾迹界面/尾迹显示栏/卸下", ViewButton) ---@type ViewButton
    self.partnerUI = self:Get("尾迹界面/尾迹显示栏/伙伴UI", ViewComponent) ---@type ViewComponent

    -- 星级UI
    self.starUI = self:Get("尾迹界面/尾迹显示栏/星级UI", ViewComponent) ---@type ViewComponent
    self.starLevel = self:Get("尾迹界面/尾迹显示栏/星级UI/星级", ViewComponent) ---@type ViewComponent
    -- 星级下的五个星
    self.star1 = self:Get("尾迹界面/尾迹显示栏/星级UI/星级/星_1", ViewComponent) ---@type ViewComponent
    self.star2 = self:Get("尾迹界面/尾迹显示栏/星级UI/星级/星_2", ViewComponent) ---@type ViewComponent
    self.star3 = self:Get("尾迹界面/尾迹显示栏/星级UI/星级/星_3", ViewComponent) ---@type ViewComponent
    self.star4 = self:Get("尾迹界面/尾迹显示栏/星级UI/星级/星_4", ViewComponent) ---@type ViewComponent
    self.star5 = self:Get("尾迹界面/尾迹显示栏/星级UI/星级/星_5", ViewComponent) ---@type ViewComponent

    -- 名字
    self.nameLabel = self:Get("尾迹界面/尾迹显示栏/名字", ViewComponent) ---@type ViewComponent

    -- 尾迹栏位（底部）
    self.trailSlotSection = self:Get("尾迹界面/尾迹栏位", ViewComponent) ---@type ViewComponent

    -- 数据存储
    self.trailData = {} ---@type table
    self.selectedTrail = nil ---@type table

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    gg.log("TrailGui 尾迹界面初始化完成")
end

function TrailGui:RegisterEvents()
    gg.log("注册尾迹系统事件监听")
end

function TrailGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
        gg.log("尾迹界面已关闭")
    end

    self.upgradeButton.clickCb = function()
        gg.log("升星按钮被点击")
    end

    self.equipButton.clickCb = function()
        gg.log("装备按钮被点击")
    end

    self.unequipButton.clickCb = function()
        gg.log("卸下按钮被点击")
    end

    gg.log("尾迹界面按钮事件注册完成")
end

function TrailGui:OnOpen()
    gg.log("TrailGui尾迹界面打开")
end

function TrailGui:OnClose()
    gg.log("TrailGui尾迹界面关闭")
end

return TrailGui.New(script.Parent, uiConfig)