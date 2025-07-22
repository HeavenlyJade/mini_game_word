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
    self.upgradeBtnMap = {}  -- 新增：存放天赋名->升级按钮映射

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
    -- 按sort字段从小到大排序
    table.sort(talentList, function(a, b)
        return (a.sort or 0) < (b.sort or 0)
    end)
    for i, talent in ipairs(talentList) do
        gg.log("天赋", i, talent)
        local cloneNode = self.talentDemoFrame.node:Clone()
        self:SetupTalentSlot(cloneNode, talent, 0)
        self.talentSlotList:AppendChild(cloneNode)
    end
    gg.log("天赋列表初始化完成，共加载" .. #talentList .. "个天赋")
end

function TalentGui:OnClickUpgradeTalent(talentType, currentLevel)
    gg.log("点击升级天赋：" .. (talentType.name or ""))
    -- TODO: 这里写具体升级逻辑，比如消耗校验、等级提升、UI刷新等
end

function TalentGui:SetupTalentSlot(slotNode, talentType, currentLevel)
    -- slotNode: UI节点
    -- talentType: AchievementType 实例
    -- currentLevel: 当前天赋等级，由外部传入
    gg.log("slotNode",slotNode)
    slotNode["说明"].Title = talentType.name or ""
   
    slotNode.Name = talentType.name 

    -- slotNode["天赋描述"].Title = talentType.description or ""

    -- 升级消耗栏位
    local costList = ViewList.New(slotNode["消耗栏位"], self,"消耗栏位")
    local costs = talentType:GetUpgradeCosts(currentLevel)
    gg.log("costs",costs)
    
    costList:SetElementSize(#costs)
    for i, cost in ipairs(costs) do
        local costNode = costList:GetChild(i)
        if costNode and costNode["背景"] then
            -- if costNode["背景"]["消耗资源UI"] then
            --     costNode["背景"]["消耗资源UI"].Title = cost.item or ""
            -- end
            if costNode["背景"]["消耗数量"] then
                costNode["背景"]["消耗数量"].Title = tostring(cost.amount or 0)
            end
        end
    end
    gg.log("costList",costList.childrens)
    -- 升级按钮绑定
    local upgradeBtn = ViewButton.New(slotNode["升级"], self, "升级")
    self.upgradeBtnMap[talentType.name] = upgradeBtn
    upgradeBtn.clickCb = function()
        self:OnClickUpgradeTalent(talentType, currentLevel)
    end

end

return TalentGui.New(script.Parent, uiConfig)