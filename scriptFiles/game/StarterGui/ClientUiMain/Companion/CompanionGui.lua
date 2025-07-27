local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local PartnerEventConfig = require(MainStorage.Code.Event.EventPartner) ---@type PartnerEventConfig
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
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
    self.upgradeButton = self:Get("伙伴界面/伙伴显示栏/升星", ViewButton) ---@type ViewButton
    self.equipButton = self:Get("伙伴界面/伙伴显示栏/装备", ViewButton) ---@type ViewButton
    self.unequipButton = self:Get("伙伴界面/伙伴显示栏/卸下", ViewButton) ---@type ViewButton
    self.companionUI = self:Get("伙伴界面/伙伴显示栏/伙伴UI", ViewComponent) ---@type ViewComponent

    -- 星级UI
    self.starUI = self:Get("伙伴界面/伙伴显示栏/星级UI", ViewComponent) ---@type ViewComponent
    self.starList = self:Get("伙伴界面/伙伴显示栏/星级UI/星级", ViewList) ---@type ViewList
    self.nameLabel = self:Get("伙伴界面/伙伴显示栏/名字", ViewComponent) ---@type ViewComponent

    -- 【新增】属性介绍UI
    self.attributeIntroComp = self:Get("伙伴界面/伙伴显示栏/属性介绍", ViewComponent) ---@type ViewComponent
    self.attributeList = self:Get("伙伴界面/伙伴显示栏/属性介绍/属性栏位", ViewList) ---@type ViewList
    self.attributeTemplate = self:Get("伙伴界面/伙伴显示栏/属性介绍/属性栏位/属性栏", ViewComponent) ---@type ViewComponent
    if self.attributeTemplate and self.attributeTemplate.node then
        self.attributeTemplate.node.Visible = false -- 隐藏模板
    end

    -- 伙伴栏位列表
    self.companionSlotList = self:Get("伙伴界面/伙伴栏位", ViewList) ---@type ViewList
    -- 伙伴槽位模板 -- 【修正】根据UI节点图，模板节点是'伙伴_1'
    self.slot1 = self:Get("伙伴界面/模板界面/伙伴_1", ViewComponent) ---@type ViewComponent

    -- 数据存储
    self.companionData = {} ---@type table 服务端同步的伙伴数据
    self.selectedCompanion = nil ---@type table 当前选中的伙伴
    self.companionSlotButtons = {} ---@type table 伙伴槽位按钮映射
    self.activeCompanionId = "" ---@type string 当前激活的伙伴ID
    self.partnerConfigs = {} ---@type table 伙伴配置缓存

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
        self:SelectDefaultCompanion()
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
            self.activeCompanionId = data.companionInfo.companionName
        elseif self.activeCompanionId == data.companionInfo.companionName then
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
            -- 【修正】修复传递给 CreateCompanionSlotItem 的参数
            self:CreateCompanionSlotItem(slotIndex, data.companionInfo)
            gg.log("新伙伴已添加到界面显示:", data.companionInfo.companionName)
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
    local partnerConfig = self:GetPartnerConfig(self.selectedCompanion.companionName)
    if partnerConfig and currentStarLevel >= (partnerConfig.maxStarLevel or 5) then
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
        args = { slotIndex = slotIndex }  -- 修改：统一使用 slotIndex
    }
    gg.log("发送伙伴升星请求:", slotIndex)
    gg.network_channel:fireServer(requestData)
end

