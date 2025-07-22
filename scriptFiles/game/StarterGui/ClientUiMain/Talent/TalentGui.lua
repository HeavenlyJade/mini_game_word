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
    self.currencyMap = {} -- 新增：货币数据缓存

    -- 2. 事件注册
    self:RegisterEvents()

    -- 监听背包同步事件（货币变化）
    local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig
    ClientEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, function(data)
        self:OnSyncInventoryItems(data)
    end)

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
    -- 检查消耗是否足够，不足则置灰
    self:UpdateUpgradeButtonState(talentType, currentLevel)
end

-- 新增：检测消耗并刷新升级按钮状态
function TalentGui:UpdateUpgradeButtonState(talentType, currentLevel)
    local upgradeBtn = self.upgradeBtnMap[talentType.name] ---@type ViewButton
    if not upgradeBtn then return end
    local costs = talentType:GetUpgradeCosts(currentLevel)
    local enough = true
    for _, cost in ipairs(costs) do
        local have = self.currencyMap and self.currencyMap[cost.item] or 0
        if have < (cost.amount or 0) then
            enough = false
            break
        end
    end
    upgradeBtn:SetGray(not enough)
    upgradeBtn:SetTouchEnable(enough,nil)

end

-- 新增：背包同步事件处理（可根据需要刷新天赋升级消耗等）
function TalentGui:OnSyncInventoryItems(data)
    gg.log("天赋界面收到背包数据同步事件")
    -- 只同步货币类型物品到self.currencyMap
    local items = data.items
    if not items then
        gg.log("天赋界面警告：数据中没有items字段")
        return
    end
    local MConfig = require(MainStorage.Code.Common.GameConfig.MConfig) ---@type common_config
    local currencyType = MConfig.ItemTypeEnum["货币"]
    local currencyMap = {}
    for category, itemList in pairs(items) do
        if tonumber(category) == currencyType and itemList then
            for _, item in ipairs(itemList) do
                if item.itemCategory == currencyType then
                    currencyMap[item.name] = item.amount or 0
                end
            end
        end
    end
    self.currencyMap = currencyMap
    gg.log("天赋界面已同步货币数据", currencyMap)
    -- 刷新所有天赋升级按钮状态
    -- for i, talent in ipairs(self.talentSlotList.childrensList or {}) do
    --     local talentType = talentType or nil
    --     -- 这里假设talentType可通过child节点或其他方式获取
    --     -- 由于SetupTalentSlot时已存储upgradeBtnMap，直接用talentType.name遍历
    --     -- 这里遍历upgradeBtnMap更稳妥
    -- end
    for name, btn in pairs(self.upgradeBtnMap or {}) do
        -- 需要获取talentType和当前等级，这里假设等级为0（如有等级数据请替换）
        local allAchievements = ConfigLoader.GetAllAchievements()
        local talentType = allAchievements[name]
        if talentType then
            self:UpdateUpgradeButtonState(talentType, 0)
        end
    end
end

return TalentGui.New(script.Parent, uiConfig)