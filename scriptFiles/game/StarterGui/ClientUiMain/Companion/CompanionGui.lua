local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "CompanionGui",
    layer = 3,
    hideOnInit = true,
}

---@class CompanionGui:ViewBase
local CompanionGui = ClassMgr.Class("CompanionGui", ViewBase)

---@override
function CompanionGui:OnInit(node, config)
    -- 1. 节点初始化
    self.companionPanel = self:Get("伙伴界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("伙伴界面/关闭", ViewButton) ---@type ViewButton

    -- 伙伴显示栏
    self.displayBar = self:Get("伙伴界面/伙伴显示栏", ViewComponent) ---@type ViewComponent
    self.attributeIntro = self:Get("伙伴界面/伙伴显示栏/属性介绍", ViewComponent) ---@type ViewComponent
    self.upgradeButton = self:Get("伙伴界面/伙伴显示栏/升星", ViewButton) ---@type ViewButton
    self.equipButton = self:Get("伙伴界面/伙伴显示栏/装备", ViewButton) ---@type ViewButton
    self.unequipButton = self:Get("伙伴界面/伙伴显示栏/卸下", ViewButton) ---@type ViewButton
    self.companionUI = self:Get("伙伴界面/伙伴显示栏/伙伴UI", ViewComponent) ---@type ViewComponent

    -- 星级UI
    self.starUI = self:Get("伙伴界面/伙伴显示栏/星级UI", ViewComponent) ---@type ViewComponent
    self.starLevel = self:Get("伙伴界面/伙伴显示栏/星级UI/星级", ViewComponent) ---@type ViewComponent
    self.nameLabel = self:Get("伙伴界面/伙伴显示栏/名字", ViewComponent) ---@type ViewComponent

    -- 伙伴栏位列表
    self.companionSlotList = self:Get("伙伴界面/伙伴栏位", ViewList) ---@type ViewList
    self.slot1 = self:Get("伙伴界面/伙伴栏位/翅膀_1", ViewComponent) ---@type ViewComponent
    self.slotBackground = self:Get("伙伴界面/伙伴栏位/翅膀_1/背景", ViewComponent) ---@type ViewComponent
    self.icon = self:Get("伙伴界面/伙伴栏位/翅膀_1/背景/图标", ViewComponent) ---@type ViewComponent
    self.priceSection = self:Get("伙伴界面/伙伴栏位/翅膀_1/背景/价格", ViewComponent) ---@type ViewComponent

    -- 数据存储
    self.companionData = {} ---@type table
    self.selectedCompanion = nil ---@type table

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    gg.log("CompanionGui 伙伴界面初始化完成")
end

function CompanionGui:RegisterEvents()
    gg.log("注册伙伴系统事件监听")
end

function CompanionGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
        gg.log("伙伴界面已关闭")
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

    gg.log("伙伴界面按钮事件注册完成")
end

function CompanionGui:OnOpen()
    gg.log("CompanionGui伙伴界面打开")
end

function CompanionGui:OnClose()
    gg.log("CompanionGui伙伴界面关闭")
end

return CompanionGui.New(script.Parent, uiConfig)