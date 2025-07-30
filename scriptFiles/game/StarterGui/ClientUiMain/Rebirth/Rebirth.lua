-- RebirthGui.lua - 重构版
-- 该界面现在作为'重生'天赋动作的触发器

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local TALENT_ID = "重生" -- 定义此界面关联的核心天赋ID

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
    self.closeButton = self:Get("重生界面/关闭", ViewButton) ---@type ViewButton
    self.rebirthList = self:Get("重生界面/重生栏位", ViewList) ---@type ViewList
    self.maxRebirthButton = self:Get("重生界面/重生栏位/最大重生/最大重生", ViewButton) ---@type ViewButton
    
    -- "最大重生"节点的子控件
    self.maxRebirthCountText = self:Get("重生界面/重生栏位/最大重生/可重生次数") ---@type UITextLabel
    self.maxRebirthCostText = self:Get("重生界面/重生栏位/最大重生/重生消耗") ---@type UITextLabel
    
    -- 模板节点
    self.rebirthTemplate = self:Get("重生界面/模版界面/重生", ViewComponent) ---@type ViewComponent
    if self.rebirthTemplate and self.rebirthTemplate.node then
        self.rebirthTemplate.node.Visible = false
    end

    -- 2. 数据存储
    self.currentTalentLevel = 0 -- 当前重生天赋等级
    self.costsByLevel = {} -- 存储每个等级的消耗

    -- 3. 事件注册
    self:RegisterEvents()
    self:RegisterButtonEvents()

    gg.log("RebirthGui 初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function RebirthGui:RegisterEvents()
    gg.log("注册重生UI事件监听")
    
    -- 监听重生天赋等级数据
    ClientEventManager.Subscribe(AchievementEventConfig.RESPONSE.GET_REBIRTH_LEVEL_RESPONSE, function(data)
        self:OnTalentLevelResponse(data)
    end)
    
    -- 监听天赋动作执行结果
    ClientEventManager.Subscribe(AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, function(data)
        self:OnPerformActionResponse(data)
    end)
end

function RebirthGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        self:Close()
    end

    self.maxRebirthButton.clickCb = function()
        self:OnClickMaxRebirth()
    end
end

-- =================================
-- 界面生命周期
-- =================================

---@override
function RebirthGui:OnOpen()
    gg.log("RebirthGui打开")
    -- 数据请求现在由仓库按钮发起，界面只负责监听和刷新
end

---@override
function RebirthGui:OnClose()
    gg.log("RebirthGui关闭")
    self.currentTalentLevel = 0
    self.rebirthList:ClearChildren({ "最大重生" })
end

-- =================================
-- 数据请求与响应
-- =================================

function RebirthGui:RequestTalentLevel()
    gg.log("请求天赋等级:", TALENT_ID)
    gg.network_channel:fireServer({
        cmd = AchievementEventConfig.REQUEST.GET_TALENT_LEVEL,
        args = { talentId = TALENT_ID }
    })
end

function RebirthGui:OnTalentLevelResponse(data)
    gg.log("收到天赋等级响应:", data)
    self.currentTalentLevel = data.data.currentLevel
    self.costsByLevel = data.data.costsByLevel or {}
    self.maxExecutions = data.data.maxExecutions or 0
    self.maxExecutionTotalCost = data.data.maxExecutionTotalCost or 0
    self.playerResources = data.data.playerResources or {} -- 新增：存储玩家资源

    self:RefreshDisplay()
end

function RebirthGui:OnPerformActionResponse(data)
    gg.log("收到天赋动作执行响应:", data)
    if data.success then
        gg.log("重生成功！等级:", data.executedLevel, "效果:", data.effectApplied)
        -- 重生成功后，再次请求最新的天赋等级来刷新界面
        self:RequestTalentLevel()
    else
        gg.log("重生失败:", AchievementEventConfig.GetErrorMessage(data.errorCode))
        -- TODO: 向玩家显示错误提示
    end
end

-- =================================
-- 按钮操作处理
-- =================================

---@param level number
function RebirthGui:OnClickRebirthLevel(level)
    gg.log(string.format("点击重生等级 %d 按钮", level))
    
    -- 发送执行天赋动作的请求
    gg.network_channel:fireServer({
        cmd = AchievementEventConfig.REQUEST.PERFORM_TALENT_ACTION,
        args = {
            talentId = TALENT_ID,
            targetLevel = level
        }
    })
end

function RebirthGui:OnClickMaxRebirth()
    gg.log("点击最大重生按钮")
    
    gg.network_channel:fireServer({
        cmd = AchievementEventConfig.REQUEST.PERFORM_MAX_TALENT_ACTION,
        args = {
            talentId = TALENT_ID,
        }
    })
end

-- =================================
-- UI刷新方法
-- =================================

function RebirthGui:RefreshDisplay()
    gg.log("根据天赋等级刷新重生列表:", self.currentTalentLevel)
    
    self.rebirthList:ClearChildren({ "最大重生" })

    -- 刷新最大重生节点
    self:RefreshMaxRebirthNode()

    if not self.rebirthTemplate or not self.rebirthTemplate.node then
        gg.log("错误：找不到重生项模板")
        return
    end

    if self.currentTalentLevel == 0 then
        gg.log("天赋等级为0，不显示任何重生选项")
        -- 可选：显示一条提示信息
        return
    end
    
    for level, costs in pairs(self.costsByLevel) do
        -- 1. 在客户端判断玩家资源是否足够
        local canAfford = true
        if costs and #costs > 0 then
            for _, costInfo in ipairs(costs) do
                local playerAmount = self.playerResources[costInfo.item] or 0
                if playerAmount < costInfo.amount then
                    canAfford = false
                    break -- 只要有一项资源不够，就跳出循环
                end
            end
        else
            canAfford = false -- 没有有效消耗配置，也视为不可负担
        end

        -- 2. 总是创建UI项
        local itemNode = self.rebirthTemplate.node:Clone()
        itemNode.Visible = true
        itemNode.Name = "RebirthOption_" .. level

        -- 3. 设置文本内容
        local titleText = itemNode["可重生次数"]
        if titleText then
            titleText.Title = string.format("可重生 %d 次", level)
        end
        
        local costText = itemNode["重生消耗"]
        if costText then
            local costInfo = costs[1] -- 假设每个等级只有一种消耗
            local costName = "战力"
            costText.Title = string.format("消耗: %s %s", costName, gg.FormatLargeNumber(costInfo.amount))
        end

        -- 4. 创建按钮并根据资源情况设置其可用状态
        local itemButton = ViewButton.New(itemNode["重生"], self)
        itemButton:SetTouchEnable(canAfford) -- 如果canAfford为false，按钮将自动变灰且不可点击
        
        itemButton.clickCb = function()
            -- SetTouchEnable会阻止不可用按钮的点击事件，但为了保险起见，可以再加一层判断
            if canAfford then
                self:OnClickRebirthLevel(level)
            else
                gg.log("资源不足，无法执行此等级的重生。") -- 可以加一个用户提示
            end
        end
        
        self.rebirthList:AppendChild(itemNode)
    end
end

function RebirthGui:RefreshMaxRebirthNode()
    gg.log("self.maxRebirthCountText",self.maxRebirthCountText,"elf.maxRebirthCostText",self.maxRebirthCostText)

    self.maxRebirthCountText.node.Title = string.format("可重生 %d 次", self.maxExecutions)
    local costName = "战力" -- 根据您的修改，硬编码为“战力”
    self.maxRebirthCostText.node.Title = string.format("消耗: %s %s", costName, gg.FormatLargeNumber(self.maxExecutionTotalCost))

end

return RebirthGui.New(script.Parent, uiConfig)
