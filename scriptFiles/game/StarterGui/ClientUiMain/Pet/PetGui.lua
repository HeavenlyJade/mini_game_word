local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local PetEventConfig = require(MainStorage.Code.Event.EventPet) ---@type PetEventConfig
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "PetGui",
    layer = 3,
    hideOnInit = true,
}

---@class PetGui:ViewBase
local PetGui = ClassMgr.Class("PetGui", ViewBase)

---@override
function PetGui:OnInit(node, config)
    -- 1. 节点初始化
    self.petPanel = self:Get("宠物界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("宠物界面/关闭", ViewButton) ---@type ViewButton
    self.petCountLabel = self:Get("宠物界面/宠物数量文本", ViewComponent) ---@type ViewComponent

    -- 宠物显示栏
    self.displayBar = self:Get("宠物界面/宠物显示栏", ViewComponent) ---@type ViewComponent
    self.upgradeButton = self:Get("宠物界面/宠物显示栏/升星", ViewButton) ---@type ViewButton
    self.equipButton = self:Get("宠物界面/宠物显示栏/装备", ViewButton) ---@type ViewButton
    self.unequipButton = self:Get("宠物界面/宠物显示栏/卸下", ViewButton) ---@type ViewButton
    self.petUI = self:Get("宠物界面/宠物显示栏/宠物UI", ViewComponent) ---@type ViewComponent

    -- 星级UI
    -- self.starUI = self:Get("宠物界面/宠物显示栏/星级UI", ViewComponent) ---@type ViewComponent
    self.starList = self:Get("宠物界面/宠物显示栏/星级UI/星级", ViewList) ---@type ViewList
    self.nameLabel = self:Get("宠物界面/宠物显示栏/名字", ViewComponent) ---@type ViewComponent
    self.Synthesis= self:Get("宠物界面/宠物显示栏/一键合成", ViewButton) ---@type ViewButton
    self.UltimateEqu = self:Get("宠物界面/宠物显示栏/装备最佳", ViewButton) ---@type ViewButton

    -- 属性介绍UI
    self.attributeIntroComp = self:Get("宠物界面/宠物显示栏/属性介绍", ViewComponent) ---@type ViewComponent
    self.attributeList = self:Get("宠物界面/宠物显示栏/属性介绍/属性栏位", ViewList) ---@type ViewList
    self.attributeTemplate = self:Get("宠物界面/宠物显示栏/属性介绍/属性栏位/属性栏", ViewComponent) ---@type ViewComponent
    if self.attributeTemplate and self.attributeTemplate.node then
        self.attributeTemplate.node.Visible = false -- 隐藏模板
    end

    -- 宠物栏位列表
    self.petSlotList = self:Get("宠物界面/宠物栏位", ViewList) ---@type ViewList
    -- 模板从模版界面取
    self.slotTemplate = self:Get("宠物界面/模版界面/宠物_1", ViewComponent) ---@type ViewComponent

    -- 宠物携带带
    self.petCarryNumLabel = self:Get("宠物界面/宠物数量/携带数量", ViewComponent) ---@type ViewComponent
    self.carryCountLabel = self:Get("宠物界面/宠物数量/携带数量", ViewComponent) ---@type ViewComponent

    -- 删除按钮
    self.deleteButton = self:Get("宠物界面/删除", ViewButton) ---@type ViewButton
    self.lockButton = self:Get("宠物界面/锁定", ViewButton) ---@type ViewButton

    -- 数据存储
    self.petData = {} ---@type table 服务端同步的宠物数据
    self.selectedPet = nil ---@type table 当前选中的宠物
    self.petSlotButtons = {} ---@type table 宠物槽位按钮映射
    self.activeSlots = {} ---@type table<string, number> 当前激活的宠物槽位映射
    self.equipSlotIds = {} ---@type table<string> 所有可用的装备栏ID
    self.petConfigs = {} ---@type table 宠物配置缓存

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    gg.log("PetGui 宠物界面初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function PetGui:RegisterEvents()
    gg.log("注册宠物系统事件监听")
    
    -- 监听宠物列表响应
    ClientEventManager.Subscribe(PetEventConfig.NOTIFY.PET_LIST_UPDATE, function(data)
        self:OnPetListResponse(data)
    end)
    
    -- 监听宠物升星响应
    ClientEventManager.Subscribe(PetEventConfig.RESPONSE.PET_STAR_UPGRADED, function(data)
        self:OnUpgradeStarResponse(data)
    end)
    
    -- 监听宠物装备/卸下等更新
    ClientEventManager.Subscribe(PetEventConfig.NOTIFY.PET_UPDATE, function(data)
        self:OnPetUpdateNotify(data)
    end)
    
    -- 监听新获得宠物通知
    ClientEventManager.Subscribe(PetEventConfig.NOTIFY.PET_OBTAINED, function(data)
        self:OnPetObtainedNotify(data)
    end)
    
    -- 监听宠物移除通知
    ClientEventManager.Subscribe(PetEventConfig.NOTIFY.PET_REMOVED, function(data)
        self:OnPetRemovedNotify(data)
    end)
    
    -- 监听错误响应
    ClientEventManager.Subscribe(PetEventConfig.RESPONSE.ERROR, function(data)
        self:OnPetErrorResponse(data)
    end)
end

function PetGui:RegisterButtonEvents()
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
        self:OnClickEquipPet()
    end

    -- 卸下按钮
    self.unequipButton.clickCb = function()
        self:OnClickUnequipPet()
    end

    -- 删除按钮
    self.deleteButton.clickCb = function()
        self:OnClickDeletePet()
    end

    -- 锁定按钮
    self.lockButton.clickCb = function()
        self:OnClickLockPet()
    end

    gg.log("宠物界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

function PetGui:OnOpen()
    gg.log("PetGui宠物界面打开")
    self:RequestPetData()
end

function PetGui:OnClose()
    gg.log("PetGui宠物界面关闭")
end

-- =================================
-- 数据请求与响应
-- =================================

--- 请求宠物数据
function PetGui:RequestPetData()
    local requestData = {
        cmd = PetEventConfig.REQUEST.GET_PET_LIST,
        args = {}
    }
    gg.log("请求宠物数据同步")
    gg.network_channel:fireServer(requestData)
end

--- 处理宠物列表响应
function PetGui:OnPetListResponse(data)
    gg.log("收到宠物数据响应:", data)
    if data and data.petList then
        self.petData = data.petList
        self.activeSlots = data.activeSlots or {}
        self.equipSlotIds = data.equipSlotIds or {}
        
        gg.log("宠物数据同步完成, 激活槽位:", self.activeSlots)
        
        -- 刷新界面显示
        self:RefreshPetList()
        self:SelectDefaultPet()
    else
        gg.log("宠物数据响应格式错误")
    end
end

--- 处理升星响应
function PetGui:OnUpgradeStarResponse(data)
    gg.log("收到升星响应:", data)
    if data.success and data.petSlot then
        local slotIndex = data.petSlot
        local newStarLevel = data.newStarLevel
        
        -- 更新本地数据
        if self.petData[slotIndex] then
            self.petData[slotIndex].starLevel = newStarLevel
            gg.log("宠物升星成功:", slotIndex, "新星级:", newStarLevel)
            
            -- 刷新显示
            self:RefreshPetSlotDisplay(slotIndex)
            if self.selectedPet and self.selectedPet.slotIndex == slotIndex then
                self:RefreshSelectedPetDisplay()
            end
        end
    else
        gg.log("宠物升星失败:", data.errorMessage or "未知错误")
    end
end

--- 处理宠物更新通知
function PetGui:OnPetUpdateNotify(data)
    gg.log("收到宠物更新通知:", data)
    if data.petSlot and data.petInfo then
        local slotIndex = data.petSlot
        self.petData[slotIndex] = data.petInfo
        
        if data.activeSlots then
            self.activeSlots = data.activeSlots
        end
        
        -- 刷新显示
        self:RefreshPetList() -- 全量刷新以保证排序和激活状态正确
        if self.selectedPet and self.selectedPet.slotIndex == slotIndex then
            self:RefreshSelectedPetDisplay()
        end
    end
end

--- 处理新获得宠物通知
function PetGui:OnPetObtainedNotify(data)
    gg.log("收到新获得宠物通知:", data)
    if data.petSlot and data.petInfo then
        local slotIndex = data.petSlot
        self.petData[slotIndex] = data.petInfo
        
        if self:IsOpen() then
            self:CreatePetSlotItem(slotIndex, data.petInfo)
            gg.log("新宠物已添加到界面显示:", data.petInfo.petName)
        end
    end
end

--- 处理宠物移除通知
function PetGui:OnPetRemovedNotify(data)
    gg.log("收到宠物移除通知:", data)
    if data.slotIndex then
        local slotIndex = data.slotIndex
        self.petData[slotIndex] = nil
        
        if self:IsOpen() then
            self:RefreshPetList()
            if self.selectedPet and self.selectedPet.slotIndex == slotIndex then
                self:SelectDefaultPet()
            end
        end
    end
end


--- 处理错误响应
function PetGui:OnPetErrorResponse(data)
    gg.log("收到宠物系统错误响应:", data)
    local errorMessage = data.errorMessage or "操作失败"
    gg.log("错误信息:", errorMessage)
    -- TODO: 显示错误提示给玩家
end

--- 检查界面是否已打开
function PetGui:IsOpen()
    return self.petPanel and self.petPanel:IsVisible()
end

-- =================================
-- 按钮操作处理
-- =================================

--- 升星按钮点击
function PetGui:OnClickUpgradeStar()
    if not self.selectedPet then
        gg.log("未选中宠物，无法升星")
        return
    end
    
    local slotIndex = self.selectedPet.slotIndex
    local currentStarLevel = self.selectedPet.starLevel or 1
    
    gg.log("点击升星按钮:", "槽位", slotIndex, "当前星级", currentStarLevel)
    
    local petConfig = self:GetPetConfig(self.selectedPet.petName)
    if petConfig and currentStarLevel >= (petConfig.maxStarLevel or 5) then
        gg.log("宠物已达最高星级")
        return
    end
    
    self:SendUpgradeStarRequest(slotIndex)
end

--- 装备按钮点击
function PetGui:OnClickEquipPet()
    if not self.selectedPet then
        gg.log("未选中宠物，无法装备")
        return
    end

    local petSlotId = self.selectedPet.slotIndex
    local equipSlotId = self:FindNextAvailableEquipSlot()

    if not equipSlotId then
        gg.log("没有可用的装备栏")
        return
    end
    
    gg.log("点击装备按钮:", "背包槽位", petSlotId, "目标装备栏", equipSlotId)
    self:SendEquipPetRequest(petSlotId, equipSlotId)
end

--- 卸下按钮点击
function PetGui:OnClickUnequipPet()
    if not self.selectedPet then
        gg.log("未选中宠物，无法卸下")
        return
    end
    
    local petSlotId = self.selectedPet.slotIndex
    local equipSlotId = self:GetEquipSlotByPetSlot(petSlotId)

    if not equipSlotId then
        gg.log("错误：该宠物并未装备，但卸下按钮可见")
        return
    end

    gg.log("点击卸下按钮:", "从装备栏", equipSlotId)
    self:SendUnequipPetRequest(equipSlotId)
end

function PetGui:OnClickDeletePet()
    if not self.selectedPet then
        gg.log("未选择宠物，无法删除")
        return
    end

    if self.selectedPet.isLocked then
        gg.log("宠物已锁定，无法删除")
        -- TODO: 可以向玩家显示提示
        return
    end

    -- TODO: 在实际项目中，这里应该弹出一个二次确认对话框
    gg.log("请求删除宠物:", self.selectedPet.slotIndex)
    self:SendDeletePetRequest(self.selectedPet.slotIndex)
end

function PetGui:OnClickLockPet()
    if not self.selectedPet then
        gg.log("未选择宠物，无法切换锁定状态")
        return
    end

    gg.log("请求切换宠物锁定状态:", self.selectedPet.slotIndex)
    self:SendToggleLockRequest(self.selectedPet.slotIndex)
end

-- =================================
-- 网络请求发送
-- =================================

--- 发送升星请求
function PetGui:SendUpgradeStarRequest(slotIndex)
    local requestData = {
        cmd = PetEventConfig.REQUEST.UPGRADE_PET_STAR,
        args = { slotIndex = slotIndex }
    }
    gg.log("发送宠物升星请求:", slotIndex)
    gg.network_channel:fireServer(requestData)
end

--- 发送装备/卸下请求
function PetGui:SendEquipPetRequest(petSlotId, equipSlotId)
    local requestData = {
        cmd = PetEventConfig.REQUEST.EQUIP_PET,
        args = { 
            companionSlotId = petSlotId,
            equipSlotId = equipSlotId
        }
    }
    gg.log("发送装备宠物请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

function PetGui:SendUnequipPetRequest(equipSlotId)
    local requestData = {
        cmd = PetEventConfig.REQUEST.UNEQUIP_PET,
        args = { 
            equipSlotId = equipSlotId
        }
    }
    gg.log("发送卸下宠物请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

--- 【新增】发送删除宠物请求
function PetGui:SendDeletePetRequest(slotIndex)
    local requestData = {
        cmd = PetEventConfig.REQUEST.DELETE_PET,
        args = { slotIndex = slotIndex }
    }
    gg.log("发送删除宠物请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

--- 【新增】发送切换锁定状态请求
function PetGui:SendToggleLockRequest(slotIndex)
    local requestData = {
        cmd = PetEventConfig.REQUEST.TOGGLE_PET_LOCK,
        args = { slotIndex = slotIndex }
    }
    gg.log("发送切换锁定状态请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

-- =================================
-- UI刷新方法
-- =================================

--- 刷新宠物列表
function PetGui:RefreshPetList()
    gg.log("刷新宠物列表显示")
    
    self.petSlotButtons = {}
    self.petSlotList:ClearChildren()
    
    local petList = self:GetSortedPetList()

    for _, item in ipairs(petList) do
        local petInfo = item.info
        self:CreatePetSlotItem(petInfo.slotIndex, petInfo)
    end
    
    self.petCountLabel.node.Title = "宠物数量: " .. self:GetPetCount()
    gg.log("宠物列表刷新完成")
end

--- 创建宠物槽位项
function PetGui:CreatePetSlotItem(slotIndex, petInfo)
    if not self.slotTemplate or not self.slotTemplate.node then
        gg.log("警告：宠物槽位模板不存在")
        return
    end
    
    local slotNode = self.slotTemplate.node:Clone()
    slotNode.Visible = true
    slotNode.Name = petInfo.petName .. "_" .. slotIndex
    
    self.petSlotList:AppendChild(slotNode)
    
    self:SetupPetSlotDisplay(slotNode, slotIndex, petInfo)
    
    local slotButton = ViewButton.New(slotNode, self)
    slotButton.clickCb = function()
        self:OnPetSlotClick(slotIndex, petInfo)
    end
    
    self.petSlotButtons[slotIndex] = slotButton
end

--- 设置宠物槽位显示
function PetGui:SetupPetSlotDisplay(slotNode, slotIndex, petInfo)
    if not slotNode then return end
    
    local backgroundNode = slotNode["背景"]
    if not backgroundNode then return end
    
    local petConfig = self:GetPetConfig(petInfo.petName) ---@type PetType

    if petConfig and petConfig.rarity then
        local qualityBg = CardIcon.qualityBackGroundIcon[petConfig.rarity]
        if qualityBg then
            backgroundNode.Icon = qualityBg
        end
    end

    local iconNode = backgroundNode["图标"]
    if iconNode and petConfig and petConfig.avatarResource then
        iconNode.Icon = petConfig.avatarResource
    end

    self:UpdateStarDisplayInSlot(slotNode, petInfo.starLevel or 1)
    
    local isEquipped = self:IsPetEquipped(slotIndex)
    self:UpdateActiveState(slotNode, isEquipped)

    -- 【新增】更新锁定状态显示
    local lockNode = slotNode:FindFirstChild("锁定")
    if lockNode then
        lockNode.Visible = petInfo.isLocked or false
    end
end

--- 更新槽位中的星级显示
function PetGui:UpdateStarDisplayInSlot(slotNode, starLevel)
    -- TODO: 根据UI结构更新槽位中的星级显示，可能需要查找子节点
    -- 例如: local starText = slotNode:FindFirstChild("StarText")
    -- if starText then starText.Title = starLevel .. "星" end
end

--- 更新激活状态显示
function PetGui:UpdateActiveState(slotNode, isActive)
    local activeMark = slotNode["选中"] -- 假设激活标记节点叫“选中”
    if activeMark then
        activeMark.Visible = isActive
    end
end

--- 刷新指定槽位显示
function PetGui:RefreshPetSlotDisplay(slotIndex)
    local petInfo = self.petData[slotIndex]
    if not petInfo then return end
    
    local nodeName = petInfo.petName .. "_" .. slotIndex
    local slotNode = self.petSlotList.node:FindFirstChild(nodeName)
    if slotNode then
        self:SetupPetSlotDisplay(slotNode, slotIndex, petInfo)
    end
end

--- 宠物槽位点击事件
function PetGui:OnPetSlotClick(slotIndex, petInfo)
    gg.log("点击宠物槽位:", slotIndex, petInfo.petName)
    
    local isEquipped = self:IsPetEquipped(slotIndex)

    self.selectedPet = {
        slotIndex = slotIndex,
        petName = petInfo.petName,
        level = petInfo.level,
        starLevel = petInfo.starLevel,
        isEquipped = isEquipped,
        isLocked = petInfo.isLocked or false -- 【新增】
    }
    
    self:RefreshSelectedPetDisplay()
end

--- 刷新选中宠物显示
function PetGui:RefreshSelectedPetDisplay()
    if not self.selectedPet then
        self:HidePetDetail()
        return
    end
    
    local pet = self.selectedPet
    gg.log("刷新选中宠物显示:", pet.petName)

    local petConfig = self:GetPetConfig(pet.petName)
    if self.petUI and petConfig and petConfig.avatarResource then
        self.petUI.node.Icon = petConfig.avatarResource
    end
    
    if self.nameLabel then
        local displayName = pet.customName or pet.petName
        self.nameLabel.node.Title = displayName
    end
    
    if self.starList then
        local currentStarLevel = pet.starLevel or 0
        for i, starViewComp in ipairs(self.starList.childrensList or {}) do
            local starNode = starViewComp.node
            if starNode then
                starNode.Visible = (i <= currentStarLevel)
            end
        end
    end
    
    self:UpdateAttributeDisplay(petConfig, pet.starLevel)
    self:UpdateButtonStates(pet)
end

--- 更新属性介绍显示
function PetGui:UpdateAttributeDisplay(petConfig, starLevel)
    if not self.attributeList or not petConfig then
        if self.attributeList then self.attributeList:HideChildrenFrom(0) end
        return
    end
    
    local currentStar = starLevel or 0
    local maxStar = petConfig.maxStarLevel or 5
    
    local currentEffects = petConfig:CalculateCarryingEffectsByStarLevel(currentStar)
    local nextEffects = {}
    if currentStar < maxStar then
        nextEffects = petConfig:CalculateCarryingEffectsByStarLevel(currentStar + 1)
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
            self:UpdateAttributeItem(attributeItem.node, variableName, currentEffectData, nextEffectData, petConfig, currentStar >= maxStar)
        end
    end

    self.attributeList:HideChildrenFrom(numEffects)
end

--- 更新单个属性项的显示
function PetGui:UpdateAttributeItem(attributeNode, variableName, currentEffectData, nextEffectData, petConfig, isMaxStar)
    if not attributeNode then return end

    local currentAttrText = attributeNode:FindFirstChild("当前属性")
    local nextAttrText = attributeNode:FindFirstChild("升星属性")

    if currentAttrText and currentEffectData then
        currentAttrText.Title = petConfig:FormatEffectDescription(variableName, currentEffectData.value, currentEffectData.isPercentage)
    end

    if nextAttrText then
        if isMaxStar then
            nextAttrText.Title = "升星属性: 已满级"
        elseif nextEffectData then
            nextAttrText.Title = petConfig:FormatEffectDescription(variableName, nextEffectData.value, nextEffectData.isPercentage)
        else
            nextAttrText.Title = "升星属性: N/A"
        end
    end
end

--- 更新按钮状态
function PetGui:UpdateButtonStates(pet)
    if not pet then return end
    
    if self.upgradeButton then
        self.upgradeButton:SetVisible(true)
        local petConfig = self:GetPetConfig(pet.petName)
        local maxStarLevel = petConfig and petConfig.maxStarLevel or 5
        local canUpgrade = (pet.starLevel or 1) < maxStarLevel
        self.upgradeButton:SetGray(not canUpgrade)
        self.upgradeButton:SetTouchEnable(canUpgrade, nil)
    end
    
    local isEquipped = pet.isEquipped
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
        self.deleteButton:SetGray(pet.isLocked)
        self.deleteButton:SetTouchEnable(not pet.isLocked, nil)
    end

    if self.lockButton then
        self.lockButton:SetVisible(true)
        -- TODO: 可以根据锁定状态改变按钮文本或图标
        -- local lockText = self.lockButton.node:FindFirstChild("Text")
        -- if lockText then lockText.Title = pet.isLocked and "解锁" or "锁定" end
    end
end

--- 隐藏宠物详情
function PetGui:HidePetDetail()
    if self.nameLabel then self.nameLabel.node.Title = "未选择宠物" end
    if self.petUI then self.petUI.node.Icon = "" end

    if self.starList then
        for i, starViewComp in ipairs(self.starList.childrensList or {}) do
            local starNode = starViewComp.node
            if starNode then starNode.Visible = false end
        end
    end
    if self.attributeList then self.attributeList:HideChildrenFrom(0) end
    
    if self.upgradeButton then self.upgradeButton:SetVisible(false) end
    if self.equipButton then self.equipButton:SetVisible(false) end
    if self.unequipButton then self.unequipButton:SetVisible(false) end
    if self.deleteButton then self.deleteButton:SetVisible(false) end
    if self.lockButton then self.lockButton:SetVisible(false) end
end

-- =================================
-- 工具方法
-- =================================

--- 获取排序后的宠物列表
function PetGui:GetSortedPetList()
    local petList = {}
    for slotIndex, petInfo in pairs(self.petData) do
        petInfo.isEquipped = self:IsPetEquipped(slotIndex)
        petInfo.slotIndex = slotIndex

        local config = self:GetPetConfig(petInfo.petName)
        table.insert(petList, {
            info = petInfo,
            rarity = config and config.rarity or 0,
        })
    end

    table.sort(petList, function(a, b)
        if a.info.isEquipped ~= b.info.isEquipped then return a.info.isEquipped end
        if a.rarity ~= b.rarity then return a.rarity > b.rarity end
        local aStars = a.info.starLevel or 0
        local bStars = b.info.starLevel or 0
        if aStars ~= bStars then return aStars > bStars end
        return (a.info.slotIndex or 0) < (b.info.slotIndex or 0)
    end)
    
    return petList
end

--- 检查宠物是否已装备
function PetGui:IsPetEquipped(petSlotId)
    for _, equippedId in pairs(self.activeSlots) do
        if equippedId == petSlotId then return true end
    end
    return false
end

--- 根据宠物背包槽位ID查找其所在的装备栏ID
function PetGui:GetEquipSlotByPetSlot(petSlotId)
    for equipId, compId in pairs(self.activeSlots) do
        if compId == petSlotId then return equipId end
    end
    return nil
end

--- 查找下一个可用的装备栏ID
function PetGui:FindNextAvailableEquipSlot()
    for _, equipId in ipairs(self.equipSlotIds) do
        if not self.activeSlots[equipId] then
            return equipId
        end
    end
    return nil
end

--- 获取宠物配置
function PetGui:GetPetConfig(petName)
    if not petName then return nil end
    
    if not self.petConfigs[petName] then
        self.petConfigs[petName] = ConfigLoader.GetPet(petName)
    end
    
    return self.petConfigs[petName]
end

--- 获取宠物数量
function PetGui:GetPetCount()
    local count = 0
    for _ in pairs(self.petData) do
        count = count + 1
    end
    return count
end

--- 默认选择第一个宠物
function PetGui:SelectDefaultPet()
    gg.log("尝试默认选择第一个宠物")
    
    local sortedList = self:GetSortedPetList()
    
    if #sortedList > 0 then
        local firstPet = sortedList[1].info
        gg.log("默认选择宠物:", firstPet.petName)
        self:OnPetSlotClick(firstPet.slotIndex, firstPet)
    else
        gg.log("没有宠物可供选择，清空详情")
        self.selectedPet = nil
        self:RefreshSelectedPetDisplay()
    end
end

return PetGui.New(script.Parent, uiConfig)