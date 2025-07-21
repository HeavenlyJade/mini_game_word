local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "TalentGui",
    layer = 3,
    hideOnInit = true,
}

---@class TalentGui:ViewBase
local TalentGui = ClassMgr.Class("TalentGui", ViewBase)

---@override
function TalentGui:OnInit(node, config)
    -- 1. 节点初始化
    self.talentPanel = self:Get("天赋界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("天赋界面/关闭", ViewButton) ---@type ViewButton

    -- 天赋栏位
    self.talentSlotList = self:Get("天赋界面/天赋栏位", ViewList) ---@type ViewList
    self.talentFrame = self:Get("天赋界面/天赋栏位/天赋框", ViewComponent) ---@type ViewComponent
    self.descLabel = self:Get("天赋界面/天赋栏位/天赋框/说明", ViewComponent) ---@type ViewComponent
    self.upgradeButton = self:Get("天赋界面/天赋栏位/天赋框/升级", ViewButton) ---@type ViewButton
    self.resourceUI = self:Get("天赋界面/天赋栏位/天赋框/资源UI", ViewComponent) ---@type ViewComponent
    self.consumeLabel = self:Get("天赋界面/天赋栏位/天赋框/消耗", ViewComponent) ---@type ViewComponent

    -- 升级对比
    self.upgradeCompare = self:Get("天赋界面/天赋栏位/天赋框/升级对比", ViewComponent) ---@type ViewComponent
    self.compareBefore = self:Get("天赋界面/天赋栏位/天赋框/升级对比/前", ViewComponent) ---@type ViewComponent
    self.compareAfter = self:Get("天赋界面/天赋栏位/天赋框/升级对比/后", ViewComponent) ---@type ViewComponent

    -- 消耗栏位
    self.consumeSlotList = self:Get("天赋界面/天赋栏位/天赋框/消耗栏位", ViewList) ---@type ViewList
    self.consumeSlotBg = self:Get("天赋界面/天赋栏位/天赋框/消耗栏位/背景", ViewComponent) ---@type ViewComponent
    self.consumeAmount = self:Get("天赋界面/天赋栏位/天赋框/消耗栏位/背景/消耗数量", ViewComponent) ---@type ViewComponent
    self.consumeResourceUI = self:Get("天赋界面/天赋栏位/天赋框/消耗栏位/背景/消耗资源UI", ViewComponent) ---@type ViewComponent

    -- 数据存储
    self.talentData = {} ---@type table
    self.selectedTalent = nil ---@type table

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    gg.log("TalentGui 天赋界面初始化完成")
end

function TalentGui:RegisterEvents()
    gg.log("注册天赋系统事件监听")
end

function TalentGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
        gg.log("天赋界面已关闭")
    end
    self.upgradeButton.clickCb = function()
        gg.log("升级按钮被点击")
    end
    gg.log("天赋界面按钮事件注册完成")
end

function TalentGui:OnOpen()
    gg.log("TalentGui天赋界面打开")
end

function TalentGui:OnClose()
    gg.log("TalentGui天赋界面关闭")
end

return TalentGui.New(script.Parent, uiConfig)