--- 发送设置激活伙伴请求
function CompanionGui:SendSetActiveCompanionRequest(slotIndex)
    local requestData = {
        cmd = PartnerEventConfig.REQUEST.SET_ACTIVE_PARTNER,
        args = { slotIndex = slotIndex }  -- 修改：统一使用 slotIndex
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
    
    self.companionSlotList:ClearChildren()
    
    local companionList = self:GetSortedCompanionList()

    -- 3. 遍历排序后的列表来创建UI
    for _, item in ipairs(companionList) do
        local companionInfo = item.info
        self:CreateCompanionSlotItem(companionInfo.slotIndex, companionInfo)
    end
    
    gg.log("伙伴列表刷新完成，共", self:GetCompanionCount(), "个伙伴")
end

--- 创建伙伴槽位项
function CompanionGui:CreateCompanionSlotItem(slotIndex, companionInfo)
    if not self.slot1 or not self.slot1.node then
        gg.log("警告：伙伴槽位模板不存在")
        return
    end
    gg.log("创建伙伴槽位项", slotIndex, companionInfo)
    -- 克隆槽位模板
    local slotNode = self.slot1.node:Clone()
    slotNode.Visible = true
    -- 【修正】使用伙伴名和槽位索引生成唯一节点名称, 修正字段为 companionName
    slotNode.Name = companionInfo.companionName .. "_" .. slotIndex
    
    -- 添加到列表
    self.companionSlotList:AppendChild(slotNode)
    
    -- 设置槽位显示
    self:SetupCompanionSlotDisplay(slotNode, slotIndex, companionInfo)
    
    -- 创建按钮组件并绑定点击事件
    local slotButton = ViewButton.New(slotNode,self)
    slotButton.clickCb = function()
        self:OnCompanionSlotClick(slotIndex, companionInfo)
    end
    
    -- 保存按钮引用
    self.companionSlotButtons[slotIndex] = slotButton
end

--- 设置伙伴槽位显示
function CompanionGui:SetupCompanionSlotDisplay(slotNode, slotIndex, companionInfo)
    if not slotNode then return end
    
    local backgroundNode = slotNode["背景"]
    if not backgroundNode then return end
    
    local partnerConfig = self:GetPartnerConfig(companionInfo.companionName) --@type PartnerType

    -- 【新增】根据伙伴品质设置背景图
    if partnerConfig and partnerConfig.rarity then
        local qualityBg = CardIcon.qualityBackGroundIcon[partnerConfig.rarity]
        if qualityBg then
            backgroundNode.Icon = qualityBg
        end
    end

    -- 设置图标
    local iconNode = backgroundNode["图标"]
    if iconNode then
        if partnerConfig and partnerConfig.avatarResource then
            iconNode.Icon = partnerConfig.avatarResource
        end
    end
    -- 设置星级显示
    self:UpdateStarDisplay(slotNode, companionInfo.starLevel or 1)
    
    -- 设置激活状态显示
    self:UpdateActiveState(slotNode, companionInfo.isActive or false)
    
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
    -- 【修正】使用新的命名规则查找节点
    local nodeName = companionInfo.companionName .. "_" .. slotIndex
    local slotNode = self.companionSlotList.node:FindFirstChild(nodeName)
    if slotNode then
        self:SetupCompanionSlotDisplay(slotNode, slotIndex, companionInfo)
    end
end

--- 伙伴槽位点击事件
function CompanionGui:OnCompanionSlotClick(slotIndex, companionInfo)
    gg.log("点击伙伴槽位:", slotIndex, companionInfo.companionName)
    
    -- 设置选中伙伴
    self.selectedCompanion = {
        slotIndex = slotIndex,
        companionName = companionInfo.companionName,
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
    gg.log("刷新选中伙伴显示:", companion.companionName)

    -- 【新增】获取伙伴配置并更新伙伴UI的图标
    local partnerConfig = self:GetPartnerConfig(companion.companionName)
    if self.companionUI and partnerConfig and partnerConfig.avatarResource then
        self.companionUI.node.Icon = partnerConfig.avatarResource
    end
    
    -- 更新名字显示
    if self.nameLabel then
        local displayName = companion.customName or companion.companionName
        -- 【修正】文本节点的属性是 Title，不是 UITextLabel
        self.nameLabel.node.Title = displayName
    end
    
    -- 更新星级显示
    if self.starList then
        local currentStarLevel = companion.starLevel or 0
        for i, starViewComp in ipairs(self.starList.childrensList or {}) do
            local starNode = starViewComp.node
            if starNode then
                -- 从自定义属性中读取亮星和暗星的图标资源ID
                local litIcon = starNode:GetAttribute("存在")
                local unlitIcon = starNode:GetAttribute("不存在")

                if i <= currentStarLevel then
                    -- 设置为亮星
                    starNode.Icon = litIcon        
                else
                    starNode.Icon = unlitIcon
                end
            end
        end
    end
    
    -- 更新属性介绍
    gg.log("更新属性介绍", partnerConfig, companion.starLevel)
    self:UpdateAttributeDisplay(partnerConfig, companion.starLevel)
    
    -- 更新按钮状态
    self:UpdateButtonStates(companion)
end

--- 更新属性介绍显示
---@param partnerConfig PetType 伙伴配置
---@param starLevel number 当前星级
function CompanionGui:UpdateAttributeDisplay(partnerConfig, starLevel)
    if not self.attributeList then return end

    if not partnerConfig then
        self.attributeList:HideChildrenFrom(0)
        return
    end
    
    local currentStar = starLevel
    local maxStar = partnerConfig.maxStarLevel
    
    local currentEffects = partnerConfig:CalculateCarryingEffectsByStarLevel(currentStar)
    local nextEffects = {}
    if currentStar < maxStar then
        nextEffects = partnerConfig:CalculateCarryingEffectsByStarLevel(currentStar + 1)
    end
    gg.log("currentEffects",currentEffects)
    gg.log("nextEffects",nextEffects)
    -- 收集并排序以保证顺序稳定
    local effectsToShow = {}
    for name, data in pairs(currentEffects) do
        table.insert(effectsToShow, {name = name, data = data})
    end
    table.sort(effectsToShow, function(a, b) return a.name < b.name end)

    local numEffects = #effectsToShow
    self.attributeList:SetElementSize(numEffects) -- 确保有足够的UI元素

    for i = 1, numEffects do
        local effectInfo = effectsToShow[i]
        local attributeItem = self.attributeList:GetChild(i)
        if attributeItem then
            local variableName = effectInfo.name
            local currentEffectData = effectInfo.data
            local nextEffectData = nextEffects[variableName]
            self:UpdateAttributeItem(attributeItem.node, variableName, currentEffectData, nextEffectData, partnerConfig, currentStar >= maxStar)
        end
    end

    self.attributeList:HideChildrenFrom(numEffects)
end

--- 更新单个属性项的显示
---@param attributeNode SandboxNode 要更新的节点
---@param variableName string 效果变量名
---@param currentEffectData table 当前星级效果数据
---@param nextEffectData table|nil 下一星级效果数据
---@param partnerConfig PetType 伙伴配置
---@param isMaxStar boolean 是否已是最高星级
function CompanionGui:UpdateAttributeItem(attributeNode, variableName, currentEffectData, nextEffectData, partnerConfig, isMaxStar)
    if not attributeNode then return end

    attributeNode.Name = "属性项_" .. variableName -- 更新名称以便调试

    -- 根据UI截图，查找对应的文本节点
    local currentAttrText = attributeNode:FindFirstChild("当前属性")
    local nextAttrText = attributeNode:FindFirstChild("升星属性")

    -- 设置当前属性
    if currentAttrText and currentEffectData then
        currentAttrText.Title = partnerConfig:FormatEffectDescription(variableName, currentEffectData.value)
    end

    -- 设置升星属性
    if nextAttrText then
        if isMaxStar then
            nextAttrText.Title = "升星属性: 已满级"
        elseif nextEffectData then
            nextAttrText.Title = partnerConfig:FormatEffectDescription(variableName, nextEffectData.value)
        else
            -- 正常情况下不应出现，作为保险
            nextAttrText.Title = "升星属性: N/A"
        end
    end
end

--- 更新按钮状态
function CompanionGui:UpdateButtonStates(companion)
    if not companion then return end
    
    -- 升星按钮状态
    if self.upgradeButton then
        -- 【新增】确保升星按钮可见
        self.upgradeButton:SetVisible(true)
        local partnerConfig = self:GetPartnerConfig(companion.companionName)
        local maxStarLevel = partnerConfig and partnerConfig.maxStarLevel or 5
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
    if self.starList then
        for i, starViewComp in ipairs(self.starList.childrensList or {}) do
            local starNode = starViewComp.node
            if starNode then
                -- 全部设为暗星
                local unlitIcon = starNode:GetAttribute("不存在")
                if unlitIcon and unlitIcon ~= "" then
                    starNode.Icon = unlitIcon
                end
            end
        end
    end
    -- if self.attributeList then
    --     self.attributeList:ClearChildren()
    -- end
    
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

--- 获取排序后的伙伴列表
---@return table
function CompanionGui:GetSortedCompanionList()
    -- 1. 将伙伴数据从字典转为包含排序信息的数组
    local companionList = {}
    for _, companionInfo in pairs(self.companionData) do
        local config = self:GetPartnerConfig(companionInfo.companionName)
        table.insert(companionList, {
            info = companionInfo,
            rarity = config and config.rarity or 0,
        })
    end

    -- 2. 按新的排序规则排序：1.装备 > 2.品质 > 3.星级
    table.sort(companionList, function(a, b)
        local aInfo = a.info
        local bInfo = b.info

        -- 规则1: 装备状态 (装备的在前)
        if aInfo.isActive ~= bInfo.isActive then
            return aInfo.isActive -- a为true时排在前面
        end

        -- 规则2: 品质 (高品质在前)
        if a.rarity ~= b.rarity then
            return a.rarity > b.rarity
        end

        -- 规则3: 星级 (高星级在前)
        local aStars = aInfo.starLevel or 0
        local bStars = bInfo.starLevel or 0
        if aStars ~= bStars then
            return aStars > bStars
        end
        
        -- 规则4: 如果都相同, 按槽位ID排序 (保持稳定)
        return (aInfo.slotIndex or 0) < (bInfo.slotIndex or 0)
    end)
    
    return companionList
end

--- 获取伙伴配置
function CompanionGui:GetPartnerConfig(partnerName)
    if not partnerName then return nil end
    
    -- 使用缓存避免重复加载
    if not self.partnerConfigs[partnerName] then
        self.partnerConfigs[partnerName] = ConfigLoader.GetPartner(partnerName)
    end
    
    return self.partnerConfigs[partnerName]
end

--- 获取伙伴数量
function CompanionGui:GetCompanionCount()
    local count = 0
    for _ in pairs(self.companionData) do
        count = count + 1
    end
    return count
end

--- 默认选择第一个伙伴
function CompanionGui:SelectDefaultCompanion()
    gg.log("尝试默认选择第一个伙伴")
    
    local sortedList = self:GetSortedCompanionList()
    
    if #sortedList > 0 then
        local firstCompanion = sortedList[1].info
        gg.log("默认选择伙伴:", firstCompanion.companionName)
        self:OnCompanionSlotClick(firstCompanion.slotIndex, firstCompanion)
    else
        gg.log("没有伙伴可供选择，清空详情")
        self.selectedCompanion = nil
        self:RefreshSelectedCompanionDisplay()
    end
end

return CompanionGui.New(script.Parent, uiConfig)