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
    
    -- 模板节点
    self.rebirthTemplate = self:Get("重生界面/模版界面/重生", ViewComponent) ---@type ViewComponent
    if self.rebirthTemplate and self.rebirthTemplate.node then
        self.rebirthTemplate.node.Visible = false
    end

    -- 2. 数据存储
    self.currentTalentLevel = 0 -- 当前重生天赋等级

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
    gg.log("RebirthGui打开，请求重生天赋等级")
    self:RequestTalentLevel()
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

    if not self.rebirthTemplate or not self.rebirthTemplate.node then
        gg.log("错误：找不到重生项模板")
        return
    end

    if self.currentTalentLevel == 0 then
        gg.log("天赋等级为0，不显示任何重生选项")
        -- 可选：显示一条提示信息
        return
    end
    
    for i = 1, self.currentTalentLevel do
        local itemNode = self.rebirthTemplate.node:Clone()
        itemNode.Visible = true
        itemNode.Name = "RebirthOption_" .. i

        -- 查找并设置文本
        local titleText = itemNode["可重生次数"]
        if titleText then
            titleText.Title = string.format("可重生 %d 次", i)
        end
        
        -- 查找并设置消耗文本 (注意：此方案下客户端不预先知道消耗，所以显示固定文本)
        local costText = itemNode["重生消耗"]
        if costText then
            costText.Title = "消耗: (点击查看)" -- 或者留空
        end

        -- 为整个克隆出的节点创建按钮并绑定事件
        local itemButton = ViewButton.New(itemNode["重生"], self)
        itemButton.clickCb = function()
            self:OnClickRebirthLevel(i)
        end
        
        self.rebirthList:AppendChild(itemNode)
    end
end

return RebirthGui.New(script.Parent, uiConfig)