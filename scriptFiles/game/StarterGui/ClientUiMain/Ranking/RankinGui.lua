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
    
    --gg.log("RankingGui 初始化完成")
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
    self.Tmplsit = self:Get("排行榜界面/排行榜位置模板", ViewList) ---@type ViewList
    self.Tmplsit:SetVisible(false)
    -- 前三名排名节点
    self.firstRank = self:Get("排行榜界面/排行榜位置模板/排名第一", ViewComponent) ---@type ViewComponent

    self.secondRank = self:Get("排行榜界面/排行榜位置模板/排名第二", ViewComponent) ---@type ViewComponent
    self.thirdRank = self:Get("排行榜界面/排行榜位置模板/排名第三", ViewComponent) ---@type ViewComponent  
    -- 其他排名节点
    self.otherRank = self:Get("排行榜界面/排行榜位置模板/排名其它", ViewComponent) ---@type ViewComponent
 
    -- 右侧区域
    self.rightBg = self:Get("排行榜界面/右侧底图", ViewComponent) ---@type ViewComponent  
    self.rankingButtonPos = self:Get("排行榜界面/右侧底图/排行榜按钮位置", ViewList) ---@type ViewList
   
    self.TemrankingButton = self:Get("排行榜界面/右侧底图/排行榜按钮位置模版/排行按钮", ViewButton) ---@type ViewButton
    self.TemrangkList = self:Get("排行榜界面/右侧底图/排行榜按钮位置模版", ViewList) ---@type ViewList
    self.TemrankingButton:SetVisible(false)
    self.TemrangkList:SetVisible(false)
    --gg.log("RankingGui 节点初始化完成")
end

-- 数据初始化
function RankingGui:InitData()
    self.rankingButtonsPos = {} ---@type {string:ViewList} 排行榜按钮位置LIST容器   
    self.rankingData = {} ---@type table 完整排行榜数据 {rankType = {rankingList = {}, playerRankInfo = {}, rankingConfig = {}}}
    self.rankingTypes = {} ---@type table 支持的排行榜类型列表
    self.currentRankType = nil ---@type string 当前排行榜类型
    self.maxDisplayRanks = 100 ---@type number 最大显示排名数量
    
    -- 读取排行榜配置
    self:LoadRankingConfig()
    
    --gg.log("RankingGui 数据初始化完成")
end

