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
local NodeConf = require(MainStorage.Code.Common.Icon.NodeConf) ---@type NodeConf

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
					avatarComponent = nil,
					userId = nil -- 新增：用于跟踪当前排名显示的玩家ID
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
	-- 监听比赛准备倒计时事件
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_PREPARE_COUNTDOWN, function(eventData)
		self:OnPrepareCountdown(eventData)
	end)
	
	-- 【新增】监听停止比赛准备倒计时事件
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_PREPARE_COUNTDOWN_STOP, function(eventData)
		self:OnStopPrepareCountdown(eventData)
	end)

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

-- 处理比赛准备倒计时
function ContestGui:OnPrepareCountdown(eventData)
	local prepareTime = eventData.prepareTime or 10
	local playerScene = eventData.playerScene or "init_map" -- 【新增】从服务端获取玩家场景
	
	--gg.log("收到比赛准备倒计时，准备时间: " .. prepareTime .. "秒，玩家场景: " .. playerScene)
	
	-- 保存玩家场景信息
	self.currentPlayerScene = playerScene
	
	-- 显示准备倒计时界面
	self:SetVisible(true)
	self.countDown:SetVisible(true)
	
	-- 获取场景中的倒计时节点并设置初始文本
	self:SetupCountdownNode(prepareTime)
	
	-- 开始倒计时显示
	self:StartPrepareCountdown(prepareTime)
end

-- 设置倒计时节点
function ContestGui:SetupCountdownNode(prepareTime)
	-- 【修改】使用服务端提供的玩家场景信息
	local currentScene = self.currentPlayerScene or "init_map"
	if not currentScene then
		--gg.log("警告: ContestGui - 无法获取玩家当前场景")
		return
	end
	
	--gg.log("使用服务端提供的场景信息:", currentScene)
	
	-- 从NodeConf获取倒计时节点路径
	local countdownPath = NodeConf["倒计时"][currentScene]
	if not countdownPath then
		--gg.log("警告: ContestGui - 无法从NodeConf获取场景 " .. currentScene .. " 的倒计时节点路径")
		return
	end
	
	-- 从WorkSpace开始，使用gg.GetChild方法获取场景节点
	local workSpace = game.WorkSpace
	local countdownNode = gg.GetChild(workSpace, countdownPath)
	if not countdownNode then
		--gg.log("警告: ContestGui - 无法获取倒计时节点: " .. countdownPath)
		return
	end
	
	-- 设置倒计时节点的初始文本
	local timeText = string.format("%02d：%02d：%02d后开始比赛", 
		math.floor(prepareTime / 3600), 
		math.floor((prepareTime % 3600) / 60), 
		prepareTime % 60)
	
	-- 设置节点标题
	if countdownNode.Title then
		countdownNode.Title = timeText
		--gg.log("成功设置倒计时节点文本: " .. timeText)
	else
		--gg.log("警告: ContestGui - 倒计时节点没有Title属性")
	end
	
	-- 保存节点引用以便后续更新
	self.sceneCountdownNode = countdownNode
end

-- 【新增】设置比赛剩余时间显示
function ContestGui:SetupRaceTimeDisplay(raceTime)

	
	-- 设置初始比赛剩余时间文本
	local timeText = string.format("剩余时间: %02d:%02d", 
		math.floor(raceTime / 60), 
		raceTime % 60)
	
	if self.countDown.Title then
		self.countDown.Title = timeText
		--gg.log("成功设置比赛剩余时间文本: " .. timeText)
	else
		--gg.log("警告: ContestGui - 倒计时节点没有Title属性")
	end
	
end
-- 获取当前玩家所在场景
function ContestGui:GetCurrentPlayerScene()
	-- 【修改】优先使用服务端提供的场景信息
	if self.currentPlayerScene then
		--gg.log("使用服务端提供的场景信息:", self.currentPlayerScene)
		return self.currentPlayerScene
	end
	
	-- 尝试从本地玩家数据获取场景信息
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return nil
	end
	
	local uin = localPlayer.UserId
	--gg.log("当前玩家ID: " .. uin)
	if not uin then
		return nil
	end
	
	-- 从全局映射中获取场景信息（备用方案）
	local scene = gg.player_scene_map and gg.player_scene_map[uin]
	if scene then
		--gg.log("从全局场景映射获取场景:", scene)
		return scene
	end
	
	-- 默认返回init_map
	--gg.log("使用默认场景: init_map")
	return "init_map"
end

-- 开始准备倒计时
function ContestGui:StartPrepareCountdown(prepareTime)
    -- 如果已有定时器，先停止并清理
    if self.prepareTimer then
        self.prepareTimer:Stop()
        self.prepareTimer:Destroy()
        self.prepareTimer = nil
    end
    
    local remainingTime = prepareTime
    
    -- 创建定时器节点
    self.prepareTimer = SandboxNode.New("Timer", game.WorkSpace)
    self.prepareTimer.Name = string.format("ContestPrepareCountdown_%s", self.name or "ContestGui")
    self.prepareTimer.Delay = 1 -- 首次延迟1秒
    self.prepareTimer.Loop = true -- 循环执行
    self.prepareTimer.Interval = 1 -- 每秒执行一次
    
    -- 设置定时器回调
    self.prepareTimer.Callback = function()
        if remainingTime > 0 then
            -- 更新倒计时显示
            self:UpdatePrepareCountdown(remainingTime)
            remainingTime = remainingTime - 1
        else
            -- 倒计时结束，停止定时器
            self.prepareTimer:Stop()
            self.prepareTimer = nil
            
            -- 隐藏倒计时
            self.countDown:SetVisible(false)
            
            -- 清理场景节点引用
            self.sceneCountdownNode = nil
            
            --gg.log("比赛准备倒计时结束")
        end
    end
    
    -- 启动定时器
    self.prepareTimer:Start()
    
    --gg.log(string.format("开始比赛准备倒计时，总时间: %d秒", prepareTime))
