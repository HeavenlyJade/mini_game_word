local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "WingGui",
    layer = 3,
    hideOnInit = true,
}

---@class WingGui:ViewBase
local WingGui = ClassMgr.Class("WingGui", ViewBase)

---@override
function WingGui:OnInit(node, config)
    -- 1. 节点初始化
    -- 翅膀界面主节点
    self.wingMainPanel = self:Get("翅膀界面", ViewComponent) ---@type ViewComponent

    -- 基础功能按钮
    self.closeButton = self:Get("翅膀界面/关闭", ViewButton) ---@type ViewButton

    -- 翅膀显示区域
    self.wingDisplayCard = self:Get("翅膀界面/翅膀显示卡", ViewComponent) ---@type ViewComponent
    self.attributeIntro = self:Get("翅膀界面/翅膀显示卡/属性介绍", ViewComponent) ---@type ViewComponent
    self.rebirthSlot = self:Get("翅膀界面/翅膀显示卡/属性介绍/重生栏位", ViewComponent) ---@type ViewComponent
    self.maxRebirthSection = self:Get("翅膀界面/翅膀显示卡/属性介绍/重生栏位/最大重生", ViewComponent) ---@type ViewComponent
    self.currentAttribute = self:Get("翅膀界面/翅膀显示卡/属性介绍/重生栏位/最大重生/当前属性", ViewComponent) ---@type ViewComponent
    self.upgradeAttribute = self:Get("翅膀界面/翅膀显示卡/属性介绍/重生栏位/最大重生/升星属性", ViewComponent) ---@type ViewComponent

    -- 功能操作按钮
    self.upgradeButton = self:Get("翅膀界面/翅膀显示栏/升星", ViewButton) ---@type ViewButton
    self.equipButton = self:Get("翅膀界面/翅膀显示栏/装备", ViewButton) ---@type ViewButton
    self.unequipButton = self:Get("翅膀界面/翅膀显示栏/卸下", ViewButton) ---@type ViewButton
    self.wingUI = self:Get("翅膀界面/翅膀显示栏/翅膀UI", ViewComponent) ---@type ViewComponent
    self.starUI = self:Get("翅膀界面/翅膀显示栏/星级UI", ViewComponent) ---@type ViewComponent

    -- 翅膀栏位列表
    self.wingSlotList = self:Get("翅膀界面/翅膀栏位", ViewList) ---@type ViewList
    self.wingSlot1 = self:Get("翅膀界面/翅膀栏位/翅膀_1", ViewComponent) ---@type ViewComponent
    self.unequippedMark = self:Get("翅膀界面/翅膀栏位/翅膀_1/未装备", ViewComponent) ---@type ViewComponent
    self.slotBackground = self:Get("翅膀界面/翅膀栏位/翅膀_1/背景", ViewComponent) ---@type ViewComponent
    self.priceSection = self:Get("翅膀界面/翅膀栏位/翅膀_1/背景/价格", ViewComponent) ---@type ViewComponent
    self.priceTextBox = self:Get("翅膀界面/翅膀栏位/翅膀_1/背景/价格/价格文本框", ViewComponent) ---@type ViewComponent

    -- 数据存储
    self.wingData = {} ---@type table 翅膀数据
    self.selectedWing = nil ---@type table 当前选中的翅膀

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    --gg.log("WingGui 翅膀界面初始化完成")
end

-- 2. 事件注册
function WingGui:RegisterEvents()
    --gg.log("注册翅膀系统事件监听")
end

-- 3. 按钮点击事件注册
function WingGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function()
        self:Close()
        --gg.log("翅膀界面已关闭")
    end

    -- 升星按钮
    self.upgradeButton.clickCb = function()
        --gg.log("升星按钮被点击")
    end

    -- 装备按钮
    self.equipButton.clickCb = function()
        --gg.log("装备按钮被点击")
    end

    -- 卸下按钮
    self.unequipButton.clickCb = function()
        --gg.log("卸下按钮被点击")
    end


    --gg.log("翅膀界面按钮事件注册完成")
end

-- 打开界面时的操作
function WingGui:OnOpen()
    --gg.log("WingGui翅膀界面打开")
end

-- 关闭界面时的操作
function WingGui:OnClose()
    --gg.log("WingGui翅膀界面关闭")
end

return WingGui.New(script.Parent, uiConfig)