--- 加载排行榜配置并生成按钮
function RankingGui:LoadRankingConfig()
    -- 引入排行榜配置
    local RankingConfig = require(MainStorage.Code.Common.Config.RankingConfig) ---@type RankingConfig
    
    -- 检查模板按钮是否存在
    if not self.TemrankingButton then
        --gg.log("排行榜模板按钮不存在，无法生成排行榜按钮")
        return
    end
    
    -- 检查按钮位置容器是否存在
    if not self.rankingButtonPos then
        --gg.log("排行榜按钮位置容器不存在，无法生成排行榜按钮")
        return
    end
    
    -- 清空现有的排行榜按钮（保留模板）
    self.rankingButtonPos:ClearChildren()
    
    -- 将配置转换为数组并按权重排序（权重高优先）
    local sortedList = {}
    for rankType, config in pairs(RankingConfig.CONFIGS) do
        table.insert(sortedList, { rankType = rankType, config = config })
    end
    table.sort(sortedList, function(a, b)
        local wa = (a.config and a.config.weight) or 0
        local wb = (b.config and b.config.weight) or 0
        if wa ~= wb then
            return wa > wb
        end
        -- 次级排序：按名称，确保稳定输出
        local na = (a.config and a.config.name) or a.rankType
        local nb = (b.config and b.config.name) or b.rankType
        return tostring(na) < tostring(nb)
    end)

    -- 记录排序后的类型列表（可用于其他地方需要顺序展示时）
    self.rankingTypesSorted = {}
    for i = 1, #sortedList do
        self.rankingTypesSorted[i] = sortedList[i].rankType
    end
    
    -- 按排序结果生成按钮
    for i = 1, #sortedList do
        local rankType = sortedList[i].rankType
        local config = sortedList[i].config
        
        -- 克隆模板按钮
        local buttonNode = self.TemrankingButton.node:Clone()
        local rankingPositionNode = self.rankingPosition.node:Clone()
        rankingPositionNode.Name = rankType
        buttonNode.Name = "排行榜_" .. rankType
        buttonNode.Visible = true
        
        -- 设置按钮名称标签
        local buttonNameLabel = buttonNode:FindFirstChild("按钮名称")
        if buttonNameLabel then
            buttonNameLabel.Title = config.name or rankType
        end
        
        -- 使用ViewList的AppendChild方法添加节点
        self.rankingButtonPos:AppendChild(buttonNode)
        
        -- 为按钮添加点击事件
        local viewButton = ViewButton.New(buttonNode, self, buttonNode.Name)
        viewButton.clickCb = function()
            self:OnRankingTypeButtonClicked(rankType, config)
        end
        
        -- 存储按钮引用
        if not self.rankingButtons then
            self.rankingButtons = {}
        end
        self.rankingButtons[rankType] = viewButton
        self.rankingButtonsPos[rankType] = rankingPositionNode
    end
    
    --gg.log("排行榜按钮生成完成，总数:", #self.rankingTypesSorted)
end

-- 事件注册
function RankingGui:RegisterEvents()
    -- 引入排行榜事件配置
    local RankingEvent = require(MainStorage.Code.Event.EventRanking) ---@type EventRanking
    
    -- 监听排行榜数据同步事件
    ClientEventManager.Subscribe(RankingEvent.NOTIFY.RANKING_DATA_SYNC, function(data)
        self:OnRankingDataSync(data)
    end)
    
    -- 监听排行榜类型同步事件
    ClientEventManager.Subscribe(RankingEvent.NOTIFY.RANKING_TYPES_SYNC, function(data)
        self:OnRankingTypesSync(data)
    end)
    
    --gg.log("RankingGui 事件注册完成")
end

-- 按钮事件注册
function RankingGui:RegisterButtonEvents()
    -- 关闭按钮
    if self.closeButton then
        self.closeButton.clickCb = function()
            self:OnCloseButtonClicked()
        end
    end
    
    --gg.log("RankingGui 按钮事件注册完成")
end

-- 关闭按钮点击事件
function RankingGui:OnCloseButtonClicked()
    --gg.log("点击关闭排行榜界面")
    self:Close()
end

--- 排行榜类型按钮点击事件
---@param rankType string 排行榜类型
---@param config table 排行榜配置
function RankingGui:OnRankingTypeButtonClicked(rankType, config)
    --gg.log("点击排行榜类型按钮", rankType, config.name)
    
    -- 设置当前排行榜类型
    self.currentRankType = rankType
    
    -- 显示排行榜界面
    self:ShowRanking(rankType)
    
end

--- 处理排行榜数据同步事件
---@param data table 排行榜数据 {rankType, rankingConfig, rankingList, playerRankInfo, count}
function RankingGui:OnRankingDataSync(data)
    --gg.log("获取到的排行榜数据", data)
    if not data or not data.rankType then
        --gg.log("排行榜数据同步事件数据无效")
        return
    end
    
    local rankType = data.rankType
    
    -- 存储完整的排行榜数据
    self.rankingData[rankType] = {
        rankingConfig = data.rankingConfig or {}, -- 排行榜配置
        rankingList = data.rankingList or {}, -- 完整排行榜列表
        playerRankInfo = data.playerRankInfo or {}, -- 玩家排名信息
        count = data.count or 0, -- 排行榜条目数量
        timestamp = data.timestamp or 0 -- 数据时间戳
    }
    
    local playerRank = (data.playerRankInfo and data.playerRankInfo.rank) or -1
    local listCount = data.count or 0
    
    --gg.log("接收排行榜数据同步", rankType, "排行榜条目数:", listCount, "玩家排名:", playerRank)
end

--- 处理排行榜类型同步事件
---@param data table 排行榜类型数据 {rankingTypes, count}
function RankingGui:OnRankingTypesSync(data)
    --gg.log("排行榜数据",data)
    if not data or not data.rankingTypes then
        --gg.log("排行榜类型同步事件数据无效")
        return
    end
    
    -- 存储排行榜类型列表
    self.rankingTypes = data.rankingTypes or {}
    
    --gg.log("接收排行榜类型同步", "类型数量:", #self.rankingTypes)
end

-- 显示排行榜界面
function RankingGui:ShowRanking(rankType)
    self.currentRankType = rankType or "default"
    self:SetVisible(true)
    
    -- 获取排行榜数据
    local rankingData = self.rankingData[rankType]
    if not rankingData then
        --gg.log("显示排行榜界面失败：排行榜数据不存在", rankType)
        return
    end
    
    local config = rankingData.rankingConfig
    local rankingList = rankingData.rankingList    
    -- 更新界面标题
    self.paramLabel.node.Title = config.displayName
    
    
    -- 显示排行榜数据
    self:DisplayRankingList(rankingList)
    

end

-- 隐藏排行榜界面
function RankingGui:HideRanking()
    self:SetVisible(false)  
    --gg.log("隐藏排行榜界面")
end

--- 显示排行榜列表
---@param rankingList table 排行榜数据列表
function RankingGui:DisplayRankingList(rankingList)
       -- 先清理排行榜位置容器的所有子节点
    if self.rankingPosition then
        self.rankingPosition:ClearChildren()
        --gg.log("清理排行榜位置容器完成")
    end
    if not rankingList or #rankingList == 0 then
        --gg.log("排行榜列表为空，无法显示")
        return
    end
    
 
    
    -- 显示前三名（使用特有的节点）
    for i = 1, math.min(3, #rankingList) do
        local rankData = rankingList[i]
        if rankData then
            self:DisplayTopRank(i, rankData)
        end
    end
    
    -- 显示第4名及以后的排名（使用通用节点）
    if #rankingList > 3 then
        for i = 4, #rankingList do
            local rankData = rankingList[i]
            if rankData then
                self:DisplayOtherRank(i, rankData)
            end
        end
    end
    
    ----gg.log("显示排行榜列表完成，共", #rankingList, "条数据")
end

--- 显示前三名排行榜数据
---@param rank number 排名（1-3）
---@param rankData table 排名数据 {uin, score, playerName, rank}
function RankingGui:DisplayTopRank(rank, rankData)
    if not rankData then return end
    
    -- 正确处理服务器发送的数据格式
    local playerName = rankData.playerName or "未知玩家"
    local score = rankData.score or 0
    local playerUin = rankData.uin or ""
    
    
    local rankNode = nil
    if rank == 1 then
        rankNode = self.firstRank
    elseif rank == 2 then
        rankNode = self.secondRank
    elseif rank == 3 then
        rankNode = self.thirdRank
    end
    
    if not rankNode then return end
    
    -- 克隆排名节点
    local clonedRankNode = rankNode.node:Clone()
    clonedRankNode.Name = "排名_" .. rank
    
    -- 设置排名信息
    local playerNameNode = clonedRankNode:FindFirstChild("玩家名字")
    local playerParamNode = clonedRankNode:FindFirstChild("排行参数")
    
    if playerNameNode then
        playerNameNode.Title = playerName
    end
    if playerParamNode then
        playerParamNode.Title = gg.FormatLargeNumber(score)
    end
    
    -- 使用ViewList的AppendChild方法添加到排行榜位置容器
    if self.rankingPosition then
        self.rankingPosition:AppendChild(clonedRankNode)
        --gg.log("添加前三名排名", rank, ":", playerName, score)
    end
end

--- 显示第4名及以后的排行榜数据
---@param rank number 排名（4及以上）
---@param rankData table 排名数据 {uin, score, playerName, rank}
function RankingGui:DisplayOtherRank(rank, rankData)
    if not rankData or not self.otherRank then return end
    
    -- 正确处理服务器发送的数据格式
    local playerName = rankData.playerName or "未知玩家"
    local score = rankData.score or 0
    local playerUin = rankData.uin or ""
    
    -- 如果playerName为空，显示默认名称
    if playerName == "" then
        playerName = "玩家" .. tostring(playerUin)
    end
    
    -- 克隆排名其它模板节点
    local otherRankNode = self.otherRank.node:Clone()
    otherRankNode.Name = "排名_" .. rank
    
    -- 设置排名信息
    local rankIndexNode = otherRankNode:FindFirstChild("名次")
    local playerNameNode = otherRankNode:FindFirstChild("玩家名字")
    local playerParamNode = otherRankNode:FindFirstChild("排行参数")
    
    if rankIndexNode then
        rankIndexNode.Title = tostring(rank)
    end

    if playerNameNode then
        playerNameNode.Title = playerName
    end
    if playerParamNode then
        playerParamNode.Title = gg.FormatLargeNumber(score)
    end
    
    -- 使用ViewList的AppendChild方法添加到排行榜位置容器
    if self.rankingPosition then
        self.rankingPosition:AppendChild(otherRankNode)
        --gg.log("添加排名", rank, ":", playerName, score)
    end
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
        rankingButton = self.rankingButton,
        rankingButtons = self.rankingButtons or {} -- 动态生成的排行榜按钮
    }
end

--- 获取指定排行榜类型的玩家排名信息
---@param rankType string 排行榜类型
---@return table|nil 排名信息 {rank, score, playerName, isOnRanking}
function RankingGui:GetPlayerRankInfo(rankType)
    if not rankType or not self.rankingData then
        return nil
    end
    
    local rankingData = self.rankingData[rankType]
    if not rankingData then
        return nil
    end
    
    return rankingData.playerRankInfo
end

--- 获取所有排行榜类型
---@return table 排行榜类型列表
function RankingGui:GetAllRankingTypes()
    return self.rankingTypes or {}
end

--- 检查是否已接收到排行榜数据
---@return boolean 是否已接收数据
function RankingGui:HasRankingData()
    return next(self.rankingData) ~= nil and next(self.rankingTypes) ~= nil
end

--- 获取指定排行榜类型的完整排行榜列表
---@param rankType string 排行榜类型
---@return table|nil 排行榜列表
function RankingGui:GetRankingList(rankType)
    if not rankType or not self.rankingData then
        return nil
    end
    
    local rankingData = self.rankingData[rankType]
    if not rankingData then
        return nil
    end
    
    return rankingData.rankingList
end

--- 获取指定排行榜类型的配置信息
---@param rankType string 排行榜类型
---@return table|nil 配置信息
function RankingGui:GetRankingConfig(rankType)
    if not rankType or not self.rankingData then
        return nil
    end
    
    local rankingData = self.rankingData[rankType]
    if not rankingData then
        return nil
    end
    
    return rankingData.rankingConfig
end

--- 获取指定排行榜类型的数据统计
---@param rankType string 排行榜类型
---@return table|nil 统计信息 {count, timestamp}
function RankingGui:GetRankingStats(rankType)
    if not rankType or not self.rankingData then
        return nil
    end
    
    local rankingData = self.rankingData[rankType]
    if not rankingData then
        return nil
    end
    
    return {
        count = rankingData.count or 0,
        timestamp = rankingData.timestamp or 0
    }
end

return RankingGui.New(script.Parent, uiConfig)