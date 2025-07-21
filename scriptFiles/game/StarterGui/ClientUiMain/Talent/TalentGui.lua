local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

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
    self.talentSlotDemoList = self:Get("天赋界面/天赋模板", ViewList) ---@type ViewList
    self.talentDemoFrame = self:Get("天赋界面/天赋模板/天赋框", ViewComponent) ---@type ViewComponent


    -- 升级对比


    -- 数据存储
    self.talentData = {} ---@type table
    self.selectedTalent = nil ---@type table

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    gg.log("TalentGui 天赋界面初始化完成")

    -- 初始化天赋栏位
    self:InitTalentList()
end

function TalentGui:RegisterEvents()
    gg.log("注册天赋系统事件监听")
end

function TalentGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
        gg.log("天赋界面已关闭")
    end

    gg.log("天赋界面按钮事件注册完成")
end

function TalentGui:OnOpen()
    gg.log("TalentGui天赋界面打开")
end

function TalentGui:OnClose()
    gg.log("TalentGui天赋界面关闭")
end

function TalentGui:InitTalentList()
    local allAchievements = ConfigLoader.GetAllAchievements()
    local talentList = {}
    for id, achievementType in pairs(allAchievements) do
        if achievementType:IsTalentAchievement() then
            table.insert(talentList, achievementType)
        end
    end
    
    for i, talent in ipairs(talentList) do
        gg.log("天赋", i,talent)
        local cloneNode = self.talentDemoFrame.node:Clone()
        cloneNode.Name = talent.name or ("TalentSlot" .. i)
        self.talentSlotList:AppendChild(cloneNode)
        self:SetupTalentSlot(cloneNode, talent)
    end

    gg.log("天赋列表初始化完成，共加载" .. #talentList .. "个天赋")
end

function TalentGui:SetupTalentSlot(slotNode, talentType)
    -- slotNode: UI节点
    -- talentType: AchievementType 实例
    if slotNode["天赋名"] then
        slotNode["天赋名"].Title = talentType.name or ""
    end
    if slotNode["天赋描述"] then
        slotNode["天赋描述"].Title = talentType.description or ""
    end
    -- 可根据UI结构补充更多字段，如图标、等级等
end

return TalentGui.New(script.Parent, uiConfig)