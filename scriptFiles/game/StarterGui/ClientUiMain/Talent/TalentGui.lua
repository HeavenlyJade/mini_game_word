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

    -- 引入成就事件配置
    local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig
    -- 监听天赋升级响应事件
    ClientEventManager.Subscribe(AchievementEventConfig.RESPONSE.UPGRADE_RESPONSE, function(data)
        self:OnTalentUpgradeResponse(data)
    end)
    -- 监听天赋升级通知事件
    ClientEventManager.Subscribe(AchievementEventConfig.NOTIFY.TALENT_UPGRADED, function(data)
        self:OnTalentUpgradeNotify(data)
    end)
    -- 监听错误响应事件
    ClientEventManager.Subscribe(AchievementEventConfig.RESPONSE.ERROR, function(data)
        self:OnTalentErrorResponse(data)
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

---@param talentType AchievementType
---@param currentLevel number
function TalentGui:OnClickUpgradeTalent(talentType, currentLevel)
    gg.log("点击升级天赋：", talentType, "当前等级：", currentLevel,talentType.name)
    if currentLevel >= talentType:GetMaxLevel() then
        gg.log("天赋已达最大等级")
        return
    end
    local costs = talentType:GetUpgradeCosts(currentLevel)
    gg.log("升级消耗", costs)

    -- 检查本地货币缓存是否足够
    for _, cost in ipairs(costs) do
        local item = cost.item
        local amount = cost.amount or 0
        local have = self.currencyMap[item] or 0
        if have < amount then
            gg.log("材料不足：", item, "需要：", amount, "拥有：", have)
            -- 可在此处弹窗提示
            return
        end
    end

    self:SendUpgradeTalentRequest(talentType.name)
end



function TalentGui:SendUpgradeTalentRequest(talentId)
    local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig
    local requestData = {
        cmd = AchievementEventConfig.REQUEST.UPGRADE_TALENT,
        args = { talentId = talentId }
    }
    gg.log("发送天赋升级请求:", talentId)
    gg.network_channel:fireServer(requestData)
end

function TalentGui:OnTalentUpgradeResponse(data)
    gg.log("收到天赋升级响应:", data)
    if data.success then
        local responseData = data.data
        gg.log("天赋升级成功:", responseData.talentId, responseData.oldLevel, "->", responseData.newLevel)
        self:RefreshTalentDisplay(responseData.talentId, responseData.newLevel)
        self:RefreshAllUpgradeButtons()
    else
        gg.log("天赋升级失败:", data.errorCode)
    end
end

function TalentGui:OnTalentUpgradeNotify(data)
    gg.log("收到天赋升级通知:", data)
    local notifyData = data.data
    if notifyData then
        gg.log("天赋升级通知:", notifyData.talentId, notifyData.oldLevel, "->", notifyData.newLevel)
        -- 可播放升级特效、音效等
    end
end

function TalentGui:OnTalentErrorResponse(data)
    gg.log("收到天赋系统错误响应:", data)
    local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig
    local errorMessage = AchievementEventConfig.GetErrorMessage(data.errorCode or 1999)
    gg.log("错误信息:", errorMessage)
end

function TalentGui:RefreshTalentDisplay(talentId, newLevel)
    gg.log("刷新天赋显示:", talentId, "新等级:", newLevel)
    -- 这里需要根据你的UI结构来实现
    -- 示例：
    -- local talentNode = self:FindTalentNode(talentId)
    -- if talentNode then
    --     local levelText = talentNode:FindChild("等级文本")
    --     if levelText then
    --         levelText.Title = "Lv." .. newLevel
    --     end
    -- end
end

function TalentGui:RefreshAllUpgradeButtons()
    for talentName, btn in pairs(self.upgradeBtnMap or {}) do
        local allAchievements = ConfigLoader.GetAllAchievements()
        local talentType = allAchievements[talentName]
        if talentType then
            self:UpdateUpgradeButtonState(talentType, 0) -- 真实等级需从服务端同步
        end
    end
end

function TalentGui:SetupTalentSlot(slotNode, talentType, currentLevel)
    slotNode["说明"].Title = talentType.name or ""
    slotNode.Name = talentType.name
    local costList = ViewList.New(slotNode["消耗栏位"], self,"消耗栏位")
    local costs = talentType:GetUpgradeCosts(currentLevel)
    costList:SetElementSize(#costs)
    for i, cost in ipairs(costs) do
        local costNode = costList:GetChild(i)
        if costNode and costNode.node then
            if costNode.node["消耗数量"] then
                costNode.node["消耗数量"].Title = tostring(cost.amount or 0)
            end
        end
    end
    -- 升级按钮绑定
    local upgradeBtn = ViewButton.New(slotNode["升级"], self, "升级")
    self.upgradeBtnMap[talentType.name] = upgradeBtn
    gg.log("升级按钮绑定????",talentType.name)
    upgradeBtn.clickCb = function() self:OnClickUpgradeTalent(talentType, currentLevel) end
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

function TalentGui:OnSyncInventoryItems(data)
    gg.log("天赋界面收到背包数据同步事件")
    
    local items = data.items
    if not items then
        gg.log("天赋界面警告：数据中没有items字段")
        return
    end
    
    local MConfig = require(MainStorage.Code.Common.GameConfig.MConfig) ---@type common_config
    local currencyType = MConfig.ItemTypeEnum["货币"]
    
    -- 【关键修改】检查是否有货币数据更新
    local hasCurrencyUpdate = false
    for category, itemList in pairs(items) do
        if tonumber(category) == currencyType and itemList then
            hasCurrencyUpdate = true
            -- 【重要修复】使用 pairs 而不是 ipairs，处理槽位索引
            for slotIndex, item in pairs(itemList) do
                if item and item.itemCategory == currencyType then
                    self.currencyMap[item.name] = item.amount or 0
                    gg.log("天赋界面更新货币:", item.name, "数量:", item.amount, "槽位:", slotIndex)
                end
            end
        end
    end
    
    -- 如果没有货币数据更新，直接返回，避免误操作
    if not hasCurrencyUpdate then
        gg.log("天赋界面：本次同步无货币数据变更")
        return
    end
    
    gg.log("天赋界面已同步货币数据", self.currencyMap)
    
    -- 刷新所有天赋升级按钮状态
    for name, btn in pairs(self.upgradeBtnMap or {}) do
        local allAchievements = ConfigLoader.GetAllAchievements()
        local talentType = allAchievements[name]
        if talentType then
            self:UpdateUpgradeButtonState(talentType, 0)
        end
    end
end

return TalentGui.New(script.Parent, uiConfig)