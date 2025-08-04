local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local TrailEventConfig = require(MainStorage.Code.Event.EventTrail) ---@type TrailEventConfig
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "TrailGui",
    layer = 3,
    hideOnInit = true,
}

---@class TrailGui:ViewBase
local TrailGui = ClassMgr.Class("TrailGui", ViewBase)

---@override
function TrailGui:OnInit(node, config)
    -- 1. 节点初始化
    self.trailPanel = self:Get("尾迹界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("尾迹界面/关闭", ViewButton) ---@type ViewButton

    -- 尾迹显示栏
    self.displayBar = self:Get("尾迹界面/尾迹显示栏", ViewComponent) ---@type ViewComponent
    self.attributeIntro = self:Get("尾迹界面/尾迹显示栏/属性介绍", ViewComponent) ---@type ViewComponent

    -- 属性栏位
    self.attributeList = self:Get("尾迹界面/尾迹显示栏/属性介绍/属性栏位", ViewList) ---@type ViewList
    self.attributeItem = self:Get("尾迹界面/尾迹显示栏/属性介绍/属性栏位/属性栏", ViewComponent) ---@type ViewComponent
    if self.attributeItem and self.attributeItem.node then
        self.attributeItem.node.Visible = false -- 隐藏模板
    end

    -- 功能按钮
    self.equipButton = self:Get("尾迹界面/尾迹显示栏/装备", ViewButton) ---@type ViewButton
    self.unequipButton = self:Get("尾迹界面/尾迹显示栏/卸下", ViewButton) ---@type ViewButton
    self.trailUI = self:Get("尾迹界面/尾迹显示栏/轨迹UI", ViewComponent) ---@type ViewComponent

    -- 名字
    self.nameLabel = self:Get("尾迹界面/尾迹显示栏/名字", ViewComponent) ---@type ViewComponent

    -- 尾迹栏位（底部）
    self.trailSlotSection = self:Get("尾迹界面/模版界面", ViewList) ---@type ViewList
    self.trailSlotList = self:Get("尾迹界面/尾迹栏位", ViewList) ---@type ViewList
    -- 模板从模版界面取
    self.slotTemplate = self:Get("尾迹界面/模版界面/尾迹_1", ViewComponent) ---@type ViewComponent

    -- 数据存储
    self.trailData = {} ---@type table 服务端同步的尾迹数据
    self.selectedTrail = nil ---@type table 当前选中的尾迹
    self.trailSlotButtons = {} ---@type table 尾迹槽位按钮映射
    self.activeSlots = {} ---@type table<string, number> 当前激活的尾迹槽位映射
    self.equipSlotIds = {} ---@type table<string> 所有可用的装备栏ID
    self.trailConfigs = {} ---@type table 尾迹配置缓存
    self.trailBagCapacity = 30 -- 默认背包容量
    self.unlockedEquipSlots = 1 -- 默认可携带栏位数量

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    gg.log("TrailGui 尾迹界面初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function TrailGui:RegisterEvents()
    gg.log("注册尾迹系统事件监听")

    -- 监听尾迹列表响应
    ClientEventManager.Subscribe(TrailEventConfig.NOTIFY.TRAIL_LIST_UPDATE, function(data)
        self:OnTrailListResponse(data)
    end)

    -- 监听尾迹更新
    ClientEventManager.Subscribe(TrailEventConfig.NOTIFY.TRAIL_UPDATE, function(data)
        self:OnTrailUpdateNotify(data)
    end)

    -- 监听新获得尾迹通知
    ClientEventManager.Subscribe(TrailEventConfig.NOTIFY.TRAIL_OBTAINED, function(data)
        self:OnTrailObtainedNotify(data)
    end)

    -- 监听错误响应
    ClientEventManager.Subscribe(TrailEventConfig.RESPONSE.ERROR_RESPONSE, function(data)
        self:OnTrailErrorResponse(data)
    end)
end

function TrailGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function()
        self:Close()
    end

    -- 装备按钮
    self.equipButton.clickCb = function()
        self:OnClickEquipTrail()
    end

    -- 卸下按钮
    self.unequipButton.clickCb = function()
        self:OnClickUnequipTrail()
    end

    gg.log("尾迹界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

function TrailGui:OnOpen()
    gg.log("TrailGui尾迹界面打开")
    self:RequestTrailData()
end

function TrailGui:OnClose()
    gg.log("TrailGui尾迹界面关闭")
end

-- =================================
-- 数据请求与响应
-- =================================

--- 请求尾迹数据
function TrailGui:RequestTrailData()
    local requestData = {
        cmd = TrailEventConfig.REQUEST.GET_TRAIL_LIST,
        args = {}
    }
    gg.log("请求尾迹数据同步")
    gg.network_channel:fireServer(requestData)
end

--- 处理尾迹列表响应
function TrailGui:OnTrailListResponse(data)
    gg.log("收到尾迹数据响应:", data)
    if data and data.trailList then
        self.trailData = data.trailList
        self.activeSlots = data.activeSlots or {}
        self.equipSlotIds = data.equipSlotIds or {}
        self.trailBagCapacity = data.trailSlots or 30
        self.unlockedEquipSlots = data.unlockedEquipSlots or 1

        gg.log("尾迹数据同步完成, 激活槽位:", self.activeSlots)

        -- 刷新界面显示
        self:RefreshTrailList()
        self:SelectDefaultTrail()
    else
        gg.log("尾迹数据响应格式错误或列表为空")
    end
end

--- 处理尾迹更新通知
function TrailGui:OnTrailUpdateNotify(data)
    gg.log("收到尾迹更新通知:", data)
    if data.trailData then
        local trailData = data.trailData
        local slotIndex = trailData.slotIndex
        if slotIndex then
            self.trailData[slotIndex] = trailData

            -- 刷新显示
            self:RefreshTrailList()
            if self.selectedTrail and self.selectedTrail.slotIndex == slotIndex then
                self:RefreshSelectedTrailDisplay()
            end
        end
    end
end

--- 处理新获得尾迹通知
function TrailGui:OnTrailObtainedNotify(data)
    gg.log("收到新获得尾迹通知:", data)
    if data.slotIndex and data.trailName then
        local slotIndex = data.slotIndex
        local trailInfo = {
            trailName = data.trailName,
            slotIndex = slotIndex,
            customName = data.customName or "",
            isLocked = data.isLocked or false
        }
        self.trailData[slotIndex] = trailInfo

        if self:IsOpen() then
            self:CreateTrailSlotItem(slotIndex, trailInfo)
            gg.log("新尾迹已添加到界面显示:", data.trailName)
        end
    end
end

--- 处理错误响应
function TrailGui:OnTrailErrorResponse(data)
    gg.log("收到尾迹系统错误响应:", data)
    local errorMessage = data.errorMsg or "操作失败"
    gg.log("错误信息:", errorMessage)
    -- TODO: 显示错误提示给玩家
end

--- 检查界面是否已打开
function TrailGui:IsOpen()
    return self.trailPanel and self.trailPanel:IsVisible()
end

-- =================================
-- 按钮操作处理
-- =================================

--- 装备按钮点击
function TrailGui:OnClickEquipTrail()
    if not self.selectedTrail then
        gg.log("未选中尾迹，无法装备")
        return
    end

    local trailSlotId = self.selectedTrail.slotIndex
    local equipSlotId = self:FindNextAvailableEquipSlot()

    if not equipSlotId then
        gg.log("没有可用的装备栏")
        return
    end

    gg.log("点击装备按钮:", "背包槽位", trailSlotId, "目标装备栏", equipSlotId)
    self:SendEquipTrailRequest(trailSlotId, equipSlotId)
end

--- 卸下按钮点击
function TrailGui:OnClickUnequipTrail()
    if not self.selectedTrail then
        gg.log("未选中尾迹，无法卸下")
        return
    end

    local trailSlotId = self.selectedTrail.slotIndex
    local equipSlotId = self:GetEquipSlotByTrailSlot(trailSlotId)

    if not equipSlotId then
        gg.log("错误：该尾迹并未装备，但卸下按钮可见")
        return
    end

    gg.log("点击卸下按钮:", "从装备栏", equipSlotId)
    self:SendUnequipTrailRequest(equipSlotId)
end

-- =================================
-- 网络请求发送
-- =================================

--- 发送装备/卸下请求
function TrailGui:SendEquipTrailRequest(trailSlotId, equipSlotId)
    local requestData = {
        cmd = TrailEventConfig.REQUEST.EQUIP_TRAIL,
        args = {
            trailSlotId = trailSlotId,
            equipSlotId = equipSlotId
        }
    }
    gg.log("发送装备尾迹请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

function TrailGui:SendUnequipTrailRequest(equipSlotId)
    local requestData = {
        cmd = TrailEventConfig.REQUEST.UNEQUIP_TRAIL,
        args = {
            equipSlotId = equipSlotId
        }
    }
    gg.log("发送卸下尾迹请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

-- =================================
-- UI刷新方法
-- =================================

--- 刷新尾迹列表
function TrailGui:RefreshTrailList()
    gg.log("刷新尾迹列表显示")

    self.trailSlotButtons = {}
    self.trailSlotList:ClearChildren()

    local trailList = self:GetSortedTrailList()

    for _, item in ipairs(trailList) do
        local trailInfo = item.info
        self:CreateTrailSlotItem(trailInfo.slotIndex, trailInfo)
    end

    gg.log("尾迹列表刷新完成")
end

--- 创建尾迹槽位项
function TrailGui:CreateTrailSlotItem(slotIndex, trailInfo)
    if not self.slotTemplate or not self.slotTemplate.node then
        gg.log("警告：尾迹槽位模板不存在")
        return
    end
    gg.log("创建尾迹槽位项", slotIndex, trailInfo)

    local slotNode = self.slotTemplate.node:Clone()
    slotNode.Visible = true
    slotNode.Name = trailInfo.trailName .. "_" .. slotIndex

    self.trailSlotList:AppendChild(slotNode)

    self:SetupTrailSlotDisplay(slotNode, slotIndex, trailInfo)

    local slotButton = ViewButton.New(slotNode, self)
    slotButton.clickCb = function()
        self:OnTrailSlotClick(slotIndex, trailInfo)
    end

    self.trailSlotButtons[slotIndex] = slotButton
end

--- 设置尾迹槽位显示
function TrailGui:SetupTrailSlotDisplay(slotNode, slotIndex, trailInfo)
    if not slotNode then return end

    local backgroundNode = slotNode["背景"]
    if not backgroundNode then return end

    local trailConfig = self:GetTrailConfig(trailInfo.trailName) ---@type TrailType

    if trailConfig and trailConfig.rarity then
        local qualityBg = CardIcon.qualityBackGroundIcon[trailConfig.rarity]
        if qualityBg then
            backgroundNode.Icon = qualityBg
        end
    end

    local iconNode = backgroundNode["图标"]
    if iconNode and trailConfig and trailConfig.imageResource then
        iconNode.Icon = trailConfig.imageResource
    end

    local isEquipped = self:IsTrailEquipped(slotIndex)
    self:UpdateActiveState(slotNode, isEquipped)

    -- 更新锁定状态显示
    local lockNode = slotNode:FindFirstChild("锁定")
    if lockNode then
        lockNode.Visible = trailInfo.isLocked or false
    end
end

--- 更新激活状态显示
function TrailGui:UpdateActiveState(slotNode, isActive)
    local activeMark = slotNode["选中"] -- 假设激活标记节点叫"选中"
    if activeMark then
        activeMark.Visible = isActive
    end
end

--- 尾迹槽位点击事件
function TrailGui:OnTrailSlotClick(slotIndex, trailInfo)
    gg.log("点击尾迹槽位:", slotIndex, trailInfo.trailName)

    local isEquipped = self:IsTrailEquipped(slotIndex)

    self.selectedTrail = {
        slotIndex = slotIndex,
        trailName = trailInfo.trailName,
        customName = trailInfo.customName or "",
        isEquipped = isEquipped,
        isLocked = trailInfo.isLocked or false
    }

    self:RefreshSelectedTrailDisplay()
end

--- 刷新选中尾迹显示
function TrailGui:RefreshSelectedTrailDisplay()
    if not self.selectedTrail then
        self:HideTrailDetail()
        return
    end

    local trail = self.selectedTrail
    gg.log("刷新选中尾迹显示:", trail.trailName)

    local trailConfig = self:GetTrailConfig(trail.trailName)
    if not trailConfig then
        gg.log("错误: 无法获取尾迹配置", trail.trailName)
        return
    end

    if self.trailUI and trailConfig and trailConfig.imageResource then
        self.trailUI.node.Icon = trailConfig.imageResource
    end

    if self.nameLabel then
        local displayName = trail.customName ~= "" and trail.customName or trailConfig.displayName or trail.trailName
        self.nameLabel.node.Title = displayName
    end

    self:UpdateAttributeDisplay(trailConfig)
    self:UpdateButtonStates(trail)
end

--- 更新属性介绍显示
function TrailGui:UpdateAttributeDisplay(trailConfig)
    if not self.attributeList or not trailConfig then
        if self.attributeList then self.attributeList:HideChildrenFrom(0) end
        return
    end

    -- 根据尾迹配置显示属性
    local effects = trailConfig:GetEffects() or {}
    local effectsToShow = {}
    for name, data in pairs(effects) do
        table.insert(effectsToShow, {name = name, data = data})
    end
    table.sort(effectsToShow, function(a, b) return a.name < b.name end)

    local numEffects = #effectsToShow
    self.attributeList:SetElementSize(numEffects)

    for i = 1, numEffects do
        local effectInfo = effectsToShow[i]
        local attributeItem = self.attributeList:GetChild(i)
        if attributeItem then
            local variableName = effectInfo.name
            local effectData = effectInfo.data
            self:UpdateAttributeItem(attributeItem.node, variableName, effectData, trailConfig)
        end
    end

    self.attributeList:HideChildrenFrom(numEffects)
end

--- 更新单个属性项的显示
function TrailGui:UpdateAttributeItem(attributeNode, variableName, effectData, trailConfig)
    if not attributeNode then return end

    local currentAttrText = attributeNode:FindFirstChild("当前属性")
    local nextAttrText = attributeNode:FindFirstChild("升星属性")

    if currentAttrText and effectData and trailConfig then
        currentAttrText.Title = trailConfig:FormatEffectDescription(variableName, effectData.value, effectData.isPercentage)
    end

    if nextAttrText then
        nextAttrText.Title = "升星属性: N/A" -- 尾迹暂时不支持升星
    end
end

--- 更新按钮状态
function TrailGui:UpdateButtonStates(trail)
    if not trail then return end

    local isEquipped = trail.isEquipped
    local hasEmptySlot = self:FindNextAvailableEquipSlot() ~= nil

    if self.equipButton then
        local canEquip = not isEquipped and hasEmptySlot
        self.equipButton:SetVisible(canEquip)
        self.equipButton:SetTouchEnable(canEquip, nil)
    end
    if self.unequipButton then
        self.unequipButton:SetVisible(isEquipped)
    end
end

--- 隐藏尾迹详情
function TrailGui:HideTrailDetail()
    if self.nameLabel then self.nameLabel.node.Title = "未选择尾迹" end
    if self.trailUI then self.trailUI.node.Icon = "" end

    if self.attributeList then self.attributeList:HideChildrenFrom(0) end

    if self.equipButton then self.equipButton:SetVisible(false) end
    if self.unequipButton then self.unequipButton:SetVisible(false) end
end

-- =================================
-- 工具方法
-- =================================

--- 获取排序后的尾迹列表
function TrailGui:GetSortedTrailList()
    -- 1. 将尾迹数据从字典转为包含排序信息的数组
    local trailList = {}
    for slotIndex, trailInfo in pairs(self.trailData) do
        -- 为每个尾迹动态计算并添加 isEquipped 和 slotIndex 标志
        trailInfo.isEquipped = self:IsTrailEquipped(slotIndex)
        trailInfo.slotIndex = slotIndex

        local config = self:GetTrailConfig(trailInfo.trailName)
        table.insert(trailList, {
            info = trailInfo,
            rarity = config and config.rarity or 0,
        })
    end

    -- 2. 按新的排序规则排序：1.装备 > 2.品质 > 3.名称
    table.sort(trailList, function(a, b)
        local aInfo = a.info
        local bInfo = b.info

        -- 规则1: 装备状态 (装备的在前)
        if aInfo.isEquipped ~= bInfo.isEquipped then
            return aInfo.isEquipped
        end

        -- 规则2: 品质 (高品质在前)
        if a.rarity ~= b.rarity then
            return a.rarity > b.rarity
        end

        -- 规则3: 名称 (按字母顺序)
        if aInfo.trailName ~= bInfo.trailName then
            return aInfo.trailName < bInfo.trailName
        end

        -- 规则4: 如果都相同, 按槽位ID排序 (保持稳定)
        return (aInfo.slotIndex or 0) < (bInfo.slotIndex or 0)
    end)

    return trailList
end

--- 检查尾迹是否已装备
function TrailGui:IsTrailEquipped(trailSlotId)
    for _, equippedId in pairs(self.activeSlots) do
        if equippedId == trailSlotId then return true end
    end
    return false
end

--- 根据尾迹背包槽位ID查找其所在的装备栏ID
function TrailGui:GetEquipSlotByTrailSlot(trailSlotId)
    for equipId, compId in pairs(self.activeSlots) do
        if compId == trailSlotId then return equipId end
    end
    return nil
end

--- 查找下一个可用的装备栏ID
function TrailGui:FindNextAvailableEquipSlot()
    for _, equipId in ipairs(self.equipSlotIds) do
        if not self.activeSlots[equipId] then
            return equipId
        end
    end
    return nil
end

--- 获取尾迹配置
function TrailGui:GetTrailConfig(trailName)
    if not trailName then return nil end

    if not self.trailConfigs[trailName] then
        self.trailConfigs[trailName] = ConfigLoader.GetTrail(trailName)
        if not self.trailConfigs[trailName] then
            gg.log("警告: 找不到尾迹配置", trailName)
        end
    end

    return self.trailConfigs[trailName]
end

--- 获取尾迹数量
function TrailGui:GetTrailCount()
    local count = 0
    for _ in pairs(self.trailData) do
        count = count + 1
    end
    return count
end

--- 默认选择第一个尾迹
function TrailGui:SelectDefaultTrail()
    gg.log("尝试默认选择第一个尾迹")

    local sortedList = self:GetSortedTrailList()

    if #sortedList > 0 then
        local firstTrail = sortedList[1].info
        gg.log("默认选择尾迹:", firstTrail.trailName)
        self:OnTrailSlotClick(firstTrail.slotIndex, firstTrail)
    else
        gg.log("没有尾迹可供选择，清空详情")
        self.selectedTrail = nil
        self:RefreshSelectedTrailDisplay()
    end
end

return TrailGui.New(script.Parent, uiConfig)
