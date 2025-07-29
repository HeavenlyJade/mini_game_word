local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

-- 模拟重生事件配置, 实际项目中应放在独立的事件文件中
local RebirthEventConfig = {
    REQUEST = {
        GET_REBIRTH_DATA = "Rebirth.GetRebirthData",
        PERFORM_REBIRTH = "Rebirth.PerformRebirth",
        PERFORM_MAX_REBIRTH = "Rebirth.PerformMaxRebirth",
        TOGGLE_AUTO_REBIRTH = "Rebirth.ToggleAutoRebirth",
    },
    RESPONSE = {
        REBIRTH_DATA = "Rebirth.Response.RebirthData",
        REBIRTH_SUCCESS = "Rebirth.Response.RebirthSuccess",
        ERROR = "Rebirth.Response.Error",
    },
    NOTIFY = {
        REBIRTH_DATA_UPDATE = "Rebirth.Notify.DataUpdate",
    },
}

local uiConfig = {
    uiName = "RebirthGui",
    layer = 3,
    hideOnInit = true,
    closeHuds = true,
}

---@class RebirthGui:ViewBase
local RebirthGui = ClassMgr.Class("RebirthGui", ViewBase)

---@override
function RebirthGui:OnInit(node, config)
    -- 1. 节点初始化
    self.rebirthMainPanel = self:Get("重生界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("重生界面/关闭", ViewButton) ---@type ViewButton

    -- 重生介绍与数值
    self.rebirthIntro = self:Get("重生界面/重生介绍", ViewComponent) ---@type ViewComponent
    self.rebirthStats = self:Get("重生界面/重生数值", ViewComponent) ---@type ViewComponent

    -- 重生历史记录列表
    self.rebirthHistoryList = self:Get("重生界面/重生栏位", ViewList) ---@type ViewList
    -- 模板节点需要根据实际UI编辑器中的命名来确定，这里假设它在"模版界面"下
    self.historyTemplate = self:Get("重生界面/模版界面/模版界面", ViewComponent) ---@type ViewComponent
    if self.historyTemplate and self.historyTemplate.node then
        self.historyTemplate.node.Visible = false
    end

    -- 主要重生按钮 (根据图片 "重生 +")
    self.rebirthButton = self:Get("重生界面/重生 +/重生", ViewButton) ---@type ViewButton
    self.rebirthCountText = self:Get("重生界面/重生 +/可重生次数", ViewComponent) ---@type ViewComponent
    self.rebirthCostText = self:Get("重生界面/重生 +/重生消耗", ViewComponent) ---@type ViewComponent

    -- 其他功能按钮
    self.maxRebirthButton = self:Get("重生界面/最大重生", ViewButton) ---@type ViewButton
    self.autoRebirthButton = self:Get("重生界面/自动重生", ViewButton) ---@type ViewButton

    -- 2. 数据存储
    self.rebirthData = nil ---@type table 服务端同步的重生数据
    self.autoRebirthEnabled = false ---@type boolean 自动重生状态

    -- 3. 事件注册
    self:RegisterEvents()
    self:RegisterButtonEvents()

    gg.log("RebirthGui 初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function RebirthGui:RegisterEvents()
    gg.log("注册重生系统事件监听")
    
    ClientEventManager.Subscribe(RebirthEventConfig.RESPONSE.REBIRTH_DATA, function(data)
        self:OnRebirthDataResponse(data)
    end)

    ClientEventManager.Subscribe(RebirthEventConfig.NOTIFY.REBIRTH_DATA_UPDATE, function(data)
        self:OnRebirthDataUpdate(data)
    end)

    ClientEventManager.Subscribe(RebirthEventConfig.RESPONSE.ERROR, function(data)
        gg.log("重生系统错误: " .. (data.errorMessage or "未知错误"))
        -- TODO: 向玩家显示错误提示
    end)
end

function RebirthGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function()
        self:Close()
    end
    
    -- 重生按钮
    self.rebirthButton.clickCb = function()
        self:OnClickRebirth()
    end
    
    -- 最大重生按钮
    self.maxRebirthButton.clickCb = function()
        self:OnClickMaxRebirth()
    end

    -- 自动重生切换
    self.autoRebirthButton.clickCb = function()
        self:OnClickAutoRebirth()
    end

    gg.log("重生界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

---@override
function RebirthGui:OnOpen()
    gg.log("RebirthGui打开，请求最新重生数据")
    self:RequestRebirthData()
end

---@override
function RebirthGui:OnClose()
    gg.log("RebirthGui关闭")
    -- 可选：清理临时数据
    self.rebirthData = nil
end

-- =================================
-- 数据请求与响应
-- =================================

function RebirthGui:RequestRebirthData()
    gg.log("请求重生数据")
    gg.network_channel:fireServer({ cmd = RebirthEventConfig.REQUEST.GET_REBIRTH_DATA, args = {} })
end

function RebirthGui:OnRebirthDataResponse(data)
    gg.log("收到重生数据响应:", data)
    if not data then return end
    self.rebirthData = data
    self.autoRebirthEnabled = data.isAutoRebirthEnabled or false
    self:RefreshAllDisplay()
end

function RebirthGui:OnRebirthDataUpdate(data)
    gg.log("收到重生数据更新通知:", data)
    if not data then return end
    self.rebirthData = data
    self.autoRebirthEnabled = data.isAutoRebirthEnabled or false
    self:RefreshAllDisplay()
end

-- =================================
-- 按钮操作处理
-- =================================

function RebirthGui:OnClickRebirth()
    gg.log("点击重生按钮")
    if not self.rebirthData or not self.rebirthData.canRebirth then
        gg.log("不满足重生条件，无法重生")
        -- TODO: 显示提示给玩家
        return
    end
    gg.network_channel:fireServer({ cmd = RebirthEventConfig.REQUEST.PERFORM_REBIRTH, args = {} })
end

function RebirthGui:OnClickMaxRebirth()
    gg.log("点击最大重生按钮")
    if not self.rebirthData or not self.rebirthData.canRebirth then
        gg.log("不满足重生条件，无法最大重生")
        -- TODO: 显示提示给玩家
        return
    end
    gg.network_channel:fireServer({ cmd = RebirthEventConfig.REQUEST.PERFORM_MAX_REBIRTH, args = {} })
end

function RebirthGui:OnClickAutoRebirth()
    gg.log("点击自动重生切换按钮")
    self.autoRebirthEnabled = not self.autoRebirthEnabled
    gg.log("自动重生状态切换为:", self.autoRebirthEnabled)

    gg.network_channel:fireServer({
        cmd = RebirthEventConfig.REQUEST.TOGGLE_AUTO_REBIRTH,
        args = { enable = self.autoRebirthEnabled }
    })
end

-- =================================
-- UI刷新方法
-- =================================

function RebirthGui:RefreshAllDisplay()
    gg.log("刷新整个重生界面")
    if not self.rebirthData then
        gg.log("无重生数据，隐藏界面内容")
        -- 可能需要隐藏主要面板或显示加载状态
        return
    end

    self:RefreshRebirthInfo()
    self:RefreshRebirthButtons()
    self:RefreshHistoryList()
end

--- 更新重生信息显示
function RebirthGui:RefreshRebirthInfo()
    if not self.rebirthData then return end
    
    -- 更新重生次数和消耗
    if self.rebirthCountText and self.rebirthCountText.node then
        self.rebirthCountText.node.Title = "可重生 " .. (self.rebirthData.rebirthCount or 0) .. " 次"
    end
    if self.rebirthCostText and self.rebirthCostText.node then
        self.rebirthCostText.node.Title = "消耗: " .. (self.rebirthData.costDescription or "N/A")
    end

    -- 更新重生统计数值
    if self.rebirthStats and self.rebirthStats.node then
        -- 假设重生数值是一个文本节点，内容由服务端提供
        self.rebirthStats.node.Title = self.rebirthData.statsText or ""
    end
end

--- 更新所有按钮的状态
function RebirthGui:RefreshRebirthButtons()
    if not self.rebirthData then return end
    
    local canRebirth = self.rebirthData.canRebirth or false
    
    self.rebirthButton:SetTouchEnable(canRebirth)
    self.rebirthButton:SetGray(not canRebirth)
    
    self.maxRebirthButton:SetTouchEnable(canRebirth)
    self.maxRebirthButton:SetGray(not canRebirth)

end

--- 刷新自动重生按钮状态

--- 刷新重生历史记录
function RebirthGui:RefreshHistoryList()
    if not self.rebirthHistoryList or not self.rebirthData or not self.rebirthData.history then
        return
    end

    self.rebirthHistoryList:ClearChildren()
    
    if not self.historyTemplate or not self.historyTemplate.node then
        gg.log("找不到重生历史模板")
        return
    end

    for i, historyEntry in ipairs(self.rebirthData.history) do
        local itemNode = self.historyTemplate.node:Clone()
        itemNode.Visible = true
        
        -- 假设模板的根节点可以直接设置文本，或者需要查找子节点
        -- 这里假设模板根节点就是文本项
        itemNode.Title = string.format("第 %d 次重生: %s", i, historyEntry.description)
        
        self.rebirthHistoryList:AppendChild(itemNode)
    end
end

return RebirthGui.New(script.Parent, uiConfig)