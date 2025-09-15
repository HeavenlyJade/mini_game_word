local MainStorage = game:GetService("MainStorage")
local Players = game:GetService('Players')
local CoreUI = game:GetService("CoreUI")
local AdvertisementService = game:GetService("AdvertisementService")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.Code.Client.ClientScheduler)
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent

---@class Advertisement:ViewBase
local Advertisement = ClassMgr.Class("Advertisement", ViewBase)

local uiConfig = {
    uiName = "Advertisement",
    layer = 0,
    hideOnInit = true,
}

function Advertisement:RegisterEvents()
    -- 注册广告相关事件
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.AD_WATCH_COUNT_UPDATE, function(data)
        self:OnAdWatchCountUpdate(data)
    end)
end

function Advertisement:OnInit(node, config)
    -- 获取UI组件
    self.Adbackground = self:Get("广告底图", ViewComponent) ---@type ViewComponent
    self.AdwatchButton = self:Get("广告底图/观看广告", ViewButton) ---@type ViewButton
    self.AdcloseButton = self:Get("广告底图/关闭", ViewButton) ---@type ViewButton
    self.AdwatchCountDisplay = self:Get("广告底图/广告观看次数", ViewComponent) ---@type ViewComponent
    
    -- 初始化广告数据
    self.adData = {
        watchCount = 0,
        maxWatchesPerDay = 10 -- 每日最大观看次数
    }
    
    -- 设置按钮回调
    self:SetupButtonCallbacks()
    
    -- 注册事件
    self:RegisterEvents()
    
    -- 注册广告播放完成回调
    self:RegisterAdCallback()
end


-- 设置按钮回调函数
function Advertisement:SetupButtonCallbacks()
    -- 观看广告按钮
    if self.AdwatchButton then
        self.AdwatchButton.clickCb = function(ui, viewButton)
            self:OnWatchAdButtonClick()
            self:Close()
        end
    end
    
    -- 关闭广告界面按钮
    if self.AdcloseButton then
        self.AdcloseButton.clickCb = function(ui, viewButton)
            self:Close()
        end
    end
end

-- 注册广告播放完成回调
function Advertisement:RegisterAdCallback()
    local function onAdFinished(msg)
        gg.log("广告播放完成，回调消息:", msg)
        self:OnAdPlayFinished(msg)
    end
    
    AdvertisementService:PlayAdvertisingCallback(onAdFinished)
end


-- 观看广告按钮点击处理
function Advertisement:OnWatchAdButtonClick()
    -- 检查是否为手机端
    if not self:IsMobileDevice() then
        gg.log("广告播放仅支持手机端，当前设备不支持")
        -- 使用悬浮提示UI进行屏幕提醒
        ClientEventManager.Publish("SendHoverText", {
            txt = "广告播放仅支持手机端，当前设备不支持",
            duration = 2.5,
            fontSize = 28
        })
        return
    end
    
    -- 检查观看次数限制
    if self.adData.watchCount >= self.adData.maxWatchesPerDay then
        gg.log("今日广告观看次数已达上限，无法继续观看")
        self:ShowMaxWatchesReachedMessage()
        return
    end
    
    -- 获取本地玩家UIN
    local localPlayer = Players.LocalPlayer
    if not localPlayer then
        gg.log("无法获取本地玩家信息")
        return
    end
    
    -- 调用AdvertisementService播放广告
    gg.log("开始播放广告，玩家UIN:", localPlayer.UserId)
    AdvertisementService:PlayAdvertising(localPlayer.UserId, true)
end

-- 关闭按钮点击处理
function Advertisement:OnCloseButtonClick()
    self:Hide()
end

-- 检查是否为手机端设备
function Advertisement:IsMobileDevice()
    -- 使用RunService检查是否为手机端
    return game.RunService:IsMobile()
end

-- 显示仅手机端支持的提示消息
-- 广告播放完成回调处理
function Advertisement:OnAdPlayFinished(msg)
    gg.log("广告播放完成回调处理，消息:", msg)
    
    -- 通知服务端广告观看完成
    gg.network_channel:FireServer({
        cmd = EventPlayerConfig.REQUEST.AD_WATCH_COMPLETED,
        msg =msg,

    })
end

-- 处理广告观看次数更新
function Advertisement:OnAdWatchCountUpdate(data)
    if data and data.watchCount then
        self.adData.watchCount = data.watchCount
        gg.log("收到广告观看次数更新:", data.watchCount)
        self:UpdateWatchCountDisplay()
    end
end

-- 显示达到最大观看次数的提示消息
function Advertisement:ShowMaxWatchesReachedMessage()
    if self.AdwatchButton and self.AdwatchButton.node then
        self.AdwatchButton.node.Title = "今日已达上限"
        self.AdwatchButton.node.Enabled = false
        
        -- 3秒后恢复按钮状态
        ClientScheduler.add(function()
            if self.AdwatchButton and self.AdwatchButton.node then
                self.AdwatchButton.node.Title = "观看广告"
                self.AdwatchButton.node.Enabled = true
            end
        end, 3, 1)
    end
    
    gg.log("提示：今日广告观看次数已达上限（10次）")
end

-- 更新观看次数显示
function Advertisement:UpdateWatchCountDisplay()
    if self.AdwatchCountDisplay and self.AdwatchCountDisplay.node then
        local remaining = self.adData.maxWatchesPerDay - self.adData.watchCount
        self.AdwatchCountDisplay.node.Title = string.format("今日剩余: %d/%d", remaining, self.adData.maxWatchesPerDay)
    end
end


return Advertisement.New(script.Parent, uiConfig)