end

-- 更新准备倒计时显示
function ContestGui:UpdatePrepareCountdown(remainingTime)
	if not self.countDown or not self.countDown.node then return end
	
	-- 更新UI倒计时文本
	local uiTimeText = string.format("准备开始: %d", remainingTime)
	if self.countDown.node.Title then
		self.countDown.node.Title = uiTimeText
	end
	
	-- 同时更新场景中的倒计时节点
	if self.sceneCountdownNode and self.sceneCountdownNode.Title then
		local sceneTimeText = string.format("%02d：%02d：%02d后开始比赛", 
			math.floor(remainingTime / 3600), 
			math.floor((remainingTime % 3600) / 60), 
			remainingTime % 60)
		self.sceneCountdownNode.Title = sceneTimeText
	end
end

-- 【新增】处理停止比赛准备倒计时事件
function ContestGui:OnStopPrepareCountdown(eventData)
	local reason = eventData.reason or "未知原因"
	--gg.log("收到停止比赛准备倒计时事件，原因: " .. reason)
	
	-- 停止并清理准备倒计时定时器
	if self.prepareTimer then
		self.prepareTimer:Stop()
		self.prepareTimer:Destroy()
		self.prepareTimer = nil
		--gg.log("准备倒计时定时器已停止并清理")
	end
	
	-- 隐藏倒计时界面
	if self.countDown then
		self.countDown:SetVisible(false)
	end
	
	-- 清理场景倒计时节点的文本
	if self.sceneCountdownNode and self.sceneCountdownNode.Title then
		self.sceneCountdownNode.Title = ""
		--gg.log("已清理场景倒计时节点文本")
	end
	
	-- 清理场景节点引用
	self.sceneCountdownNode = nil
	
	-- 隐藏整个比赛界面
	self:SetVisible(false)
	
	--gg.log(string.format("比赛准备倒计时已停止，原因: %s", reason))
end

-- 显示比赛界面
function ContestGui:OnContestShow(eventData)
	--gg.log("显示比赛界面，比赛时长: " .. (eventData.raceTime or 60) .. "秒")
	self:SetVisible(true)
	self.countDown:SetVisible(true)
	self.rankContainer:SetVisible(true) -- 比赛开始时显示排行榜
		-- 设置初始比赛剩余时间文本
	local timeText = string.format("剩余时间: %02d:%02d", 
	math.floor(eventData.raceTime / 60), eventData.raceTime % 60)

	self.countDown.node.Title = timeText

end

-- 隐藏比赛界面
function ContestGui:OnContestHide(eventData)
    --gg.log("隐藏比赛界面")
    self:SetVisible(false)
    self.rankContainer:SetVisible(false) -- 比赛结束时隐藏排行榜

    -- 清理排行榜信息
    if self.rankComponents then
        for _, rankComponent in pairs(self.rankComponents) do
            self:HidePlayerRank(rankComponent)
        end
    end
    
    -- 清理准备倒计时定时器
    if self.prepareTimer then
        self.prepareTimer:Stop()
        self.prepareTimer:Destroy()
        self.prepareTimer = nil
    end
end


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
	
	local timeText = string.format("剩余时间: %02d:%02d", 
	math.floor(remainingTime / 60), remainingTime % 60)
	self.countDown:SetVisible(true)
	
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
	
	-- 优化：如果玩家ID未变，则不更新头像
	if rankComponent.userId and rankComponent.userId == playerData.userId then
		return
	end
	
	-- 更新玩家头像
	self:UpdatePlayerAvatar(rankComponent, playerData.userId)
	-- 保存新的玩家ID
	rankComponent.userId = playerData.userId
end

-- 隐藏玩家排名信息
function ContestGui:HidePlayerRank(rankComponent)
	if rankComponent and rankComponent.container then
		rankComponent.container:SetVisible(false)
		rankComponent.userId = nil -- 清除玩家ID
	end
end

-- 更新玩家头像
function ContestGui:UpdatePlayerAvatar(rankComponent, userId)
	if not rankComponent or not userId then return end
	if not rankComponent.container or not rankComponent.container.node then 
		--gg.log("警告: ContestGui - 排行榜组件节点为空，无法更新头像")
		return 
	end
	
	-- 获取玩家头像节点
	local headNode = CoreUI:GetHeadNode(tostring(userId))
	if not headNode then 
		--gg.log("警告: ContestGui - 无法获取玩家头像节点，userId: " .. tostring(userId))
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
		--gg.log("警告: ContestGui - 无法找到头像容器节点")
	end
end



return ContestGui.New(script.Parent, uiConfig)

