-- RankingGui.lua
-- 排行榜界面逻辑

local MainStorage = game:GetService("MainStorage")
local CoreUI = game:GetService("CoreUI")
local Players = game:GetService("Players")

-- 引入核心模块
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager

-- 引入UI基类和组件
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent

-- UI配置
local uiConfig = {
    uiName = "RankingGui",
    layer = 3,
    hideOnInit = true,
}

---@class RankingGui : ViewBase
local RankingGui = ClassMgr.Class("RankingGui", ViewBase)

---@override
function RankingGui:OnInit(node, config)
    -- 1. 节点初始化
    self:InitNodes()
    
    -- 2. 数据存储初始化
    self:InitData()
    
    -- 3. 事件注册
    self:RegisterEvents()
    
    -- 4. 按钮点击事件注册
    self:RegisterButtonEvents()
    
    gg.log("RankingGui 初始化完成")
end

-- 节点初始化
function RankingGui:InitNodes()
    -- 主界面容器
    self.blackBg = self:Get("黑色底图", ViewComponent) ---@type ViewComponent
    self.rankingPanel = self:Get("排行榜界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("排行榜界面/关闭", ViewButton) ---@type ViewButton
    
    -- 排行榜标题栏
    self.rankingNamePanel = self:Get("排行榜界面/排行榜名称", ViewComponent) ---@type ViewComponent
    self.rankLabel = self:Get("排行榜界面/排行榜名称/排名", ViewComponent) ---@type ViewComponent
    self.playerLabel = self:Get("排行榜界面/排行榜名称/玩家", ViewComponent) ---@type ViewComponent  
    self.paramLabel = self:Get("排行榜界面/排行榜名称/排名参数名称", ViewComponent) ---@type ViewComponent
    
    -- 排行榜内容区域
    self.rankingPosition = self:Get("排行榜界面/排行榜位置", ViewList) ---@type ViewList
    
    -- 前三名排名节点
    self.firstRank = self:Get("排行榜界面/排行榜位置/排名第一", ViewComponent) ---@type ViewComponent
    self.firstPlayerName = self:Get("排行榜界面/排行榜位置/排名第一/玩家名字", ViewComponent) ---@type ViewComponent
    self.firstPlayerParam = self:Get("排行榜界面/排行榜位置/排名第一/排行参数", ViewComponent) ---@type ViewComponent  
    self.firstPlayerRank = self:Get("排行榜界面/排行榜位置/排名第一/排名", ViewComponent) ---@type ViewComponent
    
    self.secondRank = self:Get("排行榜界面/排行榜位置/排名第二", ViewComponent) ---@type ViewComponent
    self.secondPlayerName = self:Get("排行榜界面/排行榜位置/排名第二/玩家名字", ViewComponent) ---@type ViewComponent
    self.secondPlayerParam = self:Get("排行榜界面/排行榜位置/排名第二/排行参数", ViewComponent) ---@type ViewComponent
    self.secondPlayerRank = self:Get("排行榜界面/排行榜位置/排名第二/排名", ViewComponent) ---@type ViewComponent
    
    self.thirdRank = self:Get("排行榜界面/排行榜位置/排名第三", ViewComponent) ---@type ViewComponent  
    self.thirdPlayerRank = self:Get("排行榜界面/排行榜位置/排名第三/排名", ViewComponent) ---@type ViewComponent
    self.thirdPlayerName = self:Get("排行榜界面/排行榜位置/排名第三/玩家名字", ViewComponent) ---@type ViewComponent
    self.thirdPlayerParam = self:Get("排行榜界面/排行榜位置/排名第三/排行参数", ViewComponent) ---@type ViewComponent
    
    -- 其他排名节点
    self.otherRank = self:Get("排行榜界面/排行榜位置/排名其它", ViewComponent) ---@type ViewComponent
    self.otherRankIndex = self:Get("排行榜界面/排行榜位置/排名其它/名次", ViewComponent) ---@type ViewComponent
    self.otherPlayerRank = self:Get("排行榜界面/排行榜位置/排名其它/排名", ViewComponent) ---@type ViewComponent
    self.otherPlayerName = self:Get("排行榜界面/排行榜位置/排名其它/玩家名字", ViewComponent) ---@type ViewComponent
    self.otherPlayerParam = self:Get("排行榜界面/排行榜位置/排名其它/排行参数", ViewComponent) ---@type ViewComponent
    
    -- 右侧区域
    self.rightBg = self:Get("右侧底图", ViewComponent) ---@type ViewComponent  
    self.rankingButtonPos = self:Get("右侧底图/排行榜按钮位置", ViewList) ---@type ViewList

    self.TemrankingButton = self:Get("右侧底图/排行榜按钮位置模版/排行榜", ViewButton) ---@type ViewButton
    self.TembuttonNameLabel = self:Get("右侧底图/排行榜按钮位置模版/排行榜/按钮名称", ViewComponent) ---@type ViewComponent
    
    gg.log("RankingGui 节点初始化完成")
end

-- 数据初始化
function RankingGui:InitData()
    self.rankingData = {} ---@type table 排行榜数据
    self.currentRankType = nil ---@type string 当前排行榜类型
    self.maxDisplayRanks = 100 ---@type number 最大显示排名数量
    
    gg.log("RankingGui 数据初始化完成")
end

-- 事件注册
function RankingGui:RegisterEvents()
    -- TODO: 添加服务器事件监听
    -- 示例：
    -- ClientEventManager.AddListener(RankingEventConfig.RANKING_DATA_UPDATE, self.OnRankingDataUpdate, self)
    
    gg.log("RankingGui 事件注册完成")
end

-- 按钮事件注册
function RankingGui:RegisterButtonEvents()
    -- 关闭按钮
    if self.closeButton then
        self.closeButton.clickCb = function()
            self:OnCloseButtonClicked()
        end
    end
    
    -- 排行榜按钮
    if self.rankingButton then
        self.rankingButton.clickCb = function()
            self:OnRankingButtonClicked()
        end
    end
    
    gg.log("RankingGui 按钮事件注册完成")
end

-- 关闭按钮点击事件
function RankingGui:OnCloseButtonClicked()
    gg.log("点击关闭排行榜界面")
    self:SetVisible(false)
end

-- 排行榜按钮点击事件  
function RankingGui:OnRankingButtonClicked()
    gg.log("点击排行榜按钮")
    -- TODO: 实现排行榜按钮逻辑
end

-- 显示排行榜界面
function RankingGui:ShowRanking(rankType)
    self.currentRankType = rankType or "default"
    self:SetVisible(true)
    gg.log("显示排行榜界面，类型:", self.currentRankType)
end

-- 隐藏排行榜界面
function RankingGui:HideRanking()
    self:SetVisible(false)  
    gg.log("隐藏排行榜界面")
end

-- 获取节点引用的便捷方法
function RankingGui:GetRankingNodes()
    return {
        blackBg = self.blackBg,
        rankingPanel = self.rankingPanel, 
        closeButton = self.closeButton,
        rankingNamePanel = self.rankingNamePanel,
        rankingPosition = self.rankingPosition,
        firstRank = self.firstRank,
        secondRank = self.secondRank,
        thirdRank = self.thirdRank,
        otherRank = self.otherRank,
        rightBg = self.rightBg,
        rankingButton = self.rankingButton
    }
end

return RankingGui.New(script.Parent, uiConfig)