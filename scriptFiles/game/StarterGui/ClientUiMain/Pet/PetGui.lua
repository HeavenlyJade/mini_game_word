local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "PetGui",
    layer = 3,
    hideOnInit = true,
}

---@class PetGui:ViewBase
local PetGui = ClassMgr.Class("PetGui", ViewBase)

---@override
function PetGui:OnInit(node, config)
    -- 1. 节点初始化
    self.petPanel = self:Get("宠物界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("宠物界面/关闭", ViewButton) ---@type ViewButton
    self.petCountLabel = self:Get("宠物界面/宠物数量文本", ViewComponent) ---@type ViewComponent

    -- 宠物显示栏
    self.displayBar = self:Get("宠物界面/宠物显示栏", ViewComponent) ---@type ViewComponent
    self.attributeIntro = self:Get("宠物界面/宠物显示栏/属性介绍", ViewComponent) ---@type ViewComponent
    self.upgradeButton = self:Get("宠物界面/宠物显示栏/升星", ViewButton) ---@type ViewButton
    self.equipButton = self:Get("宠物界面/宠物显示栏/装备", ViewButton) ---@type ViewButton
    self.unequipButton = self:Get("宠物界面/宠物显示栏/卸下", ViewButton) ---@type ViewButton
    self.petUI = self:Get("宠物界面/宠物显示栏/宠物UI", ViewComponent) ---@type ViewComponent

    -- 星级UI
    self.starUI = self:Get("宠物界面/宠物显示栏/星级UI", ViewComponent) ---@type ViewComponent
    self.starLevel = self:Get("宠物界面/宠物显示栏/星级UI/星级", ViewComponent) ---@type ViewComponent
    self.nameLabel = self:Get("宠物界面/宠物显示栏/名字", ViewComponent) ---@type ViewComponent

    -- 宠物栏位列表
    self.petSlotList = self:Get("宠物界面/宠物栏位", ViewList) ---@type ViewList
    self.petSlot1 = self:Get("宠物界面/宠物栏位/宠物_1", ViewComponent) ---@type ViewComponent
    self.unlockedMark = self:Get("宠物界面/宠物栏位/宠物_1/未解锁", ViewComponent) ---@type ViewComponent
    self.slotBackground = self:Get("宠物界面/宠物栏位/宠物_1/背景", ViewComponent) ---@type ViewComponent

    -- 宠物携带带
    self.petCarryBar = self:Get("宠物界面/宠物携带带", ViewComponent) ---@type ViewComponent
    self.carryCountLabel = self:Get("宠物界面/宠物携带带/携带数量", ViewComponent) ---@type ViewComponent

    -- 宠物数量
    self.petCountSection = self:Get("宠物界面/宠物数量", ViewComponent) ---@type ViewComponent
    self.petCountText = self:Get("宠物界面/宠物数量/携带数量", ViewComponent) ---@type ViewComponent

    -- 删除按钮
    self.deleteButton = self:Get("宠物界面/删除", ViewButton) ---@type ViewButton

    -- 数据存储
    self.petData = {} ---@type table
    self.selectedPet = nil ---@type table

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    gg.log("PetGui 宠物界面初始化完成")
end

function PetGui:RegisterEvents()
    gg.log("注册宠物系统事件监听")
end

function PetGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
        gg.log("宠物界面已关闭")
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

    self.deleteButton.clickCb = function()
        gg.log("删除按钮被点击")
    end

    gg.log("宠物界面按钮事件注册完成")
end

function PetGui:OnOpen()
    gg.log("PetGui宠物界面打开")
end

function PetGui:OnClose()
    gg.log("PetGui宠物界面关闭")
end

return PetGui.New(script.Parent, uiConfig)