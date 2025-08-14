-- ContestGui.lua
-- 比赛界面逻辑（初始化隐藏排行榜名字）

local MainStorage = game:GetService("MainStorage")
local CoreUI = game:GetService("CoreUI")
local Players = game:GetService("Players")

-- 引入核心模块
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

-- 引入UI基类和组件
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent

-- UI配置
local uiConfig = {
	uiName = "ContestGui",
	layer = 1,
	hideOnInit = true,
}

---@class ContestGui : ViewBase
local ContestGui = ClassMgr.Class("ContestGui", ViewBase)

---@override
function ContestGui:OnInit(node, config)
	-- 1. 节点初始化
	self:InitNodes()


    	-- 2. 初始化时隐藏排行榜名字
	self:HideRankNames()
	-- 3. 注册事件监听
	self:RegisterEvents()

	-- 4. 初始化数据
	self.raceData = {
		raceTime = 0,
		elapsedTime = 0,
		remainingTime = 0,
		topThree = {},
		totalPlayers = 0
	}
end

-- 节点初始化
function ContestGui:InitNodes()
	-- 底图与倒计时容器
	self.root = self:Get("底图", ViewComponent) ---@type ViewComponent
	self.countDown = self:Get("底图/比赛倒计时", ViewComponent) ---@type ViewComponent
    self.countDown:SetVisible(false)

	-- 比赛排行榜位（容器，含 名次1/名次2/名次3 ...）
	self.rankContainer = self:Get("底图/比赛排行栏位", ViewList) ---@type ViewList
	self.rankNameComponents = {} ---@type ViewComponent[]
	
	-- 初始化前三名排行榜组件，使用节点名字作为key
	self.rankComponents = {}
	for _, childComponent in ipairs(self.rankContainer.childrensList) do
		if childComponent and childComponent.node then
			local nodeName = childComponent.node.Name
			if nodeName then
				self.rankComponents[nodeName] = {
					container = childComponent,
					nameComponent = nil,
					avatarComponent = nil
				}
			end
		end
	end
end

-- 隐藏排行榜每个名次下的"名称"文本
function ContestGui:HideRankNames()
	if not self.rankContainer then return end
	for _, comp in ipairs(self.rankContainer.childrensList) do
		-- 直接访问子节点，避免找不到时产生日志
		local nameNode = comp.node 
		if nameNode then
			local nameComp = ViewComponent.New(nameNode, self, comp.path)
			nameComp:SetVisible(false)
			table.insert(self.rankNameComponents, nameComp)
		end
	end
end

-- 注册事件监听
function ContestGui:RegisterEvents()
	-- 监听比赛界面显示事件
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_CONTEST_SHOW, function(eventData)
		self:OnContestShow(eventData)
	end)

	-- 监听比赛界面隐藏事件
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_CONTEST_HIDE, function(eventData)
		self:OnContestHide(eventData)
	end)

	-- 监听比赛数据更新事件
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_CONTEST_UPDATE, function(eventData)
		self:OnContestUpdate(eventData)
	end)
end

-- 显示比赛界面
function ContestGui:OnContestShow(eventData)
	gg.log("显示比赛界面，比赛时长: " .. (eventData.raceTime or 60) .. "秒")
	self:SetVisible(true)
	self.countDown:SetVisible(true)
end

-- 隐藏比赛界面
function ContestGui:OnContestHide(eventData)
	gg.log("隐藏比赛界面")
	self:SetVisible(false)
end

-- 更新比赛数据
function ContestGui:OnContestUpdate(eventData)
	if not eventData then return end
	
	-- 更新内部数据
	self.raceData = eventData
	
	-- 更新倒计时显示
	self:UpdateCountdown(eventData.remainingTime)
	
	-- 更新前三名排行榜
	self:UpdateTopThreeRankings(eventData.topThree)
end

-- 更新倒计时显示
function ContestGui:UpdateCountdown(remainingTime)
	if not remainingTime then return end
	
	local minutes = math.floor(remainingTime / 60)
	local seconds = remainingTime % 60
	local timeText = string.format("%02d:%02d", minutes, seconds)
	
	-- 假设倒计时节点有Title属性
	if self.countDown and self.countDown.node and self.countDown.node.Title then
		self.countDown.node.Title = timeText
	end
end

-- 更新前三名排行榜
function ContestGui:UpdateTopThreeRankings(topThreeData)
	if not topThreeData or not self.rankComponents then return end
	
	-- 遍历所有排行榜组件，根据节点名字匹配
	for nodeName, rankComponent in pairs(self.rankComponents) do
		if rankComponent and rankComponent.container then
			-- 根据节点名字判断是第几名（假设节点名字包含排名信息）
			local rank = self:GetRankFromNodeName(nodeName)
			local playerData = topThreeData[rank]
			
			if playerData then
				-- 显示该排名的玩家信息
				self:ShowPlayerRank(rankComponent, playerData, rank)
			else
				-- 隐藏该排名位置
				self:HidePlayerRank(rankComponent)
			end
		end
	end
end

-- 根据节点名字获取排名
function ContestGui:GetRankFromNodeName(nodeName)
	-- 假设节点名字格式为 "名次1", "名次2", "名次3" 等
	if nodeName then
		local rank = string.match(nodeName, "名次(%d+)")
		if rank then
			return tonumber(rank)
		end
	end
	return 1 -- 默认返回1
end

-- 显示玩家排名信息
function ContestGui:ShowPlayerRank(rankComponent, playerData, rank)
	local container = rankComponent.container
	if not container or not container.node then return end
	
	-- 显示容器
	container:SetVisible(true)
	
	-- 更新玩家头像
	self:UpdatePlayerAvatar(rankComponent, playerData.userId)

end

-- 隐藏玩家排名信息
function ContestGui:HidePlayerRank(rankComponent)
	if rankComponent and rankComponent.container then
		rankComponent.container:SetVisible(false)
	end
end

-- 更新玩家头像
function ContestGui:UpdatePlayerAvatar(rankComponent, userId)
	if not rankComponent or not userId then return end
	if not rankComponent.container or not rankComponent.container.node then 
		gg.log("警告: ContestGui - 排行榜组件节点为空，无法更新头像")
		return 
	end
	
	-- 获取玩家头像节点
	local headNode = CoreUI:GetHeadNode(tostring(userId))
	if not headNode then 
		gg.log("警告: ContestGui - 无法获取玩家头像节点，userId: " .. tostring(userId))
		return 
	end
	
	-- 查找头像容器节点（假设存在头像位置）
	local avatarContainer = rankComponent.container.node["玩家头像"]
	if avatarContainer then
		-- 设置新头像
		headNode.Parent = avatarContainer
		headNode.Position = avatarContainer.Position
		headNode.Size = avatarContainer.Size 
        headNode.Pivot = avatarContainer.Pivot
        headNode.Parent = avatarContainer.Parent
		rankComponent.avatarComponent = headNode
	else
		gg.log("警告: ContestGui - 无法找到头像容器节点")
	end
end



return ContestGui.New(script.Parent, uiConfig)

