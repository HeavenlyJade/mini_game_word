local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local PartnerEventConfig = require(MainStorage.Code.Event.EventPartner) ---@type PartnerEventConfig
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
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
    self.companionData = {} ---@type table 服务端同步的伙伴数据
    self.selectedCompanion = nil ---@type table 当前选中的伙伴
    self.companionSlotButtons = {} ---@type table 伙伴槽位按钮映射
    self.activeCompanionId = "" ---@type string 当前激活的伙伴ID
    self.companionConfigs = {} ---@type table 伙伴配置缓存

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    gg.log("CompanionGui 伙伴界面初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function CompanionGui:RegisterEvents()
    gg.log("注册伙伴系统事件监听")
    
    -- 监听伙伴列表响应
    ClientEventManager.Subscribe(PartnerEventConfig.NOTIFY.PARTNER_LIST_UPDATE, function(data)
        self:OnCompanionListResponse(data)
    end)
    
    -- 监听伙伴升星响应
    ClientEventManager.Subscribe(PartnerEventConfig.RESPONSE.PARTNER_STAR_UPGRADED, function(data)
        self:OnUpgradeStarResponse(data)
    end)
    
    -- 监听伙伴装备响应
    ClientEventManager.Subscribe(PartnerEventConfig.NOTIFY.PARTNER_UPDATE, function(data)
        self:OnCompanionUpdateNotify(data)
    end)
    
    -- 监听新获得伙伴通知
    ClientEventManager.Subscribe(PartnerEventConfig.NOTIFY.PARTNER_OBTAINED, function(data)
        self:OnCompanionObtainedNotify(data)
    end)
    
    -- 监听伙伴移除通知
    ClientEventManager.Subscribe(PartnerEventConfig.NOTIFY.PARTNER_REMOVED, function(data)
        self:OnCompanionRemovedNotify(data)
    end)
    
    -- 监听错误响应
    ClientEventManager.Subscribe(PartnerEventConfig.RESPONSE.ERROR, function(data)
        self:OnCompanionErrorResponse(data)
    end)
end

function CompanionGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function()
        self:Close()
    end

    -- 升星按钮
    self.upgradeButton.clickCb = function()
        self:OnClickUpgradeStar()
    end

    -- 装备按钮
    self.equipButton.clickCb = function()
        self:OnClickEquipCompanion()
    end

    -- 卸下按钮
    self.unequipButton.clickCb = function()
        self:OnClickUnequipCompanion()
    end

    gg.log("伙伴界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

function CompanionGui:OnOpen()
    gg.log("CompanionGui伙伴界面打开")
    self:RequestCompanionData()
end

function CompanionGui:OnClose()
    gg.log("CompanionGui伙伴界面关闭")
end

-- =================================
-- 数据请求与响应
-- =================================

--- 请求伙伴数据
function CompanionGui:RequestCompanionData()
    local requestData = {
        cmd = PartnerEventConfig.REQUEST.GET_PARTNER_LIST,
        args = {}
    }
    gg.log("请求伙伴数据同步")
    gg.network_channel:fireServer(requestData)
end

--- 处理伙伴列表响应
function CompanionGui:OnCompanionListResponse(data)
    gg.log("收到伙伴数据响应:", data)
    if data and data.partnerList then
        self.companionData = data.partnerList
        self.activeCompanionId = data.activePartnerId or ""
        
        gg.log("伙伴数据同步完成", "激活伙伴:", self.activeCompanionId)
        
        -- 刷新界面显示
        self:RefreshCompanionList()
        self:RefreshSelectedCompanionDisplay()
    else
        gg.log("伙伴数据响应格式错误")
    end
end

--- 处理升星响应
function CompanionGui:OnUpgradeStarResponse(data)
    gg.log("收到升星响应:", data)
    if data.success and data.companionSlot then
        local slotIndex = data.companionSlot
        local newStarLevel = data.newStarLevel
        
        -- 更新本地数据
        if self.companionData[slotIndex] then
            self.companionData[slotIndex].starLevel = newStarLevel
            gg.log("伙伴升星成功:", slotIndex, "新星级:", newStarLevel)
            
            -- 刷新显示
            self:RefreshCompanionSlotDisplay(slotIndex)
            if self.selectedCompanion and self.selectedCompanion.slotIndex == slotIndex then
                self:RefreshSelectedCompanionDisplay()
            end
        end
    else
        gg.log("伙伴升星失败:", data.errorMessage or "未知错误")
    end
end

--- 处理伙伴更新通知
function CompanionGui:OnCompanionUpdateNotify(data)
    gg.log("收到伙伴更新通知:", data)
    if data.companionSlot and data.companionInfo then
        local slotIndex = data.companionSlot
        self.companionData[slotIndex] = data.companionInfo
        
        -- 如果激活状态改变，更新激活伙伴ID
        if data.companionInfo.isActive then
            self.activeCompanionId = data.companionInfo.partnerName
        elseif self.activeCompanionId == data.companionInfo.partnerName then
            self.activeCompanionId = ""
        end
        
        -- 刷新显示
        self:RefreshCompanionSlotDisplay(slotIndex)
        if self.selectedCompanion and self.selectedCompanion.slotIndex == slotIndex then
            self:RefreshSelectedCompanionDisplay()
        end
    end
end

--- 处理新获得伙伴通知
function CompanionGui:OnCompanionObtainedNotify(data)
    gg.log("收到新获得伙伴通知:", data)
    if data.companionSlot and data.companionInfo then
        local slotIndex = data.companionSlot
        self.companionData[slotIndex] = data.companionInfo
        
        -- 如果界面已打开，立即刷新显示
        if self:IsOpen() then
            self:CreateCompanionSlotItem(slotIndex, {id = slotIndex, data = data.companionInfo})
            gg.log("新伙伴已添加到界面显示:", data.companionInfo.partnerName)
        end
    end
end

--- 处理错误响应
function CompanionGui:OnCompanionErrorResponse(data)
    gg.log("收到伙伴系统错误响应:", data)
    local errorMessage = data.errorMessage or "操作失败"
    gg.log("错误信息:", errorMessage)
    -- TODO: 显示错误提示给玩家
end

--- 检查界面是否已打开
function CompanionGui:IsOpen()
    return self.companionPanel and self.companionPanel:IsVisible()
end

-- =================================
-- 按钮操作处理
-- =================================

--- 升星按钮点击
function CompanionGui:OnClickUpgradeStar()
    if not self.selectedCompanion then
        gg.log("未选中伙伴，无法升星")
        return
    end
    
    local slotIndex = self.selectedCompanion.slotIndex
    local currentStarLevel = self.selectedCompanion.starLevel or 1
    
    gg.log("点击升星按钮:", "槽位", slotIndex, "当前星级", currentStarLevel)
    
    -- 检查是否已达最高星级
    local companionConfig = self:GetCompanionConfig(self.selectedCompanion.partnerName)
    if companionConfig and currentStarLevel >= (companionConfig.maxStarLevel or 5) then
        gg.log("伙伴已达最高星级")
        return
    end
    
    -- 发送升星请求
    self:SendUpgradeStarRequest(slotIndex)
end

--- 装备按钮点击
function CompanionGui:OnClickEquipCompanion()
    if not self.selectedCompanion then
        gg.log("未选中伙伴，无法装备")
        return
    end
    
    local slotIndex = self.selectedCompanion.slotIndex
    gg.log("点击装备按钮:", "槽位", slotIndex)
    
    -- 发送设置激活伙伴请求
    self:SendSetActiveCompanionRequest(slotIndex)
end

--- 卸下按钮点击
function CompanionGui:OnClickUnequipCompanion()
    if not self.selectedCompanion then
        gg.log("未选中伙伴，无法卸下")
        return
    end
    
    gg.log("点击卸下按钮")
    
    -- 发送取消激活请求（槽位为0表示取消激活）
    self:SendSetActiveCompanionRequest(0)
end

-- =================================
-- 网络请求发送
-- =================================

--- 发送升星请求
function CompanionGui:SendUpgradeStarRequest(slotIndex)
    local requestData = {
        cmd = PartnerEventConfig.REQUEST.UPGRADE_PARTNER_STAR,
        args = { companionSlot = slotIndex }
    }
    gg.log("发送伙伴升星请求:", slotIndex)
    gg.network_channel:fireServer(requestData)
end

--- 发送设置激活伙伴请求
function CompanionGui:SendSetActiveCompanionRequest(slotIndex)
    local requestData = {
        cmd = PartnerEventConfig.REQUEST.SET_ACTIVE_PARTNER,
        args = { companionSlot = slotIndex }
    }
    gg.log("发送设置激活伙伴请求:", slotIndex)
    gg.network_channel:fireServer(requestData)
end

-- =================================
-- UI刷新方法
-- =================================

--- 刷新伙伴列表
function CompanionGui:RefreshCompanionList()
    gg.log("刷新伙伴列表显示")
    
    -- 清空现有按钮映射
    self.companionSlotButtons = {}
    
    -- 清空列表
    if self.companionSlotList then
        self.companionSlotList:Clear()
    end
    
    -- 重新构建伙伴列表
    for slotIndex, companionInfo in pairs(self.companionData) do
        self:CreateCompanionSlotItem(slotIndex, companionInfo)
    end
    
    gg.log("伙伴列表刷新完成，共", self:GetCompanionCount(), "个伙伴")
end

--- 创建伙伴槽位项
function CompanionGui:CreateCompanionSlotItem(slotIndex, companionInfo)
    if not self.slot1 or not self.slot1.node then
        gg.log("警告：伙伴槽位模板不存在")
        return
    end
    
    -- 克隆槽位模板
    local slotNode = self.slot1.node:Clone()
    slotNode.Visible = true
    slotNode.Name = "伙伴槽位_" .. slotIndex
    
    -- 添加到列表
    self.companionSlotList:AppendChild(slotNode)
    
    -- 设置槽位显示
    self:SetupCompanionSlotDisplay(slotNode, slotIndex, companionInfo)
    
    -- 创建按钮组件并绑定点击事件
    local slotButton = ViewButton.New(slotNode)
    slotButton.clickCb = function()
        self:OnCompanionSlotClick(slotIndex, companionInfo)
    end
    
    -- 保存按钮引用
    self.companionSlotButtons[slotIndex] = slotButton
end

--- 设置伙伴槽位显示
function CompanionGui:SetupCompanionSlotDisplay(slotNode, slotIndex, companionInfo)
    if not slotNode then return end
    
    local backgroundNode = slotNode:FindFirstChild("背景")
    if not backgroundNode then return end
    
    -- 设置图标
    local iconNode = backgroundNode:FindFirstChild("图标")
    if iconNode then
        local companionConfig = self:GetCompanionConfig(companionInfo.partnerName)
        if companionConfig and companionConfig.icon then
            iconNode.Image = companionConfig.icon
        end
    end
    
    -- 设置星级显示
    self:UpdateStarDisplay(slotNode, companionInfo.starLevel or 1)
    
    -- 设置激活状态显示
    self:UpdateActiveState(slotNode, companionInfo.isActive or false)
    
    -- 设置价格/等级信息
    local priceNode = backgroundNode:FindFirstChild("价格")
    if priceNode then
        priceNode.Title = "Lv." .. (companionInfo.level or 1)
    end
end

--- 更新星级显示
function CompanionGui:UpdateStarDisplay(slotNode, starLevel)
    -- TODO: 根据UI结构更新星级显示
    gg.log("更新星级显示:", starLevel)
end

--- 更新激活状态显示
function CompanionGui:UpdateActiveState(slotNode, isActive)
    -- TODO: 根据UI结构更新激活状态显示
    if isActive then
        gg.log("伙伴处于激活状态")
        -- 可以添加特殊的视觉效果
    end
end

--- 刷新指定槽位显示
function CompanionGui:RefreshCompanionSlotDisplay(slotIndex)
    local companionInfo = self.companionData[slotIndex]
    if not companionInfo then return end
    
    -- 查找对应的槽位节点
    local slotNode = self.companionSlotList.node:FindFirstChild("伙伴槽位_" .. slotIndex)
    if slotNode then
        self:SetupCompanionSlotDisplay(slotNode, slotIndex, companionInfo)
    end
end

--- 伙伴槽位点击事件
function CompanionGui:OnCompanionSlotClick(slotIndex, companionInfo)
    gg.log("点击伙伴槽位:", slotIndex, companionInfo.partnerName)
    
    -- 设置选中伙伴
    self.selectedCompanion = {
        slotIndex = slotIndex,
        partnerName = companionInfo.partnerName,
        level = companionInfo.level,
        starLevel = companionInfo.starLevel,
        isActive = companionInfo.isActive
    }
    
    -- 刷新选中伙伴的详细显示
    self:RefreshSelectedCompanionDisplay()
end

--- 刷新选中伙伴显示
function CompanionGui:RefreshSelectedCompanionDisplay()
    if not self.selectedCompanion then
        -- 隐藏详细信息
        self:HideCompanionDetail()
        return
    end
    
    local companion = self.selectedCompanion
    gg.log("刷新选中伙伴显示:", companion.partnerName)
    
    -- 更新名字显示
    if self.nameLabel then
        local displayName = companion.customName or companion.partnerName
        self.nameLabel.node.Title = displayName
    end
    
    -- 更新星级显示
    if self.starLevel then
        self.starLevel.node.Title = string.rep("★", companion.starLevel or 1)
    end
    
    -- 更新属性介绍
    self:UpdateAttributeDisplay(companion)
    
    -- 更新按钮状态
    self:UpdateButtonStates(companion)
end

--- 更新属性显示
function CompanionGui:UpdateAttributeDisplay(companion)
    if not self.attributeIntro then return end
    
    local companionConfig = self:GetCompanionConfig(companion.partnerName)
    if not companionConfig then return end
    
    -- 构建属性文本
    local attributeText = string.format("等级: %d\n星级: %d\n", 
        companion.level or 1, 
        companion.starLevel or 1
    )
    
    -- 添加基础属性信息
    if companionConfig.baseAttack then
        attributeText = attributeText .. string.format("攻击力: %d\n", companionConfig.baseAttack)
    end
    if companionConfig.baseDefense then
        attributeText = attributeText .. string.format("防御力: %d\n", companionConfig.baseDefense)
    end
    
    self.attributeIntro.node.Title = attributeText
end

--- 更新按钮状态
function CompanionGui:UpdateButtonStates(companion)
    if not companion then return end
    
    -- 升星按钮状态
    if self.upgradeButton then
        local companionConfig = self:GetCompanionConfig(companion.partnerName)
        local maxStarLevel = companionConfig and companionConfig.maxStarLevel or 5
        local canUpgrade = (companion.starLevel or 1) < maxStarLevel
        
        self.upgradeButton:SetGray(not canUpgrade)
        self.upgradeButton:SetTouchEnable(canUpgrade, nil)
    end
    
    -- 装备/卸下按钮状态
    local isActive = companion.isActive
    if self.equipButton then
        self.equipButton:SetVisible(not isActive)
    end
    if self.unequipButton then
        self.unequipButton:SetVisible(isActive)
    end
end

--- 隐藏伙伴详情
function CompanionGui:HideCompanionDetail()
    if self.nameLabel then
        self.nameLabel.node.Title = "未选择伙伴"
    end
    if self.starLevel then
        self.starLevel.node.Title = ""
    end
    if self.attributeIntro then
        self.attributeIntro.node.Title = "请选择一个伙伴查看详情"
    end
    
    -- 隐藏操作按钮
    if self.upgradeButton then
        self.upgradeButton:SetVisible(false)
    end
    if self.equipButton then
        self.equipButton:SetVisible(false)
    end
    if self.unequipButton then
        self.unequipButton:SetVisible(false)
    end
end

-- =================================
-- 工具方法
-- =================================

--- 获取伙伴配置
function CompanionGui:GetCompanionConfig(partnerName)
    if not partnerName then return nil end
    
    -- 使用缓存避免重复加载
    if not self.companionConfigs[partnerName] then
        self.companionConfigs[partnerName] = ConfigLoader.GetPartner(partnerName)
    end
    
    return self.companionConfigs[partnerName]
end

--- 获取伙伴数量
function CompanionGui:GetCompanionCount()
    local count = 0
    for _ in pairs(self.companionData) do
        count = count + 1
    end
    return count
end

return CompanionGui.New(script.Parent, uiConfig)