local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "RebirthGui",
    layer = 3,
    hideOnInit = true,
    closeHuds = true,  -- 改为true，正确管理layer=0界面
}

---@class RebirthGui:ViewBase
local RebirthGui = ClassMgr.Class("RebirthGui", ViewBase)

---@override
function RebirthGui:OnInit(node, config)
    -- UI组件初始化 - 所有组件都在"重生界面"节点下
    self.rebirthMainPanel = self:Get("重生界面", ViewComponent) ---@type ViewComponent

    self.closeButton = self:Get("重生界面/关闭", ViewButton) ---@type ViewButton
    self.rebirthIntro = self:Get("重生界面/重生介绍", ViewComponent) ---@type ViewComponent
    self.rebirthStats = self:Get("重生界面/重生数值", ViewComponent) ---@type ViewComponent
    
    -- 重生栏位相关组件
    self.rebirthLevelList = self:Get("重生界面/重生栏位", ViewList) ---@type ViewList
    self.maxRebirthSection = self:Get("重生界面/重生栏位/最大重生", ViewComponent) ---@type ViewComponent
    self.maxRebirthDisplay = self:Get("重生界面/重生栏位/最大重生/最大重生", ViewComponent) ---@type ViewComponent
    self.maxRebirthValues = self:Get("重生界面/重生栏位/最大重生/可重生次数", ViewComponent) ---@type ViewComponent
    self.maxRebirthTips = self:Get("重生界面/重生栏位/最大重生/重生消耗", ViewComponent) ---@type ViewComponent
    
    -- 重生操作按钮
    self.rebirthSection = self:Get("重生界面/重生栏位/重生", ViewComponent) ---@type ViewComponent
    self.rebirthButton = self:Get("重生界面/重生栏位/重生/重生", ViewButton) ---@type ViewButton
    self.rebirthCost = self:Get("重生界面/重生栏位/重生/可重生次数", ViewComponent) ---@type ViewComponent
    self.rebirthConsume = self:Get("重生界面/重生栏位/重生/重生消耗", ViewComponent) ---@type ViewComponent
    
    -- 自动重生功能
    self.autoRebirthSection = self:Get("重生界面/重生栏位/自动重生", ViewComponent) ---@type ViewComponent
    self.autoRebirthToggle = self:Get("重生界面/重生栏位/自动重生/迷你币", ViewButton) ---@type ViewButton
    self.autoRebirthStatus = self:Get("重生界面/重生栏位/自动重生/需求迷你币", ViewComponent) ---@type ViewComponent

    -- 数据存储
    self.rebirthCount = 0 ---@type number 当前重生次数
    self.rebirthRequirement = {} ---@type table 重生条件
    self.autoRebirthEnabled = false ---@type boolean 自动重生状态
    self.miniCoinCost = 0 ---@type number 自动重生所需迷你币数量
    self.rebirthHistoryData = {} ---@type table 重生历史数据

    -- 为重生栏位UIList设置回调
    local function createRebirthHistoryItem(itemNode)
        local component = ViewComponent.New(itemNode, self)
        return component
    end
    self.rebirthLevelList.onAddElementCb = createRebirthHistoryItem

    -- 初始化UI状态
    self:InitializeRebirthUI()

    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()

    gg.log("RebirthGui 初始化完成")
end

-- 初始化重生界面
function RebirthGui:InitializeRebirthUI()
    gg.log("初始化重生界面UI状态")
    
    -- 设置初始显示状态
    self:UpdateRebirthDisplay()
    self:UpdateAutoRebirthStatus()
    
    -- 隐藏暂时不用的组件
    -- 如果有需要隐藏的组件，在这里设置
end

-- 注册事件监听
function RebirthGui:RegisterEvents()
    gg.log("注册重生系统事件监听")
    
    -- 这里后续添加与服务端的事件通信
    -- 例如：重生成功/失败响应、数据更新通知等
end

-- 注册按钮事件
function RebirthGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function()
        self:Close()
        gg.log("重生界面已关闭")
    end
    
    -- 重生按钮
    self.rebirthButton.clickCb = function()
        self:OnRebirthButtonClick()
    end
    
    -- 迷你币自动重生切换
    self.autoRebirthToggle.clickCb = function()
        self:OnAutoRebirthToggle()
    end

    gg.log("重生界面按钮事件注册完成")
end

-- 更新重生显示
function RebirthGui:UpdateRebirthDisplay()
    gg.log("更新重生显示数据")
    
    -- 更新重生次数显示
    -- 更新重生条件和消耗显示
    -- 更新按钮状态
    
    -- 后续在这里实现具体的UI更新逻辑
end

-- 更新自动重生状态显示
function RebirthGui:UpdateAutoRebirthStatus()
    gg.log("更新自动重生状态显示")
    
    -- 更新迷你币需求显示
    -- 更新自动重生按钮状态
    
    -- 后续在这里实现具体的状态更新逻辑
end

-- 处理重生按钮点击
function RebirthGui:OnRebirthButtonClick()
    gg.log("重生按钮被点击")
    
    if self:CheckRebirthRequirements() then
        self:ExecuteRebirth()
    else
        gg.log("重生条件不足")
    end
end

-- 处理迷你币自动重生切换
function RebirthGui:OnAutoRebirthToggle()
    gg.log("自动重生开关被点击")
    
    if self:CheckMiniCoinRequirement() then
        self.autoRebirthEnabled = not self.autoRebirthEnabled
        self:UpdateAutoRebirthStatus()
        gg.log("迷你币自动重生状态:", self.autoRebirthEnabled and "开启" or "关闭")
    else
        gg.log("迷你币不足，无法开启自动重生")
    end
end

-- 检查重生条件
function RebirthGui:CheckRebirthRequirements()
    gg.log("检查重生条件")
    
    -- 后续实现具体的重生条件检查逻辑
    -- 例如：等级、金币、经验等条件
    return true -- 临时返回true
end

-- 检查迷你币需求
function RebirthGui:CheckMiniCoinRequirement()
    gg.log("检查迷你币需求")
    
    -- 后续实现具体的迷你币检查逻辑
    return true -- 临时返回true
end

-- 执行重生操作
function RebirthGui:ExecuteRebirth()
    gg.log("执行重生操作")
    
    -- 后续实现具体的重生逻辑
    -- 发送重生请求到服务端
    -- 处理重生结果
end

-- 打开界面时的操作
function RebirthGui:OnOpen()
    gg.log("RebirthGui打开，刷新重生数据")
    
    -- 请求最新的重生数据
    -- 更新界面显示
    self:UpdateRebirthDisplay()
end

-- 关闭界面时的操作
function RebirthGui:OnClose()
    gg.log("RebirthGui关闭")
    
    -- 清理临时数据或状态
end

return RebirthGui.New(script.Parent, uiConfig)