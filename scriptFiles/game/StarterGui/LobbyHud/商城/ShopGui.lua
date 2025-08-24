local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager

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

    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()

    --gg.log("ShopGui 商城界面初始化完成")
end

-- 注册事件监听
function ShopGui:RegisterEvents()
    --gg.log("注册商城系统事件监听")
end

-- 注册按钮事件
function ShopGui:RegisterButtonEvents()



    -- 在线奖励按钮
    self.onlineRewardsSection.clickCb = function()
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
        --gg.log("排行榜按钮被点击")
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

-- 打开界面时的操作
function ShopGui:OnOpen()
    --gg.log("ShopGui商城界面打开")
end

-- 关闭界面时的操作
function ShopGui:OnClose()
    --gg.log("ShopGui商城界面关闭")
end

return ShopGui.New(script.Parent, uiConfig)
