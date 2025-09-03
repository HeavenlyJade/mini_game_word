local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "WelfareGui",
    layer = -1,
    hideOnInit = false,
    closeHuds = false
}

---@class WelfareGui:ViewBase
local WelfareGui = ClassMgr.Class("WelfareGui", ViewBase)

---@override
function WelfareGui:OnInit(node, config)
    -- 基础节点获取

    -- 商城下的所有子节点
 
    self.rechargeRebateSection = self:Get("底图/福利/返利", ViewButton) ---@type ViewButton
    self.monthlyCard = self:Get("底图/福利/月卡", ViewButton) ---@type ViewButton
    self.BaseImage = self:Get("底图", ViewComponent) ---@type ViewComponent
    self.BaseImage:SetVisible(false)
    -- 注册事件
    -- self:RegisterEvents()
    self:RegisterButtonEvents()

    --gg.log("ShopGui 商城界面初始化完成")
end


-- 注册按钮事件
function WelfareGui:RegisterButtonEvents()



    
    self.rechargeRebateSection.clickCb = function()
        local onlineRewardsGui = ViewBase["RechargeRebateGui"]
        onlineRewardsGui:Open()

    end

    self.monthlyCard.clickCb = function()
        local PrivilegedVIPGui = ViewBase["PrivilegedVIPGui"]
        if PrivilegedVIPGui then
            PrivilegedVIPGui:Open()
        end
        -- 打开特权会员界面
        --gg.log("特权会员按钮被点击")
        -- TODO: 实现特权会员界面
    end
end

return WelfareGui.New(script.Parent, uiConfig)
