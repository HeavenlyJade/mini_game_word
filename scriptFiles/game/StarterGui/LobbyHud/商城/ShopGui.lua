local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local MailEventConfig = require(MainStorage.Code.Event.EventMail) ---@type MailEventConfig
local PetEventConfig = require(MainStorage.Code.Event.EventPet) ---@type PetEventConfig

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "ShopGui",
    layer = -1,
    hideOnInit = false,
    closeHuds = false
}

---@class ShopGui:ViewBase
local ShopGui = ClassMgr.Class("ShopGui", ViewBase)

---@override
function ShopGui:OnInit(node, config)
    -- 基础节点获取

    -- 商城下的所有子节点
    self.onlineRewardsSection = self:Get("底图/商城/在线奖励", ViewButton) ---@type ViewButton
    self.vipSection = self:Get("底图/商城/特权会员", ViewButton) ---@type ViewButton
    self.shopSection = self:Get("底图/商城/商城", ViewButton) ---@type ViewButton
    self.rankingSection = self:Get("底图/商城/排行榜", ViewButton) ---@type ViewButton
    self.mailSection = self:Get("底图/商城/邮件", ViewButton) ---@type ViewButton

    -- 数据存储
    self.shopData = {} ---@type table 商城数据
    self.currentCategory = nil ---@type string 当前选中的分类
    self.selectedItem = nil ---@type table 当前选中的物品
    self.mailStatus = {
        hasUnclaimedMails = false  -- 是否有未领取邮件
    } ---@type table 邮件状态

    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()
    -- self:RequestMailList()

    --gg.log("ShopGui 商城界面初始化完成")
end

-- 注册事件监听
function ShopGui:RegisterEvents()
    -- 监听邮件列表响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.LIST_RESPONSE, function(data)
        self:HandleMailListResponse(data)
    end)
    
    -- 监听邮件领取响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.CLAIM_RESPONSE, function(data)
        self:HandleMailClaimResponse(data)
    end)
    
    -- 监听邮件删除响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.DELETE_RESPONSE, function(data)
        self:HandleMailDeleteResponse(data)
    end)
    
    -- 监听批量领取响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.BATCH_CLAIM_SUCCESS, function(data)
        self:HandleMailBatchClaimResponse(data)
    end)
    
    -- 监听删除已读邮件响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.DELETE_READ_SUCCESS, function(data)
        self:HandleMailDeleteReadResponse(data)
    end)
    
    --gg.log("注册商城系统事件监听")
end

-- 注册按钮事件
function ShopGui:RegisterButtonEvents()



    -- 在线奖励按钮
    self.onlineRewardsSection.clickCb = function()
        -- 先请求最强加成宠物名称
        self:RequestStrongestBonusPetName()
        
        local onlineRewardsGui = ViewBase["OnlineRewardsGui"]
        if onlineRewardsGui then
            onlineRewardsGui:Open()
            --gg.log("在线奖励按钮被点击")
        else
            --gg.log("错误：OnlineRewardsGui 界面未找到")
        end
    end

    -- 特权会员按钮
    self.vipSection.clickCb = function()
        local PrivilegedVIPGui = ViewBase["PrivilegedVIPGui"]
        if PrivilegedVIPGui then
            PrivilegedVIPGui:Open()
        end
        -- 打开特权会员界面
        --gg.log("特权会员按钮被点击")
        -- TODO: 实现特权会员界面
    end

    -- 商城按钮
    self.shopSection.clickCb = function()
        -- 打开商城购买界面
        local shopDetailGui = ViewBase["ShopDetailGui"]
        if shopDetailGui then
            shopDetailGui:Open()
            gg.log("商城按钮被点击, 打开ShopDetailGui")
        else
            gg.log("错误：ShopDetailGui 界面未找到")
        end
    end

    -- 排行榜按钮
    self.rankingSection.clickCb = function()
        -- 打开排行榜界面
        local RankingGui = ViewBase["RankingGui"]

        RankingGui:Open()
        
        gg.log("排行榜按钮被点击")
        -- TODO: 实现排行榜界面
    end

    -- 邮件按钮
    self.mailSection.clickCb = function()
        local mailGui = ViewBase["MailGui"]
        if mailGui then
            mailGui:Open()
            --gg.log("邮件按钮被点击")
        else
            --gg.log("错误：MailGui 界面未找到")
        end
    end

    --gg.log("商城界面按钮事件注册完成")
