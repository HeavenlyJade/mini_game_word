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
    self.talentNodeMap = {}     -- 天赋名称 -> UI节点映射
    self.serverTalentData = {}  -- 服务端同步的天赋等级数据
    self.TalentCostsList = {}             -- 天赋名称 -> costList 映射

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    --gg.log("TalentGui 天赋界面初始化完成")

    -- 初始化天赋栏位
    self:InitTalentList()
end

function TalentGui:RegisterEvents()
    --gg.log("注册天赋系统事件监听")
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
    -- 监听天赋数据同步响应
    ClientEventManager.Subscribe(AchievementEventConfig.RESPONSE.LIST_RESPONSE, function(data)
        self:OnTalentDataResponse(data)
    end)
end

function TalentGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
        --gg.log("天赋界面已关闭")
    end

end

function TalentGui:OnOpen()
    self:RequestTalentData()
end

function TalentGui:OnClose()
    --gg.log("TalentGui天赋界面关闭")
end

function TalentGui:InitTalentList()
    local allAchievements = ConfigLoader.GetAllAchievements()
    --gg.log("allAchievements",allAchievements)
    local talentList = {}
    for id, achievementType in pairs(allAchievements) do
        if achievementType:IsTalentAchievement() then
            --gg.log("天赋：", achievementType,achievementType.name)
            table.insert(talentList, achievementType)
        end
    end
    -- 按sort字段从小到大排序
    table.sort(talentList, function(a, b)
        return (a.sort or 0) < (b.sort or 0)
    end)
    for i, talent in ipairs(talentList) do
        local cloneNode = self.talentDemoFrame.node:Clone()
        self:SetupTalentSlot(cloneNode, talent, 0)
        self.talentSlotList:AppendChild(cloneNode)
    end
    --gg.log("天赋列表初始化完成，共加载" .. #talentList .. "个天赋")
end

---@param talentType AchievementType
---@param currentLevel number
function TalentGui:OnClickUpgradeTalent(talentType, currentLevel)
    -- 获取服务端同步的真实等级
    local realCurrentLevel = self.serverTalentData[talentType.name] or 0
gg.log("点击升级天赋：", talentType.name, "真实等级：", realCurrentLevel)
    if realCurrentLevel >= talentType:GetMaxLevel() then
        gg.log("天赋已达最大等级")
        return
    end
    local costs = talentType:GetUpgradeCosts(realCurrentLevel)
    gg.log("升级消耗", costs)
    for _, cost in ipairs(costs) do
        local item = cost.item
        local amount = cost.amount or 0
        local have = self.currencyMap[item] or 0
        if have < amount then
            gg.log("材料不足：", item, "需要：", amount, "拥有：", have)
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
    gg.network_channel:FireServer(requestData)
end

function TalentGui:OnTalentUpgradeResponse(data)
    --gg.log("收到天赋升级响应:", data)
    if data and data.data then
        local responseData = data.data
        --gg.log("天赋升级成功:", responseData.talentId, responseData.oldLevel, "->", responseData.newLevel)
        self:RefreshTalentDisplay(responseData.talentId, responseData.newLevel)
    else
        --gg.log("天赋升级失败:", data.errorCode)
    end
end

function TalentGui:OnTalentUpgradeNotify(data)
    --gg.log("收到天赋升级通知:", data)
    local notifyData = data.data
    if notifyData then
        --gg.log("天赋升级通知:", notifyData.talentId, notifyData.oldLevel, "->", notifyData.newLevel)
        -- 可播放升级特效、音效等
    end
end

function TalentGui:OnTalentErrorResponse(data)
    --gg.log("收到天赋系统错误响应:", data)
    local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig
    local errorMessage = AchievementEventConfig.GetErrorMessage(data.errorCode or 1999)
    --gg.log("错误信息:", errorMessage)
end

function TalentGui:RefreshTalentDisplay(talentId, newLevel)
    --gg.log("刷新天赋显示:", talentId, "新等级:", newLevel)
    self.serverTalentData[talentId] = newLevel
    local talentNode = self.talentNodeMap[talentId]
    --gg.log("talentNode",talentNode)
    if not talentNode then
        --gg.log("警告：找不到天赋UI节点:", talentId)
        return
    end
    if talentNode["升级对比"] then
        talentNode["升级对比"]["前"].Title = "Lv." .. newLevel
        talentNode["升级对比"]["后"].Title = "Lv." .. newLevel+1
    elseif talentNode["等级文本"] then
        talentNode["等级文本"].Title = "Lv." .. newLevel
    end
    local allAchievements = ConfigLoader.GetAllAchievements()
    local talentType = allAchievements[talentId]
    local costs = talentType:GetUpgradeCosts(newLevel)
    for _, cost in ipairs(costs) do
        local costname = cost.item
        local costNode = self.TalentCostsList[talentId].childrens[costname]
        if costNode and costNode.node then
            costNode.node["消耗数量"].Title = tostring(cost.amount or 0)
            
            if costNode.node["消耗资源UI"] then
                local itemType = ConfigLoader.GetItem(cost.item)
                if itemType and itemType.icon then
                    costNode.node["消耗资源UI"].Icon = itemType.icon
                end
            end
        end
    end
    if talentType then
        self:UpdateUpgradeButtonState(talentType, newLevel)
    end
    --gg.log("天赋显示刷新完成:", talentId, "等级:", newLevel)
end

function TalentGui:RefreshAllUpgradeButtons()
    for talentName, btn in pairs(self.upgradeBtnMap or {}) do
        local allAchievements = ConfigLoader.GetAllAchievements()
        local talentType = allAchievements[talentName]
        if talentType then
            local currentLevel = self.serverTalentData[talentName] or 0
            self:UpdateUpgradeButtonState(talentType, currentLevel)
        end
    end
end
---@param talentType AchievementType
---@param currentLevel number
function TalentGui:SetupTalentSlot(slotNode, talentType, currentLevel)

    slotNode["说明"].Title = talentType.name or ""
    slotNode.Name = talentType.name
    
    -- 设置天赋图标
    if talentType.icon and slotNode["资源UI"] then
        slotNode["资源UI"].Icon = talentType.icon
    end
    -- gg.log("talentType.description",talentType.description,slotNode["天赋描述"])
    if slotNode["天赋描述"] then
        slotNode["天赋描述"].Title = talentType.description
    end
    -- 建立天赋节点映射
    self.talentNodeMap[talentType.name] = slotNode
    local costList = ViewList.New(slotNode["消耗栏位"], self,"消耗栏位")
    local costs = talentType:GetUpgradeCosts(currentLevel)
    costList:SetElementSize(#costs)
    for i, cost in ipairs(costs) do
        local costNode = costList:GetChild(i)
        if costNode and costNode.node then
            if costNode.node["消耗数量"] then
                costNode.node["消耗数量"].Title = tostring(cost.amount or 0)
            end
            
            if costNode.node["消耗资源UI"] then
                local itemType = ConfigLoader.GetItem(cost.item)
                if itemType and itemType.icon then
                    costNode.node["消耗资源UI"].Icon = itemType.icon
                end
            end
        end
     

        local oldName = costNode.node.Name
        costNode.node.Name = cost.item
        costList.childrens[cost.item ] = costNode
        costList.childrens[oldName] = nil
    end
    -- 升级按钮绑定
    local upgradeBtn = ViewButton.New(slotNode["升级"], self, "升级")
    self.upgradeBtnMap[talentType.name] = upgradeBtn
    upgradeBtn.clickCb = function() self:OnClickUpgradeTalent(talentType, currentLevel) end
    -- 等级显示
    if slotNode["等级"] then
        slotNode["等级"].Title = "Lv." .. currentLevel
    end


    self.TalentCostsList[talentType.name] = costList  -- 存储costList到self.costs

    self:UpdateUpgradeButtonState(talentType, currentLevel)
end

-- 新增：检测消耗并刷新升级按钮状态
function TalentGui:UpdateUpgradeButtonState(talentType, currentLevel)
    local upgradeBtn = self.upgradeBtnMap[talentType.name] ---@type ViewButton
    --gg.log("upgradeBtn",upgradeBtn)
    if not upgradeBtn then return end
    local costs = talentType:GetUpgradeCosts(currentLevel)
    --gg.log("costs",costs)
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
    --gg.log("天赋界面收到背包数据同步事件")

    local items = data.items
    if not items then
        --gg.log("天赋界面警告：数据中没有items字段")
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
                    --gg.log("天赋界面更新货币:", item.name, "数量:", item.amount, "槽位:", slotIndex)
                end
            end
        end
    end

    -- 如果没有货币数据更新，直接返回，避免误操作
    if not hasCurrencyUpdate then
        --gg.log("天赋界面：本次同步无货币数据变更")
        return
    end

    --gg.log("天赋界面已同步货币数据", self.currencyMap)

    -- 刷新所有天赋升级按钮状态
    for name, btn in pairs(self.upgradeBtnMap or {}) do
        local allAchievements = ConfigLoader.GetAllAchievements()
        local talentType = allAchievements[name]
        if talentType then
            local currentLevel = self.serverTalentData[name] or 0
            self:UpdateUpgradeButtonState(talentType, currentLevel)
        end
    end
end

function TalentGui:RequestTalentData()
    local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent)
    local requestData = {
        cmd = AchievementEventConfig.REQUEST.GET_LIST,
        args = {}
    }
    --gg.log("请求天赋数据同步")
    gg.network_channel:FireServer(requestData)
end

function TalentGui:OnTalentDataResponse(data)
    --gg.log("收到天赋数据响应:", data)
    if data.data and data.data.talents then
        --gg.log("data.data.talents",data.data.talents)
        for talentId, talentInfo in pairs(data.data.talents) do
            self.serverTalentData[talentId] = talentInfo.currentLevel or 0
        end
        --gg.log("self.serverTalentData",self.serverTalentData)
        self:RefreshAllTalentDisplay()
    end
end

function TalentGui:RefreshAllTalentDisplay()
    for talentName, level in pairs(self.serverTalentData) do
        self:RefreshTalentDisplay(talentName, level)
    end
end

return TalentGui.New(script.Parent, uiConfig)
