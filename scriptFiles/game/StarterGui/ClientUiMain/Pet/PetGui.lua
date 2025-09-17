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
    self.getMoreButton = self:Get("宠物界面/获取更多", ViewButton) ---@type ViewButton

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
    self.slotTemplateSection = self:Get("宠物界面/模版界面",ViewList) ---@type ViewList
    self.slotTemplateSection:SetVisible(false)
    -- 模板从模版界面取
    self.slotTemplate = self:Get("宠物界面/模版界面/宠物_1", ViewComponent) ---@type ViewComponent

    -- 宠物携带带
    self.petCarryNumLabel = self:Get("宠物界面/宠物携带/携带数量", ViewComponent) ---@type ViewComponent
    self.petCarryNum = self:Get("宠物界面/宠物携带", ViewButton) ---@type ViewButton
    self.carryCountLabel = self:Get("宠物界面/宠物数量/携带数量", ViewComponent) ---@type ViewComponent
    self.petBagNum = self:Get("宠物界面/宠物数量", ViewButton) ---@type ViewButton

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
    self.petBagCapacity = 50 -- 默认背包容量
    self.unlockedEquipSlots = 3 -- 默认可携带栏位数量

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    ----gg.log("PetGui 宠物界面初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function PetGui:RegisterEvents()
    ----gg.log("注册宠物系统事件监听")

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

    -- 监听错误响应
    ClientEventManager.Subscribe(PetEventConfig.RESPONSE.ERROR, function(data)
        self:OnPetErrorResponse(data)
    end)
    
    -- 【新增】监听自动装备结果响应
    ClientEventManager.Subscribe(PetEventConfig.RESPONSE.PET_EFFECT_RANKING, function(data)
        self:OnAutoEquipResultResponse(data)
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

    -- 一键合成按钮
    if self.Synthesis then
        self.Synthesis.clickCb = function()
            self:OnClickSynthesis()
        end
    end

    -- 装备最佳按钮
    if self.UltimateEqu then
        self.UltimateEqu.clickCb = function()
            self:OnClickUltimateEquip()
        end
    end

    -- 获取更多按钮
    self.getMoreButton.clickCb = function()
        self:OnClickGetMorePet()
    end

    -- 【新增】携带数量按钮：打开商城并定位飞行币分类下的“宠物背包”
    if self.petBagNum then
        self.petBagNum.clickCb = function()
            --gg.log("点击携带数量，前往商城-飞行币-宠物背包")
            local shopGui = ViewBase.GetUI("ShopDetailGui")
            if shopGui then
                shopGui:OpenFromCommand({
                    categoryName = "飞行币",
                    shopItemId = "宠物背包"
                })
                -- 进入商城后关闭当前宠物界面
                self:Close()
            else
                ----gg.log("错误：找不到ShopDetailGui界面")
            end
        end
    end

    ----gg.log("宠物界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

function PetGui:OnOpen()
    ----gg.log("PetGui宠物界面打开")
    self:RequestPetData()
end

function PetGui:OnClose()
    ----gg.log("PetGui宠物界面关闭")
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
    ----gg.log("请求宠物数据同步")
    gg.network_channel:FireServer(requestData)
end

--- 处理宠物列表响应
function PetGui:OnPetListResponse(data)
    -- 【修复】恢复正确的逻辑，以处理被 petList 包装的数据
    if data and data.petList and data.petList.companionList then
        self.petData = data.petList.companionList
        self.activeSlots = data.petList.activeSlots or {}
        self.equipSlotIds = data.petList.equipSlotIds or {}
        self.petBagCapacity = data.petList.maxSlots or 50
        self.unlockedEquipSlots = data.petList.unlockedEquipSlots or 3

        ----gg.log("宠物数据同步完成, 激活槽位:", self.activeSlots)

        -- 刷新界面显示
        self:RefreshPetList()
        self:RefreshPetCounts()
        self:SelectDefaultPet()
    else
        ----gg.log("宠物数据响应格式错误或列表为空")
    end
end

--- 处理升星响应
function PetGui:OnUpgradeStarResponse(data)
    ----gg.log("收到升星响应:", data)
    if data.success and data.petSlot then
        local slotIndex = data.petSlot
        local newStarLevel = data.newStarLevel

        -- 更新本地数据
        if self.petData[slotIndex] then
            self.petData[slotIndex].starLevel = newStarLevel
            ----gg.log("宠物升星成功:", slotIndex, "新星级:", newStarLevel)

            -- 刷新显示
            self:RefreshPetSlotDisplay(slotIndex)
            if self.selectedPet and self.selectedPet.slotIndex == slotIndex then
                self:RefreshSelectedPetDisplay()
            end
        end
    else
        ----gg.log("宠物升星失败:", data.errorMessage or "未知错误")
    end
end

--- 处理宠物更新通知
function PetGui:OnPetUpdateNotify(data)
    ----gg.log("收到宠物更新通知:", data)
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
        self:RefreshPetCounts()
    end
end

--- 处理新获得宠物通知
function PetGui:OnPetObtainedNotify(data)
    ----gg.log("收到新获得宠物通知:", data)
    if data.petSlot and data.petInfo then
        local slotIndex = data.petSlot
        self.petData[slotIndex] = data.petInfo

        if self:IsOpen() then
            self:CreatePetSlotItem(slotIndex, data.petInfo)
            ----gg.log("新宠物已添加到界面显示:", data.petInfo.companionName)
        end
        self:RefreshPetCounts()
    end
end

--- 处理错误响应
function PetGui:OnPetErrorResponse(data)
    ----gg.log("收到宠物系统错误响应:", data)
    local errorMessage = data.errorMessage or "操作失败"
    ----gg.log("错误信息:", errorMessage)
    -- TODO: 显示错误提示给玩家
end

--- 【新增】处理自动装备结果响应
function PetGui:OnAutoEquipResultResponse(data)
    ----gg.log("收到自动装备结果响应:", data)
    
    if data.ranking then
        ----gg.log("自动装备完成，宠物效果排行:", data.ranking)
        
        -- 刷新界面显示
        self:RequestPetData() -- 重新请求宠物数据以获取最新的装备状态
        
        -- 恢复装备最佳按钮状态
        if self.UltimateEqu then
            self.UltimateEqu:SetGray(false)
            self.UltimateEqu:SetTouchEnable(true, nil)
        end
        
        -- 可以在这里添加成功提示
        ----gg.log("自动装备所有最优宠物完成！")
    else
        ----gg.log("自动装备失败或没有响应数据")
        
        -- 恢复装备最佳按钮状态
        if self.UltimateEqu then
            self.UltimateEqu:SetGray(false)
            self.UltimateEqu:SetTouchEnable(true, nil)
        end
    end
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
        ----gg.log("未选中宠物，无法升星")
        return
    end

    local slotIndex = self.selectedPet.slotIndex
    local currentStarLevel = self.selectedPet.starLevel or 1

    ----gg.log("点击升星按钮:", "槽位", slotIndex, "当前星级", currentStarLevel)

    local petConfig = self:GetPetConfig(self.selectedPet.companionName)
    if petConfig and currentStarLevel >= (petConfig.maxStarLevel or 5) then
        ----gg.log("宠物已达最高星级")
        return
    end

    self:SendUpgradeStarRequest(slotIndex)
end

--- 装备按钮点击
function PetGui:OnClickEquipPet()
    if not self.selectedPet then
        ----gg.log("未选中宠物，无法装备")
        return
    end

    local petSlotId = self.selectedPet.slotIndex
    local equipSlotId = self:FindNextAvailableEquipSlot()

    if not equipSlotId then
        ----gg.log("没有可用的装备栏")
        return
    end

    ----gg.log("点击装备按钮:", "背包槽位", petSlotId, "目标装备栏", equipSlotId)
    self:SendEquipPetRequest(petSlotId, equipSlotId)
end

--- 【新增】单个宠物自动装备最佳（可选功能）
function PetGui:OnClickAutoEquipBestPet()
    if not self.selectedPet then
        ----gg.log("未选中宠物，无法自动装备")
        return
    end

    local equipSlotId = self:FindNextAvailableEquipSlot()
    if not equipSlotId then
        ----gg.log("没有可用的装备栏")
        return
    end

    ----gg.log("点击单个宠物自动装备最佳:", "目标装备栏", equipSlotId)
    
    -- 发送单个宠物自动装备最佳请求
    local requestData = {
        cmd = PetEventConfig.REQUEST.AUTO_EQUIP_BEST_PET,
        args = {
            equipSlotId = equipSlotId,
            excludeEquipped = true
        }
    }
    
    gg.network_channel:FireServer(requestData)
end

--- 卸下按钮点击
function PetGui:OnClickUnequipPet()
    if not self.selectedPet then
        ----gg.log("未选中宠物，无法卸下")
        return
    end

    local petSlotId = self.selectedPet.slotIndex
    local equipSlotId = self:GetEquipSlotByPetSlot(petSlotId)

    if not equipSlotId then
        ----gg.log("错误：该宠物并未装备，但卸下按钮可见")
        return
    end

    ----gg.log("点击卸下按钮:", "从装备栏", equipSlotId)
    self:SendUnequipPetRequest(equipSlotId)
end

function PetGui:OnClickDeletePet()
    if not self.selectedPet then
        ----gg.log("未选择宠物，无法删除")
        return
    end

    if self.selectedPet.isLocked then
        ----gg.log("宠物已锁定，无法删除")
        -- TODO: 可以向玩家显示提示
        return
    end

    -- TODO: 在实际项目中，这里应该弹出一个二次确认对话框
    ----gg.log("请求删除宠物:", self.selectedPet.slotIndex)
    self:SendDeletePetRequest(self.selectedPet.slotIndex)
end

function PetGui:OnClickLockPet()
    if not self.selectedPet then
        ----gg.log("未选择宠物，无法切换锁定状态")
        return
    end

    ----gg.log("请求切换宠物锁定状态:", self.selectedPet.slotIndex)
    self:SendToggleLockRequest(self.selectedPet.slotIndex)
end

--- 一键合成按钮点击
function PetGui:OnClickSynthesis()
    ----gg.log("点击了一键合成按钮，发送升星请求")
    local requestData = {
        cmd = PetEventConfig.REQUEST.UPGRADE_ALL_PETS,
        args = {}
    }
    gg.network_channel:FireServer(requestData)
end

--- 装备最佳按钮点击
function PetGui:OnClickUltimateEquip()
    ----gg.log("点击了装备最佳按钮，发送自动装备所有最优宠物请求")
    
    -- 发送自动装备所有最优宠物的请求
    local requestData = {
        cmd = PetEventConfig.REQUEST.AUTO_EQUIP_ALL_BEST_PETS,
        args = {
            excludeEquipped = true -- 排除已装备的宠物，避免重复装备
        }
    }
    
    ----gg.log("发送自动装备所有最优宠物请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
    
    -- 按钮变灰并禁用触摸，等待服务端响应

end

--- 获取更多按钮点击
function PetGui:OnClickGetMorePet()
    -- 获取ShopDetailGui界面实例
    local shopGui = ViewBase.GetUI("ShopDetailGui")
    if shopGui then
        -- 打开商城界面
        shopGui:Open()
        -- 自动选择"宠物"分类
        shopGui:SelectCategory("宠物")
        -- 隐藏当前宠物界面
        self:Close()
    else
        ----gg.log("错误：找不到ShopDetailGui界面")
    end
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
    ----gg.log("发送宠物升星请求:", slotIndex)
    gg.network_channel:FireServer(requestData)
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
    ----gg.log("发送装备宠物请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

function PetGui:SendUnequipPetRequest(equipSlotId)
    local requestData = {
        cmd = PetEventConfig.REQUEST.UNEQUIP_PET,
        args = {
            equipSlotId = equipSlotId
        }
    }
    ----gg.log("发送卸下宠物请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

--- 【新增】发送删除宠物请求
function PetGui:SendDeletePetRequest(slotIndex)
    local requestData = {
        cmd = PetEventConfig.REQUEST.DELETE_PET,
        args = { slotIndex = slotIndex }
    }
    ----gg.log("发送删除宠物请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

--- 【新增】发送切换锁定状态请求
function PetGui:SendToggleLockRequest(slotIndex)
    local requestData = {
        cmd = PetEventConfig.REQUEST.TOGGLE_PET_LOCK,
        args = { slotIndex = slotIndex }
    }
    ----gg.log("发送切换锁定状态请求:", requestData.args)
    gg.network_channel:FireServer(requestData)
end

-- =================================
-- UI刷新方法
-- =================================

--- 刷新宠物携带和背包数量显示
function PetGui:RefreshPetCounts()
    -- 刷新宠物携带数量
    local equippedCount = 0
    if self.activeSlots then
        for _ in pairs(self.activeSlots) do
            equippedCount = equippedCount + 1
        end
    end
    local maxEquipped = self.unlockedEquipSlots
    if self.petCarryNumLabel and self.petCarryNumLabel.node then
        self.petCarryNumLabel.node.Title = string.format("%d/%d", equippedCount, maxEquipped)
    end

    -- 刷新宠物背包数量
    local bagCount = self:GetPetCount()
    if self.carryCountLabel and self.carryCountLabel.node then
        self.carryCountLabel.node.Title = string.format("%d/%d", bagCount, self.petBagCapacity)
    end
end

--- 刷新宠物列表
function PetGui:RefreshPetList()
    ----gg.log("刷新宠物列表显示")

    self.petSlotButtons = {}
    self.petSlotList:ClearChildren()

    local petList = self:GetSortedPetList()

    for _, item in ipairs(petList) do
        local petInfo = item.info
        self:CreatePetSlotItem(petInfo.slotIndex, petInfo)
    end

    self.petCountLabel.node.Title = "宠物数量: " .. self:GetPetCount()
    ----gg.log("宠物列表刷新完成")
end

--- 创建宠物槽位项
function PetGui:CreatePetSlotItem(slotIndex, companionInfo)
    if not self.slotTemplate or not self.slotTemplate.node then
        ----gg.log("警告：宠物槽位模板不存在")
        return
    end
    ----gg.log("创建宠物槽位项", slotIndex, companionInfo)

    local slotNode = self.slotTemplate.node:Clone()
    slotNode.Visible = true
    slotNode.Name = companionInfo.companionName .. "_" .. slotIndex

    self.petSlotList:AppendChild(slotNode)

    self:SetupPetSlotDisplay(slotNode, slotIndex, companionInfo)

    local slotButton = ViewButton.New(slotNode, self)
    slotButton.clickCb = function()
        self:OnPetSlotClick(slotIndex, companionInfo)
    end

    self.petSlotButtons[slotIndex] = slotButton
end

--- 设置宠物槽位显示
function PetGui:SetupPetSlotDisplay(slotNode, slotIndex, petInfo)
    if not slotNode then return end

    local backgroundNode = slotNode["背景"]
    if not backgroundNode then return end

    local petConfig = self:GetPetConfig(petInfo.companionName) ---@type PetType

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
    self:UpdateActiveState(backgroundNode, isEquipped)

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
    -- 更新"选中"节点显示
    local activeMark = slotNode["选中"]
    if activeMark then
        activeMark.Visible = isActive
    end
    
    -- 更新"装备"节点显示
    local equipMark = slotNode["装备"]
    if equipMark then
        equipMark.Visible = isActive
    end
end

--- 刷新指定槽位显示
function PetGui:RefreshPetSlotDisplay(slotIndex)
    local petInfo = self.petData[slotIndex]
    if not petInfo then return end

    local nodeName = petInfo.companionName .. "_" .. slotIndex
    local slotNode = self.petSlotList.node:FindFirstChild(nodeName)
    if slotNode then
        self:SetupPetSlotDisplay(slotNode, slotIndex, petInfo)
    end
end

--- 宠物槽位点击事件
function PetGui:OnPetSlotClick(slotIndex, petInfo)
    ----gg.log("点击宠物槽位:", slotIndex, petInfo.companionName)

    local isEquipped = self:IsPetEquipped(slotIndex)

    self.selectedPet = {
        slotIndex = slotIndex,
        petName = petInfo.companionName,
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
    ----gg.log("刷新选中宠物显示:", pet.petName)

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

    -- 如果是“最强加成”宠物，优先显示效果等级配置里的描述
    if petConfig.specialBonus == "最强加成" and petConfig.effectLevelType then
        local currentDesc = petConfig.effectLevelType.GetEffectDesc and petConfig.effectLevelType:GetEffectDesc(currentStar) or nil
        local nextDesc = nil
        if currentStar < maxStar then
            nextDesc = petConfig.effectLevelType.GetEffectDesc and petConfig.effectLevelType:GetEffectDesc(currentStar + 1) or nil
        end

        -- 仅展示一条描述信息
        self.attributeList:SetElementSize(1)
        local attributeItem = self.attributeList:GetChild(1)
        if attributeItem and attributeItem.node then
            local currentAttrText = attributeItem.node["当前属性"]
            local nextAttrText = attributeItem.node["升星属性"]

            if currentAttrText then
                currentAttrText.Title = currentDesc or ""
            end

            if nextAttrText then
                if currentStar >= maxStar then
                    nextAttrText.Title = "升星属性: 已满级"
                else
                    nextAttrText.Title = nextDesc or "升星属性: N/A"
                end
            end
        end

        self.attributeList:HideChildrenFrom(1)
        return
    end

    -- 否则显示常规携带效果
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
    if self.nameLabel then self.nameLabel.node.Title = "" end
    if self.petUI then self.petUI.node.Icon = "" end

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
    if self.deleteButton then self.deleteButton:SetVisible(false) end
    if self.lockButton then self.lockButton:SetVisible(false) end
end

-- =================================
-- 工具方法
-- =================================

--- 获取排序后的宠物列表
function PetGui:GetSortedPetList()
    -- 1. 将宠物数据从字典转为包含排序信息的数组
    local petList = {}
    for slotIndex, petInfo in pairs(self.petData) do
        -- 为每个宠物动态计算并添加 isEquipped 和 slotIndex 标志
        petInfo.isEquipped = self:IsPetEquipped(slotIndex)
        petInfo.slotIndex = slotIndex

        local config = self:GetPetConfig(petInfo.companionName)
        table.insert(petList, {
            info = petInfo,
            rarity = config and config.rarity or 0,
        })
    end

    -- 2. 按新的排序规则排序：1.装备 > 2.品质 > 3.星级
    table.sort(petList, function(a, b)
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
    ----gg.log("尝试默认选择第一个宠物")

    local sortedList = self:GetSortedPetList()

    if #sortedList > 0 then
        local firstPet = sortedList[1].info
        ----gg.log("默认选择宠物:", firstPet.companionName)
        self:OnPetSlotClick(firstPet.slotIndex, firstPet)
    else
        ----gg.log("没有宠物可供选择，清空详情")
        self.selectedPet = nil
        self:RefreshSelectedPetDisplay()
    end
end

return PetGui.New(script.Parent, uiConfig)