end

-- 处理邮件列表响应
function ShopGui:HandleMailListResponse(data)
    if not data then return end
    
    local hasUnclaimedMails = false
    
    -- 检查个人邮件
    if data.personal_mails then
        for _, mailInfo in pairs(data.personal_mails) do
            -- gg.log("检查个人邮件111", mailInfo.id, mailInfo.is_claimed)
            
            -- 检查是否未领取（不管是否有附件）
            local isClaimed = mailInfo.is_claimed == true
            if not isClaimed then  -- 未领取
                hasUnclaimedMails = true
            end
        end
    end
    -- 检查全服邮件
    if data.global_mails then
        for _, mailInfo in pairs(data.global_mails) do
            -- gg.log("检查全服邮件", mailInfo.id, mailInfo.is_claimed)
            
            -- 检查是否未领取（不管是否有附件）
            local isClaimed = mailInfo.is_claimed == true
            if not isClaimed then  -- 未领取
                hasUnclaimedMails = true
            end
        end
    end
    -- gg.log("检查邮件状态", hasUnclaimedMails)

    -- 更新邮件状态
    self.mailStatus.hasUnclaimedMails = hasUnclaimedMails
    
    -- 更新UI显示
    self:UpdateMailStatusDisplay()
end

-- 处理邮件领取响应
function ShopGui:HandleMailClaimResponse(data)
    if data and data.success then
        -- 领取成功后重新请求邮件列表以更新状态
        self:RequestMailList()
    end
end

-- 处理邮件删除响应
function ShopGui:HandleMailDeleteResponse(data)
    if data and data.success then
        -- 删除成功后重新请求邮件列表以更新状态
        self:RequestMailList()
    end
end

-- 处理批量领取响应
function ShopGui:HandleMailBatchClaimResponse(data)
    if data and data.success then
        -- 批量领取成功后重新请求邮件列表以更新状态
        self:RequestMailList()
    end
end

-- 处理删除已读邮件响应
function ShopGui:HandleMailDeleteReadResponse(data)
    if data and data.success then
        -- 删除已读邮件成功后重新请求邮件列表以更新状态
        self:RequestMailList()
    end
end

-- 请求邮件列表
function ShopGui:RequestMailList()
    gg.network_channel:FireServer({
        cmd = MailEventConfig.REQUEST.GET_LIST
    })
end

-- 请求最强加成宠物名称
function ShopGui:RequestStrongestBonusPetName()
    gg.network_channel:FireServer({
        cmd = PetEventConfig.REQUEST.GET_STRONGEST_BONUS_PET_NAME
    })
    --gg.log("ShopGui：已发送获取最强加成宠物名称请求")
end

-- 更新邮件状态显示
function ShopGui:UpdateMailStatusDisplay()
    local hasNewMail = self.mailStatus.hasUnclaimedMails
    
    if self.mailSection and self.mailSection.node then
        local newNode = self.mailSection.node["new"]
        if newNode then
            newNode.Visible = hasNewMail
            --gg.log("邮件状态更新 - 未领取:", self.mailStatus.hasUnclaimedMails, "显示new:", hasNewMail)
        else
            --gg.log("警告：找不到邮件按钮的new节点")
        end
    end
end

-- 打开界面时的操作
function ShopGui:OnOpen()
    -- 请求邮件列表以更新状态
    --gg.log("ShopGui商城界面打开")
end

-- 关闭界面时的操作
function ShopGui:OnClose()
    --gg.log("ShopGui商城界面关闭")
end

return ShopGui.New(script.Parent, uiConfig)
