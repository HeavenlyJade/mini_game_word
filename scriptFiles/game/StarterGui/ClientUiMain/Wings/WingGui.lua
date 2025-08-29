local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local WingEventConfig = require(MainStorage.Code.Event.EventWing) ---@type WingEventConfig
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "WingGui",
    layer = 3,
    hideOnInit = true,
}

---@class WingGui:ViewBase
local WingGui = ClassMgr.Class("WingGui", ViewBase)

---@override
function WingGui:OnInit(node, config)
    -- 1. 节点初始化
    self.wingPanel = self:Get("翅膀界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("翅膀界面/关闭", ViewButton) ---@type ViewButton
    self.Synthesis= self:Get("翅膀界面/翅膀显示栏/一键合成", ViewButton) ---@type ViewButton
    self.UltimateEqu = self:Get("翅膀界面/翅膀显示栏/装备最佳", ViewButton) ---@type ViewButton
    self.deleteButton = self:Get("翅膀界面/删除", ViewButton) ---@type ViewButton
    self.lockButton = self:Get("翅膀界面/锁定", ViewButton) ---@type ViewButton

    -- 翅膀显示栏
    self.displayBar = self:Get("翅膀界面/翅膀显示栏", ViewComponent) ---@type ViewComponent
    self.upgradeButton = self:Get("翅膀界面/翅膀显示栏/升星", ViewButton) ---@type ViewButton
    self.equipButton = self:Get("翅膀界面/翅膀显示栏/装备", ViewButton) ---@type ViewButton
    self.unequipButton = self:Get("翅膀界面/翅膀显示栏/卸下", ViewButton) ---@type ViewButton
    self.wingUI = self:Get("翅膀界面/翅膀显示栏/翅膀UI", ViewComponent) ---@type ViewComponent

    -- 星级UI
    self.starUI = self:Get("翅膀界面/翅膀显示栏/星级UI", ViewComponent) ---@type ViewComponent
    self.starList = self:Get("翅膀界面/翅膀显示栏/星级UI/星级", ViewList) ---@type ViewList
    self.nameLabel = self:Get("翅膀界面/翅膀显示栏/名字", ViewComponent) ---@type ViewComponent
    self.WingCarryNumLabel = self:Get("翅膀界面/翅膀携带/携带数量", ViewComponent) ---@type ViewComponent
    self.carryCountLabel = self:Get("翅膀界面/翅膀数量/携带数量", ViewComponent) ---@type ViewComponent
    -- 属性介绍UI
    self.attributeIntroComp = self:Get("翅膀界面/翅膀显示栏/属性介绍", ViewComponent) ---@type ViewComponent
    self.attributeList = self:Get("翅膀界面/翅膀显示栏/属性介绍/属性栏位", ViewList) ---@type ViewList
    self.attributeTemplate = self:Get("翅膀界面/翅膀显示栏/属性介绍/属性栏位/属性栏", ViewComponent) ---@type ViewComponent
    if self.attributeTemplate and self.attributeTemplate.node then
        self.attributeTemplate.node.Visible = false -- 隐藏模板
    end

    -- 翅膀栏位列表
    self.wingSlotList = self:Get("翅膀界面/翅膀栏位", ViewList) ---@type ViewList
    -- 翅膀槽位模板
    self.slotTemplate = self:Get("翅膀界面/模板栏位/翅膀1", ViewComponent) ---@type ViewComponent
    self.slotTemplate:SetVisible(false)

    -- 数据存储
    self.wingData = {} ---@type table 服务端同步的翅膀数据
    self.selectedWing = nil ---@type table 当前选中的翅膀
    self.wingSlotButtons = {} ---@type table 翅膀槽位按钮映射
    self.activeSlots = {} ---@type table<string, number> 当前激活的翅膀槽位映射
    self.equipSlotIds = {} ---@type table<string> 所有可用的装备栏ID
    self.wingConfigs = {} ---@type table 翅膀配置缓存
    self.wingBagCapacity = 30 -- 默认背包容量
    self.unlockedEquipSlots = 1 -- 默认可装备栏位数量（翅膀只有一个装备栏）

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    --gg.log("WingGui 翅膀界面初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function WingGui:RegisterEvents()
    --gg.log("注册翅膀系统事件监听")

    -- 监听翅膀列表响应
    ClientEventManager.Subscribe(WingEventConfig.NOTIFY.WING_LIST_UPDATE, function(data)
        self:OnWingListResponse(data)
    end)

    -- 监听翅膀升星响应
    ClientEventManager.Subscribe(WingEventConfig.RESPONSE.WING_STAR_UPGRADED, function(data)
        self:OnUpgradeStarResponse(data)
    end)

    -- 监听翅膀装备/卸下等更新
    ClientEventManager.Subscribe(WingEventConfig.NOTIFY.WING_UPDATE, function(data)
        self:OnWingUpdateNotify(data)
    end)

    -- 监听新获得翅膀通知
    ClientEventManager.Subscribe(WingEventConfig.NOTIFY.WING_OBTAINED, function(data)
        self:OnWingObtainedNotify(data)
    end)

    -- 监听翅膀移除通知
    ClientEventManager.Subscribe(WingEventConfig.NOTIFY.WING_REMOVED, function(data)
        self:OnWingRemovedNotify(data)
    end)

    -- 监听错误响应
    ClientEventManager.Subscribe(WingEventConfig.RESPONSE.ERROR, function(data)
        self:OnWingErrorResponse(data)
    end)

    -- 【新增】监听自动装备结果响应
    ClientEventManager.Subscribe(WingEventConfig.RESPONSE.WING_EFFECT_RANKING, function(data)
        self:OnAutoEquipResultResponse(data)
    end)
end

function WingGui:RegisterButtonEvents()
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
        self:OnClickEquipWing()
    end

    -- 卸下按钮
    self.unequipButton.clickCb = function()
        self:OnClickUnequipWing()
    end

    -- 【新增】一键合成按钮
    if self.Synthesis then
        self.Synthesis.clickCb = function()
            self:OnClickSynthesis()
        end
    end

    -- 【新增】装备最佳按钮
    if self.UltimateEqu then
        self.UltimateEqu.clickCb = function()
            self:OnClickUltimateEquip()
        end
    end

    -- 【新增】删除按钮
    if self.deleteButton then
        self.deleteButton.clickCb = function()
            self:OnClickDeleteWing()
        end
    end

    -- 【新增】锁定按钮
    if self.lockButton then
        self.lockButton.clickCb = function()
            self:OnClickLockWing()
        end
    end

    --gg.log("翅膀界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

function WingGui:OnOpen()
    --gg.log("WingGui翅膀界面打开")
    self:RequestWingData()
end

function WingGui:OnClose()
    --gg.log("WingGui翅膀界面关闭")
end

-- =================================
-- 数据请求与响应
-- =================================

--- 请求翅膀数据
function WingGui:RequestWingData()
    local requestData = {
        cmd = WingEventConfig.REQUEST.GET_WING_LIST,
        args = {}
    }
    --gg.log("请求翅膀数据同步")
    gg.network_channel:FireServer(requestData)
end

--- 处理翅膀列表响应
function WingGui:OnWingListResponse(data)
    -- --gg.log("收到翅膀数据响应:", data)
    -- 【修复】直接访问companionList，不需要wingList包装层
    if data and data.companionList then
        self.wingData = data.companionList
        self.activeSlots = data.activeSlots or {}
        self.equipSlotIds = data.equipSlotIds or {}
        self.wingBagCapacity = data.bagCapacity or 30
        self.unlockedEquipSlots = data.unlockedEquipSlots or 1
        -- gg.log("翅膀数据:", self.activeSlots, self.equipSlotIds, self.wingBagCapacity, self.unlockedEquipSlots)

        --gg.log("翅膀数据同步完成, 激活槽位:", self.activeSlots)

        -- 刷新界面显示
        self:RefreshWingList()
        self:SelectDefaultWing()
    else
        --gg.log("翅膀数据响应格式错误或列表为空")
    end
end

--- 处理升星响应
function WingGui:OnUpgradeStarResponse(data)
    --gg.log("收到升星响应:", data)
    if data.success and data.wingSlot then
        local slotIndex = data.wingSlot
        local newStarLevel = data.newStarLevel

        -- 更新本地数据
        if self.wingData[slotIndex] then
            self.wingData[slotIndex].starLevel = newStarLevel
            --gg.log("翅膀升星成功:", slotIndex, "新星级:", newStarLevel)

            -- 刷新显示
            self:RefreshWingSlotDisplay(slotIndex)
            if self.selectedWing and self.selectedWing.slotIndex == slotIndex then
                self:RefreshSelectedWingDisplay()
            end
        end
    else
        --gg.log("翅膀升星失败:", data.errorMessage or "未知错误")
    end
end

--- 处理翅膀更新通知
function WingGui:OnWingUpdateNotify(data)
    --gg.log("收到翅膀更新通知:", data)
    if data.wingSlot and data.wingInfo then
        local slotIndex = data.wingSlot
        self.wingData[slotIndex] = data.wingInfo

        if data.activeSlots then
            self.activeSlots = data.activeSlots
        end

        -- 【新增】更新携带数量显示
        if self.carryCountLabel then
            local equippedCount = 0
            for _ in pairs(self.activeSlots) do
                equippedCount = equippedCount + 1
            end
            self.carryCountLabel.node.Title = string.format("携带数量: %d/%d", equippedCount, self.unlockedEquipSlots)
        end

        -- 刷新显示
        self:RefreshWingList() -- 全量刷新以保证排序和激活状态正确
        if self.selectedWing and self.selectedWing.slotIndex == slotIndex then
            self:RefreshSelectedWingDisplay()
        end
    end
end

--- 处理新获得翅膀通知
function WingGui:OnWingObtainedNotify(data)
    --gg.log("收到新获得翅膀通知:", data)
    if data.wingSlot and data.wingInfo then
        local slotIndex = data.wingSlot
        self.wingData[slotIndex] = data.wingInfo

        if self:IsOpen() then
            self:CreateWingSlotItem(slotIndex, data.wingInfo)
            --gg.log("新翅膀已添加到界面显示:", data.wingInfo.companionName)
        end
    end
end

--- 处理翅膀移除通知
function WingGui:OnWingRemovedNotify(data)
    --gg.log("收到翅膀移除通知:", data)
    if data.wingSlot then
        local slotIndex = data.wingSlot
        self.wingData[slotIndex] = nil

        -- 刷新显示
        self:RefreshWingList()
        if self.selectedWing and self.selectedWing.slotIndex == slotIndex then
            self.selectedWing = nil
            self:RefreshSelectedWingDisplay()
        end
    end
end

--- 处理错误响应
function WingGui:OnWingErrorResponse(data)
    --gg.log("收到翅膀系统错误响应:", data)
    local errorMessage = data.errorMessage or "操作失败"
    --gg.log("错误信息:", errorMessage)
    -- TODO: 显示错误提示给玩家
end

--- 【新增】处理自动装备结果响应
function WingGui:OnAutoEquipResultResponse(data)
    --gg.log("收到自动装备结果响应:", data)
    
    if data.ranking then
        --gg.log("自动装备完成，翅膀效果排行:", data.ranking)
        
        -- 刷新界面显示
        self:RequestWingData() -- 重新请求翅膀数据以获取最新的装备状态
        
        -- 恢复装备最佳按钮状态
        if self.UltimateEqu then
            self.UltimateEqu:SetGray(false)
            self.UltimateEqu:SetTouchEnable(true, nil)
        end
        
        -- 可以在这里添加成功提示
        --gg.log("自动装备所有最优翅膀完成！")
    else
        --gg.log("自动装备失败或没有响应数据")
        
        -- 恢复装备最佳按钮状态
        if self.UltimateEqu then
            self.UltimateEqu:SetGray(false)
            self.UltimateEqu:SetTouchEnable(true, nil)
        end
    end
end

--- 检查界面是否已打开
function WingGui:IsOpen()
    return self.wingPanel and self.wingPanel:IsVisible()
end

-- =================================
-- 按钮操作处理
-- =================================

--- 升星按钮点击
function WingGui:OnClickUpgradeStar()
    if not self.selectedWing then
        --gg.log("未选中翅膀，无法升星")
        return
    end

    local slotIndex = self.selectedWing.slotIndex
    local currentStarLevel = self.selectedWing.starLevel or 1

    --gg.log("点击升星按钮:", "槽位", slotIndex, "当前星级", currentStarLevel)

    local wingConfig = self:GetWingConfig(self.selectedWing.companionName)
    if wingConfig and currentStarLevel >= (wingConfig.maxStarLevel or 5) then
        --gg.log("翅膀已达最高星级")
        return
    end

    self:SendUpgradeStarRequest(slotIndex)
end

--- 装备按钮点击
function WingGui:OnClickEquipWing()
    if not self.selectedWing then
        --gg.log("未选中翅膀，无法装备")
        return
    end

    local wingSlotId = self.selectedWing.slotIndex
    local equipSlotId = self:FindNextAvailableEquipSlot()

    if not equipSlotId then
        --gg.log("没有可用的装备栏")
        return
    end

    --gg.log("点击装备按钮:", "背包槽位", wingSlotId, "目标装备栏", equipSlotId)
    self:SendEquipWingRequest(wingSlotId, equipSlotId)
end

--- 卸下按钮点击
function WingGui:OnClickUnequipWing()
    if not self.selectedWing then
        --gg.log("未选中翅膀，无法卸下")
        return
    end

    local wingSlotId = self.selectedWing.slotIndex
    local equipSlotId = self:GetEquipSlotByWingSlot(wingSlotId)

    if not equipSlotId then
        --gg.log("错误：该翅膀并未装备，但卸下按钮可见")
        return
    end

    --gg.log("点击卸下按钮:", "从装备栏", equipSlotId)
    self:SendUnequipWingRequest(equipSlotId)
end

--- 【新增】一键合成按钮点击
function WingGui:OnClickSynthesis()
    --gg.log("点击了一键合成按钮，发送升星请求")
    local requestData = {
        cmd = WingEventConfig.REQUEST.UPGRADE_ALL_WINGS,
        args = {}
    }
    gg.network_channel:FireServer(requestData)
end

--- 【新增】装备最佳按钮点击
function WingGui:OnClickUltimateEquip()
    --gg.log("点击了装备最佳按钮，发送自动装备所有最优翅膀请求")
    
    -- 发送自动装备所有最优翅膀的请求
    local requestData = {
        cmd = WingEventConfig.REQUEST.AUTO_EQUIP_ALL_BEST_WINGS,
        args = {
            excludeEquipped = true -- 排除已装备的翅膀，避免重复装备
        }
    }
    
    --gg.log("发送自动装备所有最优翅膀请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

--- 【新增】删除翅膀按钮点击
function WingGui:OnClickDeleteWing()
    if not self.selectedWing then
        --gg.log("未选择翅膀，无法删除")
        return
    end

    if self.selectedWing.isLocked then
        --gg.log("翅膀已锁定，无法删除")
        -- TODO: 可以向玩家显示提示
        return
    end

    -- TODO: 在实际项目中，这里应该弹出一个二次确认对话框
    --gg.log("请求删除翅膀:", self.selectedWing.slotIndex)
    self:SendDeleteWingRequest(self.selectedWing.slotIndex)
end

--- 【新增】锁定翅膀按钮点击
function WingGui:OnClickLockWing()
    if not self.selectedWing then
        --gg.log("未选择翅膀，无法切换锁定状态")
        return
    end

    --gg.log("请求切换翅膀锁定状态:", self.selectedWing.slotIndex)
    self:SendToggleLockRequest(self.selectedWing.slotIndex)
end

-- =================================
-- 网络请求发送
-- =================================

--- 发送升星请求
function WingGui:SendUpgradeStarRequest(slotIndex)
    local requestData = {
        cmd = WingEventConfig.REQUEST.UPGRADE_WING_STAR,
        args = { slotIndex = slotIndex }
    }
    --gg.log("发送翅膀升星请求:", slotIndex)
    gg.network_channel:FireServer(requestData)
end

--- 发送装备/卸下请求
function WingGui:SendEquipWingRequest(wingSlotId, equipSlotId)
    local requestData = {
        cmd = WingEventConfig.REQUEST.EQUIP_WING,
        args = {
            companionSlotId = wingSlotId,
            equipSlotId = equipSlotId
        }
    }
    --gg.log("发送装备翅膀请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

function WingGui:SendUnequipWingRequest(equipSlotId)
    local requestData = {
        cmd = WingEventConfig.REQUEST.UNEQUIP_WING,
        args = {
            equipSlotId = equipSlotId
        }
    }
    --gg.log("发送卸下翅膀请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

--- 【新增】发送删除翅膀请求
function WingGui:SendDeleteWingRequest(slotIndex)
    local requestData = {
        cmd = WingEventConfig.REQUEST.DELETE_WING,
        args = { slotIndex = slotIndex }
    }
    --gg.log("发送删除翅膀请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

--- 【新增】发送切换锁定状态请求
function WingGui:SendToggleLockRequest(slotIndex)
    local requestData = {
        cmd = WingEventConfig.REQUEST.TOGGLE_WING_LOCK,
        args = { slotIndex = slotIndex }
    }
    --gg.log("发送切换锁定状态请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

-- =================================
-- UI刷新方法
-- =================================

--- 刷新翅膀列表
function WingGui:RefreshWingList()
    --gg.log("刷新翅膀列表显示")

    self.wingSlotButtons = {}
    self.wingSlotList:ClearChildren()

    local wingList = self:GetSortedWingList()

    for _, item in ipairs(wingList) do
        local wingInfo = item.info
        self:CreateWingSlotItem(wingInfo.slotIndex, wingInfo)
    end

    -- 【新增】更新翅膀数量显示
    local wingCount = self:GetWingCount()
    if self.carryCountLabel then
        self.carryCountLabel.node.Title = string.format("%d/%d", wingCount, self.wingBagCapacity)
    end

    -- 【新增】更新携带数量显示
    local equippedCount = 0

    if self.WingCarryNumLabel then
        for _ in pairs(self.activeSlots) do
            equippedCount = equippedCount + 1
        end
        self.WingCarryNumLabel.node.Title = string.format("%d/%d", equippedCount, self.unlockedEquipSlots)
    end
    -- gg.log("翅膀数量111:", wingCount, self.wingBagCapacity,equippedCount, self.unlockedEquipSlots)

    --gg.log("翅膀列表刷新完成")
end

--- 创建翅膀槽位项
function WingGui:CreateWingSlotItem(slotIndex, companionInfo)
    if not self.slotTemplate or not self.slotTemplate.node then
        --gg.log("警告：翅膀槽位模板不存在")
        return
    end
    --gg.log("创建翅膀槽位项", slotIndex, companionInfo)

    local slotNode = self.slotTemplate.node:Clone()
    slotNode.Visible = true
    slotNode.Name = companionInfo.companionName .. "_" .. slotIndex

    self.wingSlotList:AppendChild(slotNode)

    self:SetupWingSlotDisplay(slotNode, slotIndex, companionInfo)

    local slotButton = ViewButton.New(slotNode, self)
    slotButton.clickCb = function()
        self:OnWingSlotClick(slotIndex, companionInfo)
    end

    self.wingSlotButtons[slotIndex] = slotButton
end

--- 设置翅膀槽位显示
function WingGui:SetupWingSlotDisplay(slotNode, slotIndex, wingInfo)
    if not slotNode then return end

    local backgroundNode = slotNode["背景"]
    if not backgroundNode then return end

    local wingConfig = self:GetWingConfig(wingInfo.companionName) ---@type PetType

    if wingConfig and wingConfig.rarity then
        local qualityBg = CardIcon.qualityBackGroundIcon[wingConfig.rarity]
        if qualityBg then
            backgroundNode.Icon = qualityBg
        end
    end

    local iconNode = backgroundNode["图标"]
    if iconNode and wingConfig and wingConfig.avatarResource then
        iconNode.Icon = wingConfig.avatarResource
    end

    self:UpdateStarDisplayInSlot(slotNode, wingInfo.starLevel or 1)

    local isEquipped = self:IsWingEquipped(slotIndex)
    self:UpdateActiveState(slotNode, isEquipped)

    -- 【新增】更新锁定状态显示
    local lockNode = slotNode:FindFirstChild("锁定")
    if lockNode then
        lockNode.Visible = wingInfo.isLocked or false
    end
end

--- 更新槽位中的星级显示
function WingGui:UpdateStarDisplayInSlot(slotNode, starLevel)
    -- TODO: 根据UI结构更新槽位中的星级显示
    --gg.log("更新翅膀槽位星级显示:", starLevel)
end

--- 更新激活状态显示
function WingGui:UpdateActiveState(slotNode, isActive)
    local activeMark = slotNode["选中"] -- 假设激活标记节点叫"选中"
    if activeMark then
        activeMark.Visible = isActive
    end
end

--- 刷新指定槽位显示
function WingGui:RefreshWingSlotDisplay(slotIndex)
    local wingInfo = self.wingData[slotIndex]
    if not wingInfo then return end

    local nodeName = wingInfo.companionName .. "_" .. slotIndex
    local slotNode = self.wingSlotList.node:FindFirstChild(nodeName)
    if slotNode then
        self:SetupWingSlotDisplay(slotNode, slotIndex, wingInfo)
    end
end

--- 翅膀槽位点击事件
function WingGui:OnWingSlotClick(slotIndex, wingInfo)
    --gg.log("点击翅膀槽位:", slotIndex, wingInfo.companionName)

    local isEquipped = self:IsWingEquipped(slotIndex)

    self.selectedWing = {
        slotIndex = slotIndex,
        wingName = wingInfo.companionName,
        level = wingInfo.level,
        starLevel = wingInfo.starLevel,
        isEquipped = isEquipped,
        isLocked = wingInfo.isLocked or false -- 【新增】添加锁定状态
    }

    self:RefreshSelectedWingDisplay()
end

--- 刷新选中翅膀显示
function WingGui:RefreshSelectedWingDisplay()
    if not self.selectedWing then
        self:HideWingDetail()
        return
    end

    local wing = self.selectedWing
    --gg.log("刷新选中翅膀显示:", wing.wingName)

    local wingConfig = self:GetWingConfig(wing.wingName)
    if self.wingUI and wingConfig and wingConfig.avatarResource then
        self.wingUI.node.Icon = wingConfig.avatarResource
    end

    if self.nameLabel then
        local displayName = wing.customName or wing.wingName
        self.nameLabel.node.Title = displayName
    end

    if self.starList then
        local currentStarLevel = wing.starLevel or 0
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
                    -- 设置为暗星
                    starNode.Icon = unlitIcon
                end
            end
        end
    end

    self:UpdateAttributeDisplay(wingConfig, wing.starLevel)
    self:UpdateButtonStates(wing)
end

--- 更新属性介绍显示
function WingGui:UpdateAttributeDisplay(wingConfig, starLevel)
    if not self.attributeList or not wingConfig then
        if self.attributeList then self.attributeList:HideChildrenFrom(0) end
        return
    end

    local currentStar = starLevel or 0
    local maxStar = wingConfig.maxStarLevel or 5

    local currentEffects = wingConfig:CalculateCarryingEffectsByStarLevel(currentStar)
    local nextEffects = {}
    if currentStar < maxStar then
        nextEffects = wingConfig:CalculateCarryingEffectsByStarLevel(currentStar + 1)
    end

    local effectsToShow = {}
    for name, data in pairs(currentEffects) do
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
            local currentEffectData = effectInfo.data
            local nextEffectData = nextEffects[variableName]
            self:UpdateAttributeItem(attributeItem.node, variableName, currentEffectData, nextEffectData, wingConfig, currentStar >= maxStar)
        end
    end

    self.attributeList:HideChildrenFrom(numEffects)
end

--- 更新单个属性项的显示
function WingGui:UpdateAttributeItem(attributeNode, variableName, currentEffectData, nextEffectData, wingConfig, isMaxStar)
    if not attributeNode then return end

    local currentAttrText = attributeNode:FindFirstChild("当前属性")
    local nextAttrText = attributeNode:FindFirstChild("升星属性")

    if currentAttrText and currentEffectData then
        currentAttrText.Title = wingConfig:FormatEffectDescription(variableName, currentEffectData.value, currentEffectData.isPercentage)
    end

    if nextAttrText then
        if isMaxStar then
            nextAttrText.Title = "升星属性: 已满级"
        elseif nextEffectData then
            nextAttrText.Title = wingConfig:FormatEffectDescription(variableName, nextEffectData.value, nextEffectData.isPercentage)
        else
            nextAttrText.Title = "升星属性: N/A"
        end
    end
end

--- 更新按钮状态
function WingGui:UpdateButtonStates(wing)
    if not wing then return end

    if self.upgradeButton then
        self.upgradeButton:SetVisible(true)
        local wingConfig = self:GetWingConfig(wing.wingName)
        local maxStarLevel = wingConfig and wingConfig.maxStarLevel or 5
        local canUpgrade = (wing.starLevel or 1) < maxStarLevel
        self.upgradeButton:SetGray(not canUpgrade)
        self.upgradeButton:SetTouchEnable(canUpgrade, nil)
    end

    local isEquipped = wing.isEquipped
    local hasEmptySlot = self:FindNextAvailableEquipSlot() ~= nil

    if self.equipButton then
        local canEquip = not isEquipped and hasEmptySlot
        self.equipButton:SetVisible(canEquip)
        self.equipButton:SetTouchEnable(canEquip, nil)
    end
    if self.unequipButton then
        self.unequipButton:SetVisible(isEquipped)
    end

    -- 【新增】更新删除和锁定按钮的状态
    if self.deleteButton then
        -- 只有在未锁定的情况下才可删除
        self.deleteButton:SetVisible(true)
        self.deleteButton:SetGray(wing.isLocked)
        self.deleteButton:SetTouchEnable(not wing.isLocked, nil)
    end

    if self.lockButton then
        self.lockButton:SetVisible(true)
        -- TODO: 可以根据锁定状态改变按钮文本或图标
        -- local lockText = self.lockButton.node:FindFirstChild("Text")
        -- if lockText then lockText.Title = wing.isLocked and "解锁" or "锁定" end
    end
end

--- 隐藏翅膀详情
function WingGui:HideWingDetail()
    if self.nameLabel then self.nameLabel.node.Title = "" end
    if self.wingUI then self.wingUI.node.Icon = "" end

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
    if self.attributeList then self.attributeList:HideChildrenFrom(0) end

    if self.upgradeButton then self.upgradeButton:SetVisible(false) end
    if self.equipButton then self.equipButton:SetVisible(false) end
    if self.unequipButton then self.unequipButton:SetVisible(false) end

    -- 【新增】隐藏删除和锁定按钮
    if self.deleteButton then self.deleteButton:SetVisible(false) end
    if self.lockButton then self.lockButton:SetVisible(false) end
end

-- =================================
-- 工具方法
-- =================================

--- 获取排序后的翅膀列表
function WingGui:GetSortedWingList()
    -- 1. 将翅膀数据从字典转为包含排序信息的数组
    local wingList = {}
    for slotIndex, wingInfo in pairs(self.wingData) do
        -- 为每个翅膀动态计算并添加 isEquipped 和 slotIndex 标志
        wingInfo.isEquipped = self:IsWingEquipped(slotIndex)
        wingInfo.slotIndex = slotIndex

        local config = self:GetWingConfig(wingInfo.companionName)
        table.insert(wingList, {
            info = wingInfo,
            rarity = config and config.rarity or 0,
        })
    end

    -- 2. 按新的排序规则排序：1.装备 > 2.品质 > 3.星级
    table.sort(wingList, function(a, b)
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

        -- 规则3: 星级 (高星级在前)
        local aStars = aInfo.starLevel or 0
        local bStars = bInfo.starLevel or 0
        if aStars ~= bStars then
            return aStars > bStars
        end

        -- 规则4: 如果都相同, 按槽位ID排序 (保持稳定)
        return (aInfo.slotIndex or 0) < (bInfo.slotIndex or 0)
    end)

    return wingList
end

--- 检查翅膀是否已装备
function WingGui:IsWingEquipped(wingSlotId)
    for _, equippedId in pairs(self.activeSlots) do
        if equippedId == wingSlotId then return true end
    end
    return false
end

--- 根据翅膀背包槽位ID查找其所在的装备栏ID
function WingGui:GetEquipSlotByWingSlot(wingSlotId)
    for equipId, compId in pairs(self.activeSlots) do
        if compId == wingSlotId then return equipId end
    end
    return nil
end

--- 查找下一个可用的装备栏ID
function WingGui:FindNextAvailableEquipSlot()
    for _, equipId in ipairs(self.equipSlotIds) do
        if not self.activeSlots[equipId] then
            return equipId
        end
    end
    return nil
end

--- 获取翅膀配置
function WingGui:GetWingConfig(wingName)
    if not wingName then return nil end

    if not self.wingConfigs[wingName] then
        self.wingConfigs[wingName] = ConfigLoader.GetWing(wingName)
    end

    return self.wingConfigs[wingName]
end

--- 获取翅膀数量
function WingGui:GetWingCount()
    local count = 0
    for _ in pairs(self.wingData) do
        count = count + 1
    end
    return count
end

--- 默认选择第一个翅膀
function WingGui:SelectDefaultWing()
    --gg.log("尝试默认选择第一个翅膀")

    local sortedList = self:GetSortedWingList()

    if #sortedList > 0 then
        local firstWing = sortedList[1].info
        --gg.log("默认选择翅膀:", firstWing.companionName)
        self:OnWingSlotClick(firstWing.slotIndex, firstWing)
    else
        --gg.log("没有翅膀可供选择，清空详情")
        self.selectedWing = nil
        self:RefreshSelectedWingDisplay()
    end
end

return WingGui.New(script.Parent, uiConfig)
