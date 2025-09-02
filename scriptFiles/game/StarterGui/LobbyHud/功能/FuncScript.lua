local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class FuncScript:ViewBase
local FuncScript = ClassMgr.Class("FuncScript", ViewBase)

local uiConfig = {
    uiName = "FuncScript",
    layer = -1,
    hideOnInit = false,
    closeHuds = false
}

---@override 
function FuncScript:OnInit(node, config)
    
    -- 获取主要UI节点
    self.backgroundPanel = self:Get("底图", ViewComponent) ---@type ViewComponent
    
    -- 获取功能按钮组（假设为图片按钮样式）
    self.autoPlay = self:Get("底图/自动挂机", ViewButton) ---@type ViewButton
    self.autoUpgrade = self:Get("底图/自动比赛", ViewButton) ---@type ViewButton  、
    self.stopAutoPlay = self:Get("底图/停止自动挂机", ViewButton) ---@type ViewButton
    self.stopAutoUpgrade = self:Get("底图/停止自动比赛", ViewButton) ---@type ViewButton
    self.stopAutoPlay:SetVisible(false)
    self.stopAutoUpgrade:SetVisible(false)
    self.bossKiller = self:Get("底图/脱离卡死", ViewButton) ---@type ViewButton
    
    -- 注册按钮事件
    self:RegisterButtonEvents()
    -- 注册网络事件
    self:RegisterNetworkEvents()
end



-- 注册按钮点击事件
function FuncScript:RegisterButtonEvents()
    -- 自动挂机功能
    self.autoPlay.clickCb = function(ui, button)
        self:HandleAutoPlay()
    end

    -- 自动比赛功能
    self.autoUpgrade.clickCb = function(ui, button)
        self:HandleAutoRace()
    end
    
    -- 停止自动比赛功能
    self.stopAutoUpgrade.clickCb = function(ui, button)
        self:HandleStopAutoRace()
    end
    
    -- 停止自动挂机功能
    self.stopAutoPlay.clickCb = function(ui, button)
        self:HandleStopAutoPlay()
    end
    
    self.bossKiller.clickCb = function(ui, button)
        self:HandleUnstuck()
    end
    
    -- 初始化按钮显示状态
    self:UpdateAutoRaceButtonDisplay()
    self:UpdateAutoPlayButtonDisplay()
end

--- 【新增】注册网络事件
function FuncScript:RegisterNetworkEvents()
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.AUTO_RACE_STOPPED, function(data)
        gg.log("接收到停止自动比赛通知: " .. (data and data.reason or "无原因"))
        self.autoRaceState = false
        self:UpdateAutoRaceButtonDisplay()
    end)
    
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.LEAVE_IDLE_SUCCESS, function(data)
        gg.log("接收到离开挂机成功通知")
        self.autoPlayState = false
        self:UpdateAutoPlayButtonDisplay()
            
        
    end)
end

-- 自动挂机功能处理
function FuncScript:HandleAutoPlay()
    gg.log("触发自动挂机功能")
    
    
    -- 发送自动挂机请求到服务端
    gg.network_channel:FireServer({
        cmd = EventPlayerConfig.REQUEST.AUTO_PLAY_TOGGLE,
        enabled = true
    })
    
    -- 更新按钮显示状态
    self:UpdateAutoPlayButtonDisplay()
    
    -- 显示状态提示

end

-- 自动比赛功能处理
function FuncScript:HandleAutoRace()
    gg.log("触发自动比赛功能")
    
    -- 更新本地状态
    self.autoRaceState = true
    
    -- 如果启动自动比赛，先停止自动挂机
    if self.autoRaceState and self.autoPlayState then
        self.autoPlayState = false
        self:HandleStopAutoPlay(true) -- 调用停止函数，并传递一个标志以避免重复发送请求
    end
    
    -- 发送自动比赛请求到服务端
    gg.network_channel:FireServer({
        cmd = EventPlayerConfig.REQUEST.AUTO_RACE_TOGGLE,
        uin = gg.get_client_uin(),
        enabled = true
    })
    
    -- 更新按钮显示状态
    self:UpdateAutoRaceButtonDisplay()
end

-- 停止自动比赛功能处理
function FuncScript:HandleStopAutoRace(isInternalCall)
    gg.log("触发停止自动比赛功能")
    
    -- 更新本地状态
    self.autoRaceState = false
    
    if not isInternalCall then
        -- 发送停止自动比赛请求到服务端
        gg.network_channel:FireServer({
            cmd = EventPlayerConfig.REQUEST.AUTO_RACE_TOGGLE,
            uin = gg.get_client_uin(),
            enabled = false
        })
    end
    
    -- 更新按钮显示状态
    self:UpdateAutoRaceButtonDisplay()
end

-- 停止自动挂机功能处理
function FuncScript:HandleStopAutoPlay(isInternalCall)
    gg.log("触发停止自动挂机功能")
    
    -- 更新本地状态
    self.autoPlayState = false
    
    if not isInternalCall then
        -- 发送停止自动挂机请求到服务端
        gg.network_channel:FireServer({
            cmd = EventPlayerConfig.REQUEST.AUTO_PLAY_TOGGLE,
            enabled = false
        })
    end
    
    -- 更新按钮显示状态
    self:UpdateAutoPlayButtonDisplay()
end

-- 更新自动比赛按钮显示状态
function FuncScript:UpdateAutoRaceButtonDisplay()
    if self.autoRaceState then
        -- 自动比赛开启状态：隐藏自动比赛按钮，显示停止按钮
        self.autoUpgrade:SetVisible(false)
        self.stopAutoUpgrade:SetVisible(true)     
    else
        self.autoUpgrade:SetVisible(true)
        self.stopAutoUpgrade:SetVisible(false)
        
    end
end

-- 更新自动挂机按钮显示状态
function FuncScript:UpdateAutoPlayButtonDisplay()
    if self.autoPlayState then
        -- 自动挂机开启状态：隐藏自动挂机按钮，显示停止按钮
        self.autoPlay:SetVisible(false)
        self.stopAutoPlay:SetVisible(true)     
    else
        self.autoPlay:SetVisible(true)
        self.stopAutoPlay:SetVisible(false)
        
    end
end

-- 脱离卡死功能处理
function FuncScript:HandleUnstuck()
    gg.log("触发脱离卡死功能")
    
    -- 发送脱离卡死请求到服务端
    gg.network_channel:FireServer({
        cmd = EventPlayerConfig.REQUEST.UNSTUCK_PLAYER
    })
    
    -- 显示提示信息
    gg.log("已发送脱离卡死请求")
end

-- 功能列表项点击处理



return FuncScript.New(script.Parent, uiConfig)