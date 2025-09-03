-- PrivilegedVIPGui.lua
-- 特权VIP界面逻辑

local MainStorage = game:GetService("MainStorage")

-- 引入核心模块
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

-- 引入UI基类和组件
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon

-- 引入事件系统
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local ShopEventConfig = require(MainStorage.Code.Event.EventShop) ---@type ShopEventConfig
local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig

-- UI配置
local uiConfig = {
    uiName = "RechargeRebateGui",
    layer = 3,
    hideOnInit = true,
}

---@class RechargeRebateGui : ViewBase
local RechargeRebateGui = ClassMgr.Class("RechargeRebateGui", ViewBase)

---@override
function RechargeRebateGui:OnInit(node, config)
    -- 1. 节点初始化
    self:InitNodes()
    
    -- 2. 数据存储
    self:InitData()
    
    -- -- 3. 事件注册
    -- self:RegisterEvents()
    
    -- -- 4. 按钮点击事件注册
    self:RegisterButtonEvents()
    
    
    ----gg.log("RechargeRebateGui 累计充值界面初始化完成")
end

-- 节点初始化
function RechargeRebateGui:InitNodes()
    -- 主界面
    self.rechargePanel = self:Get("返利界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("返利界面/关闭", ViewButton) ---@type ViewButton
    
    -- 临取列表区域
    self.rewardList = self:Get("返利界面/领取列表", ViewList) ---@type ViewList
    
    -- 模板界面区域
    self.templatePanel = self:Get("返利界面/模板界面", ViewComponent) ---@type ViewComponent
    self.templateReward = self:Get("返利界面/模板界面/临取界面", ViewComponent) ---@type ViewComponent
    
    
    -- 界面描述区域
    self.descriptionPanel = self:Get("返利界面/界面描述", ViewComponent) ---@type ViewComponent
    self.spendingAmount = self:Get("返利界面/界面描述/消费金额", ViewComponent) ---@type ViewComponent
    self.preDescription = self:Get("返利界面/界面描述/前置描述", ViewComponent) ---@type ViewComponent
    
    -- 黑色底图
    self.blackBg = self:Get("黑色底图", ViewComponent) ---@type ViewComponent
    self.templatePanel:SetVisible(false)
    self.rewardList:SetVisible(true)
end

-- 数据初始化
function RechargeRebateGui:InitData()
    -- 从配置中获取"累计充值"的奖励配置
    self.rewardBonusConfig = ConfigLoader.GetRewardBonus("累计充值") ---@type RewardBonusType
    
    if not self.rewardBonusConfig then
        --gg.log("错误：找不到'累计充值'的奖励配置")
        return
    end
    
    -- 获取奖励等级列表
    local rewardTierList = self.rewardBonusConfig:GetRewardTierList()
    
    -- 循环处理每个奖励等级
    for i, rewardTier in ipairs(rewardTierList) do
        -- 克隆模板节点
        local clonedReward = self.templateReward.node:Clone()
        clonedReward.Name = "奖励等级_" .. i
        local description =  clonedReward["描述"]
        local processBar =  clonedReward["进度条"]
        processBar.FillAmount = 0


        local rewardItemList = ViewList.New(clonedReward["物品栏"], self, "奖励等级_" .. i .. "", function(child)
            return ViewComponent.New(child, self, "奖励等级_" .. i .. "/物品栏/" .. child.Name)
        end)

        rewardItemList:SetElementSize(#rewardTier.RewardItemList)
        for j, rewardItem in ipairs(rewardTier.RewardItemList) do
             
            local rewardItemNode = rewardItemList:GetChild(j)
            --gg.log("奖励物品：" .. j,rewardItemNode.node)
            local rewardItemIcon = rewardItemNode.node["图标"]
            local rewardItemAmount = rewardItemNode.node["数量"]
             
             -- 根据奖励类型获取对应的图标资源
            local iconResource = self:GetRewardItemIcon(rewardItem)
            rewardItemIcon.Icon = iconResource or ""
            rewardItemAmount.Title = "x" .. gg.FormatLargeNumber(rewardItem.Quantity)
         end
        -- 使用 ViewList 的 AppendChild 功能添加到 rewardList
        --gg.log("奖励等级_" .. i .. "",clonedReward["领取"])
        local claimButton = ViewButton.New(clonedReward["领取"], self, "奖励等级_" .. i .. "")

        claimButton:SetGray(true)
        claimButton:SetTouchEnable(false, nil)
        claimButton.clickCb = function()
            self:OnRewardSlotClick(i, rewardTier)
        end
        self.rewardList:AppendChild(clonedReward)

    end
    
    --gg.log(string.format("累计充值奖励配置加载完成，共 %d 个奖励等级", #rewardTierList))
end

-- 注册按钮事件
function RechargeRebateGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
    end
end

-- 根据奖励类型获取对应的图标资源
function RechargeRebateGui:GetRewardItemIcon(rewardItem)
    if not rewardItem then
        return ""
    end
    
    if rewardItem.RewardType == "物品" and rewardItem.Item then
        -- 获取物品配置
        local itemConfig = ConfigLoader.GetItem(rewardItem.Item)
        if itemConfig and itemConfig.icon then
            return itemConfig.icon
        end
    elseif rewardItem.RewardType == "宠物" and rewardItem.PetConfig then
        -- 获取宠物配置
        local petConfig = ConfigLoader.GetPet(rewardItem.PetConfig)
        if petConfig and petConfig.avatarResource then
            return petConfig.avatarResource
        end
    elseif rewardItem.RewardType == "伙伴" and rewardItem.PartnerConfig then
        -- 获取伙伴配置
        local partnerConfig = ConfigLoader.GetPartner(rewardItem.PartnerConfig)
        if partnerConfig and partnerConfig.avatarResource then
            return partnerConfig.avatarResource
        end
    elseif rewardItem.RewardType == "翅膀" and rewardItem.WingConfig then
        -- 获取翅膀配置
        local wingConfig = ConfigLoader.GetWing(rewardItem.WingConfig)
        if wingConfig and wingConfig.avatarResource then
            return wingConfig.avatarResource
        end
    elseif rewardItem.RewardType == "尾迹" and rewardItem.TrailConfig then
        -- 获取尾迹配置
        local trailConfig = ConfigLoader.GetTrail(rewardItem.TrailConfig)
        if trailConfig and trailConfig.avatarResource then
            return trailConfig.avatarResource
        end
    end
    
    -- 如果都没有找到，返回空字符串
    return ""
end

-- 奖励槽位点击事件
function RechargeRebateGui:OnRewardSlotClick(index, rewardTier)
    --gg.log(string.format("点击奖励槽位 %d，消耗迷你币：%d", index, rewardTier.CostMiniCoin))
    -- TODO: 实现奖励领取逻辑
end

return RechargeRebateGui.New(script.Parent, uiConfig)
