local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

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
    gg.log("FuncScript 功能模块初始化")
    
    -- 获取主要UI节点
    self.backgroundPanel = self:Get("底图", ViewComponent) ---@type ViewComponent
    
    -- 获取功能按钮组（假设为图片按钮样式）
    self.autoPlay = self:Get("底图/功能/自动挂机", ViewButton) ---@type ViewButton
    self.autoUpgrade = self:Get("底图/功能/自动比赛", ViewButton) ---@type ViewButton  
    self.bossKiller = self:Get("底图/功能/脱离卡死", ViewButton) ---@type ViewButton
    
    -- 注册按钮事件
    self:RegisterButtonEvents()

end



-- 注册按钮点击事件
function FuncScript:RegisterButtonEvents()
    -- 自动挂机功能

    self.autoPlay.clickCb = function(ui, button)
        self:HandleAutoPlay()
    end

    self.autoUpgrade.clickCb = function(ui, button)
        self:HandleAutoRace()
    end
    self.bossKiller.clickCb = function(ui, button)
        self:HandleUnstuck()
    end
    
end

-- 自动挂机功能处理
function FuncScript:HandleAutoPlay()
    gg.log("触发自动挂机功能")
    
    -- 发送自动挂机请求到服务端
    gg.network_channel:FireServer({
        cmd = "AutoPlayToggle",
        enabled = not (self.autoPlayState or false)
    })
    
    -- 更新本地状态
    self.autoPlayState = not (self.autoPlayState or false)
    
    -- 更新按钮显示状态
    if self.autoPlay then
        self.autoPlay.Title = self.autoPlayState and "关闭挂机" or "自动挂机"
    end
end

-- 自动比赛功能处理
function FuncScript:HandleAutoRace()
    gg.log("触发自动比赛功能")
    
    -- 更新本地状态
    self.autoRaceState = not (self.autoRaceState or false)
    
    -- 发送自动比赛请求到服务端
    gg.network_channel:FireServer({
        cmd = "AutoRaceToggle",
        uin = gg.get_client_uin(),
        enabled = self.autoRaceState
    })
    
    -- 更新按钮显示状态
    if self.autoUpgrade then
        self.autoUpgrade.Title = self.autoRaceState and "关闭比赛" or "自动比赛"
    end
end

-- 脱离卡死功能处理
function FuncScript:HandleUnstuck()
    gg.log("触发脱离卡死功能")
    
    -- 发送脱离卡死请求到服务端
    gg.network_channel:FireServer({
        cmd = "UnstuckPlayer"
    })
    
    -- 显示提示信息
    gg.log("已发送脱离卡死请求")
end

-- 功能列表项点击处理



return FuncScript.New(script.Parent, uiConfig)