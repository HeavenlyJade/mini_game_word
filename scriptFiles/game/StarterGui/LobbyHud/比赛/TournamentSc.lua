-- 引用核心模块
local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local VectorUtils = require(MainStorage.Code.Untils.VectorUtils) ---@type VectorUtils

-- UI配置
local uiConfig = {
	uiName = "TournamentSc",
	layer = 2, -- HUD界面层级
	hideOnInit = false, -- HUD默认显示
}

---@class TournamentSc : ViewBase
local TournamentSc = ClassMgr.Class("TournamentSc", ViewBase)

---@override
function TournamentSc:OnInit(node, config)
	-- 1. 节点初始化
	self:InitNodes()

	-- 2. 数据存储
	self:InitData()

	-- 3. 事件注册
	self:RegisterEvents()

	-- 4. 按钮点击事件注册
	self:RegisterButtonEvents()

	--gg.log("比赛UI初始化完成")
end

-- 节点初始化
function TournamentSc:InitNodes()
	self.CoreUI = game:GetService("CoreUI")
	self.basePanel = self:Get("底图", ViewComponent)
	self.functionPanel = self:Get("底图/功能", ViewComponent)
	self.GameUserMag1 = self:Get("底图/功能/比赛进度条1/玩家头像模板", ViewComponent)
	self.GameUserMag2 = self:Get("底图/功能/比赛进度条2/玩家头像模板", ViewComponent)
	self.GameUserMag3 = self:Get("底图/功能/比赛进度条3/玩家头像模板", ViewComponent)
	self.GmaeDisTop = self:Get("底图/比赛距离实时", ViewComponent)
	-- 距离节点默认隐藏，只在比赛时显示
	self.GmaeDisTop:SetVisible(false)
	-- 比赛进度条
	self.progressBars = {}
	for i = 1, 3 do
		local basePath = "底图/功能/比赛进度条" .. i
		self.progressBars[i] = {
			container = self:Get(basePath, ViewComponent),
			trophy = self:Get(basePath .. "/奖杯", ViewComponent),
			countLabel = self:Get(basePath .. "/数量", ViewComponent),
			currentUserId = nil,
			avatarNode = nil,
		}
	end

	-- 按钮
	self.doubleTrainingButton = self:Get("底图/双倍训练", ViewButton)
	self.leaveRaceButton = self:Get("底图/离开比赛", ViewButton)
	self.leaveAfkButton = self:Get("底图/离开挂机", ViewButton)
	self.leaveAfkButton:SetVisible(false) -- 默认隐藏


	-- 速度显示
	self.speedPointer = self:Get("底图/速度指针", ViewComponent)
	self.speedDashboard = self:Get("底图/速度仪表盘", ViewComponent)
    self.speedDashboard:SetVisible(false)
    self.leaveRaceButton:SetVisible(false)
    self.speedPointer:SetVisible(false)
	self.speedLabels = {}
	for i = 1, 5 do
		local speedLabelPath = "底图/速度仪表盘/速度" .. i
		self.speedLabels["速度"..i] = self:Get(speedLabelPath, ViewComponent)
	end
end

-- 数据初始化
function TournamentSc:InitData()
	-- 用于存储比赛相关数据
	self.raceTime = 0
	self.elapsedTime = 0
	self.remainingTime = 0
	self.playerAvatars = {} -- uin -> avatarNode
	self.currentPlayerDistance = 0 -- 当前玩家飞行距离
	
	-- 【新增】客户端飞行距离追踪数据
	self.clientFlightData = {} -- userId -> FlightData
	self.clientStartPositions = {} -- userId -> Vector3
	self.distanceUpdateTimer = nil -- 距离更新定时器
end

-- 事件注册
function TournamentSc:RegisterEvents()
	--gg.log("注册比赛系统事件监听")

	-- 比赛界面显示
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_CONTEST_SHOW, function(data)
		self:OnContestShow(data)
	end)

	-- 比赛发射事件（比赛开始时触发，含玩家变量数据）
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.LAUNCH_PLAYER, function(data)
        if data.gameMode == EventPlayerConfig.GAME_MODES.RACE_GAME then
            self:OnLaunchPlayer(data)
        end
	end)

	-- 比赛界面更新
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_CONTEST_UPDATE, function(data)
		self:OnContestUpdate(data)
	end)

	-- 比赛界面隐藏
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.RACE_CONTEST_HIDE, function(data)
		self:OnContestHide(data)
	end)
end

-- 按钮事件注册
function TournamentSc:RegisterButtonEvents()
	if self.doubleTrainingButton then
		self.doubleTrainingButton.clickCb = function()
			self:OnClickDoubleTraining()
		end
	end

	if self.leaveRaceButton then
		self.leaveRaceButton.clickCb = function()
			self:OnClickLeaveRace()
		end
	end

	if self.leaveAfkButton then
		self.leaveAfkButton.clickCb = function()
			self:OnClickLeaveAfk()
		end
	end
end

-- =================================
-- 按钮操作处理
-- =================================

function TournamentSc:OnClickDoubleTraining()
	--gg.log("点击双倍训练按钮")
	-- 在此发送网络请求
end

function TournamentSc:OnClickLeaveRace()
	--gg.log("点击离开比赛按钮")
	-- 发送“玩家落地/结束比赛”事件到服务端，由 RaceGameEventManager 转发给 RaceGameMode
	if gg and gg.network_channel then
		gg.network_channel:fireServer({
			cmd = EventPlayerConfig.REQUEST.PLAYER_LANDED,
			isLanded = true,
			finalState = "ManualExit"
		})
	end

	-- 本地立即收尾：停止定时器并隐藏相关UI
	if self.speedPointerTimer then
		self.speedPointerTimer:Stop()
		self.speedPointerTimer:Destroy()
		self.speedPointerTimer = nil
	end
	self:SetSpeedPointerRotation(-90)
	if self.leaveRaceButton then self.leaveRaceButton:SetVisible(false) end
	if self.speedPointer then self.speedPointer:SetVisible(false) end
	if self.speedDashboard then self.speedDashboard:SetVisible(false) end
	
	-- 【新增】停止客户端飞行距离追踪
	self:StopClientDistanceTracking()
end

function TournamentSc:OnClickLeaveAfk()
	--gg.log("点击离开挂机按钮")
	-- 发送网络请求，通知服务端玩家想离开挂机状态
	if gg and gg.network_channel then
		gg.network_channel:fireServer({
			cmd = EventPlayerConfig.REQUEST.REQUEST_LEAVE_IDLE
		})
	end
end

-- =================================
-- 比赛事件回调
-- =================================

--- 比赛界面显示（来自服务器）
function TournamentSc:OnContestShow(data)
	self.raceTime = data and data.raceTime or 0
	if self.basePanel then
		self.basePanel:SetVisible(true)
	end
	
	-- 【新增】显示距离节点并初始化距离显示
	if self.GmaeDisTop then
		self.GmaeDisTop:SetVisible(true)
		self.currentPlayerDistance = 0
		self:UpdateDistanceDisplay(0)
	end
	
	-- 【新增】在比赛开始时记录所有玩家的起始位置
	self:RecordAllPlayersStartPositions()
	
	-- 【新增】启动客户端飞行距离追踪
	self:StartClientDistanceTracking()
end

--- 比赛界面更新（来自服务器）
function TournamentSc:OnContestUpdate(data)
	if not data then return end

	self.raceTime = data.raceTime or self.raceTime
	self.elapsedTime = data.elapsedTime or 0
	self.remainingTime = data.remainingTime or 0

	-- 【已移除】不再使用服务端数据更新玩家进度
	-- 现在完全依赖客户端的实时位置计算来更新UI
end

--- 比赛界面隐藏（来自服务器）
function TournamentSc:OnContestHide(data)
	-- 隐藏比赛相关控件
	if self.leaveRaceButton then
		self.leaveRaceButton:SetVisible(false)
	end
	if self.speedPointer then
		self.speedPointer:SetVisible(false)
	end
	if self.speedDashboard then
		self.speedDashboard:SetVisible(false)
	end

	-- 【新增】隐藏距离节点
	if self.GmaeDisTop then
		self.GmaeDisTop:SetVisible(false)
	end

	-- 可选：停止速度指针定时器
	if self.speedPointerTimer then
		self.speedPointerTimer:Stop()
		self.speedPointerTimer:Destroy()
		self.speedPointerTimer = nil
	end

	-- 【新增】清理所有玩家头像
	for userId, avatarData in pairs(self.playerAvatars) do
		if avatarData and avatarData.node and not avatarData.node.isDestroyed then
			avatarData.node:Destroy()
		end
	end
	self.playerAvatars = {}
	
	-- 【新增】停止客户端飞行距离追踪
	self:StopClientDistanceTracking()
	
	-- 【新增】重置距离数据
	self.currentPlayerDistance = 0
end

--- 接收比赛开始(发射)事件，获取服务端携带的数据（含 variableData）
---@param data table
function TournamentSc:OnLaunchPlayer(data)
    -- --gg.log("比赛发射事件", data)
    self.leaveRaceButton:SetVisible(true)
    self.speedDashboard:SetVisible(true)
    self.speedPointer:SetVisible(true)
	self.lastLaunchData = data or {}
	self.variableData = (data and data.variableData) or {}
	
	-- 【新增】在发射时立即记录所有玩家的起始位置
	local Players = game:GetService("Players")
	local allPlayers = Players:GetPlayers()
	
	gg.log("=== 比赛发射时客户端玩家列表 ===")
	for _, playerActor in ipairs(allPlayers) do
		if playerActor and playerActor.UserId then
			local uin = playerActor.UserId
			gg.log("客户端玩家名称为: " .. tostring(uin))
			
			-- 记录每个玩家的起始位置
			self.clientStartPositions[uin] = playerActor.Position
			self.clientFlightData[uin] = {
				userId = uin,
				startPosition = playerActor.Position,
				currentPosition = playerActor.Position,
				flightDistance = 0,
				isFinished = false
			}
			gg.log(string.format("TournamentSc: 玩家 %s 发射时起始位置已记录", uin))
			
			-- 🚨 新增：立即为每个玩家创建头像，确保所有玩家都能看到
			self:UpdatePlayerAvatarPosition(uin, 0)
		end
	end
	gg.log("=== 玩家列表结束 ===")
	
	-- 可在此根据需要刷新UI或缓存到本地数据系统

	-- 启动速度指针旋转定时器：从 -90 度逐步旋转到 90 度，历时 recoveryDelay
	local duration = tonumber(data and data.recoveryDelay) or 60

	-- 清理旧定时器
	if self.speedPointerTimer then
		self.speedPointerTimer:Stop()
		self.speedPointerTimer:Destroy()
		self.speedPointerTimer = nil
	end

	-- 初始角度设置为 -90
	self:SetSpeedPointerRotation(-90)

	local elapsed = 0
	local interval = 0.1
	self.speedPointerTimer = SandboxNode.New("Timer", game.WorkSpace)
	self.speedPointerTimer.Name = "TournamentSc_SpeedPointerTimer"
	self.speedPointerTimer.Delay = 0
	self.speedPointerTimer.Loop = true
	self.speedPointerTimer.Interval = interval
	self.speedPointerTimer.Callback = function()
		elapsed = elapsed + interval
		local t = math.min(1, elapsed / duration)
		local rotation = -90 + 180 * t
		self:SetSpeedPointerRotation(rotation)
		if elapsed >= duration then
			self.speedPointerTimer:Stop()
			self.speedPointerTimer:Destroy()
			self.speedPointerTimer = nil
			-- 结束时恢复为 -90
			self:SetSpeedPointerRotation(-90)
		end
	end
	self.speedPointerTimer:Start()

	-- 计算并显示战力相关数值到 速度2/3/4/5
	local variableData = self.variableData or {}
	local basePower = tonumber(variableData["数据_固定值_战力值"]) or 100
	
	-- 确保basePower最小值为100
	if basePower < 100 then
		basePower = 100
	end
	
	local A = basePower * 1.5
	local v2 = A * 0.25
	local v3 = A * 0.5
	local v4 = A * 0.75
	local v5 = A
    --gg.log("设置速度标题", self.speedLabels )

	local function setSpeedTitle(index, value)
		local comp = self.speedLabels[index]
        --gg.log("设置速度标题", index, value,comp,comp.node,comp.node.Title )
		if comp and comp.node and comp.node.Title ~= nil then
			comp.node.Title = gg.FormatLargeNumber(math.floor(value + 0.5))
		end
	end

	setSpeedTitle("速度2", v2)
	setSpeedTitle("速度3", v3)
	setSpeedTitle("速度4", v4)
	setSpeedTitle("速度5", v5)
end

--- 设置速度指针旋转角度
---@param angle number 角度（度）
function TournamentSc:SetSpeedPointerRotation(angle)
	if not self.speedPointer or not self.speedPointer.node then return end
	if self.speedPointer.node.Rotation ~= nil then
		self.speedPointer.node.Rotation = angle
	end
end

--- 设置"离开挂机"按钮的可见性
---@param visible boolean
function TournamentSc:SetAfkButtonVisible(visible)
    if self.leaveAfkButton then
        self.leaveAfkButton:SetVisible(visible)
    end
end

--- 【新增】更新距离显示
---@param distance number 飞行距离
function TournamentSc:UpdateDistanceDisplay(distance)
    if not self.GmaeDisTop or not self.GmaeDisTop.node then 
        return 
    end
    
    -- 更新UI显示
    if self.GmaeDisTop.node.Title ~= nil then
        self.GmaeDisTop.node.Title = gg.FormatLargeNumber(math.floor(distance + 0.5))
    end
end

--- 【新增】记录所有玩家的起始位置
function TournamentSc:RecordAllPlayersStartPositions()
    local Players = game:GetService("Players")
    local allPlayers = Players:GetPlayers()
    
    gg.log("=== 比赛开始时记录所有玩家起始位置 ===")
    for _, playerActor in ipairs(allPlayers) do
        if playerActor and playerActor.UserId then
            local uin = playerActor.UserId
            
            -- 记录每个玩家的起始位置
            self.clientStartPositions[uin] = playerActor.Position
            self.clientFlightData[uin] = {
                userId = uin,
                startPosition = playerActor.Position,
                currentPosition = playerActor.Position,
                flightDistance = 0,
                isFinished = false
            }
            gg.log(string.format("TournamentSc: 玩家 %s 起始位置已记录", uin))
            
            -- 🚨 新增：立即为每个玩家创建头像，确保所有玩家都能看到
            self:UpdatePlayerAvatarPosition(uin, 0)
        end
    end
    gg.log("=== 起始位置记录完成 ===")
end

--- 【新增】启动客户端飞行距离追踪
function TournamentSc:StartClientDistanceTracking()
    if self.distanceUpdateTimer then
        self:StopClientDistanceTracking()
    end
    
    -- 每0.2秒更新一次飞行距离（与服务端同步）
    self.distanceUpdateTimer = SandboxNode.New("Timer", game.WorkSpace)
    self.distanceUpdateTimer.Name = "TournamentSc_DistanceTimer"
    self.distanceUpdateTimer.Delay = 0
    self.distanceUpdateTimer.Loop = true
    self.distanceUpdateTimer.Interval = 0.1
    self.distanceUpdateTimer.Callback = function()
        self:UpdateClientFlightDistances()
    end
    self.distanceUpdateTimer:Start()
    
    gg.log("TournamentSc: 启动客户端飞行距离追踪")
end

--- 【新增】停止客户端飞行距离追踪
function TournamentSc:StopClientDistanceTracking()
    if self.distanceUpdateTimer then
        self.distanceUpdateTimer:Stop()
        self.distanceUpdateTimer:Destroy()
        self.distanceUpdateTimer = nil
    end
    
    -- 清理飞行数据
    self.clientFlightData = {}
    self.clientStartPositions = {}
    
    gg.log("TournamentSc: 停止客户端飞行距离追踪")
end

--- 【新增】更新客户端飞行距离（基于所有比赛玩家的位置实时更新UI）
function TournamentSc:UpdateClientFlightDistances()
    -- 获取所有客户端玩家
    local Players = game:GetService("Players")
    local allPlayers = Players:GetPlayers()
    
    -- 遍历所有玩家，更新比赛进度UI
    for _, playerActor in ipairs(allPlayers) do
        if playerActor and playerActor.UserId then
            local uin = playerActor.UserId
            
            -- 检查是否有起始位置记录
            if not self.clientStartPositions[uin] then
                -- 记录起始位置
                self.clientStartPositions[uin] = playerActor.Position
                -- 初始化飞行数据
                self.clientFlightData[uin] = {
                    userId = uin,
                    startPosition = playerActor.Position,
                    currentPosition = playerActor.Position,
                    flightDistance = 0,
                    isFinished = false
                }
                gg.log(string.format("TournamentSc: 玩家 %s 起始位置已记录", uin))
            end
            
            local flightData = self.clientFlightData[uin]
            if not flightData then
                -- 🚨 修复：如果flightData不存在，跳过这个玩家，而不是整个方法返回
                gg.log(string.format("TournamentSc: 警告 - 玩家 %s 的飞行数据不存在，跳过", uin))
                goto continue
            end
            
            if flightData.isFinished then
                -- 🚨 修复：如果玩家已完成，跳过这个玩家，而不是整个方法返回
                goto continue
            end
            
            -- 获取当前位置
            local currentPos = playerActor.Position
            if currentPos then
                flightData.currentPosition = currentPos
                
                -- 计算从起始位置到当前位置的距离
                local startPos = flightData.startPosition
                local distance = self:CalculateDistance(currentPos, startPos)
                
                -- 更新飞行距离（只增不减，取最大值）
                if distance then
                    local oldDistance = flightData.flightDistance
                    flightData.flightDistance = math.max(flightData.flightDistance, distance)
                    
                    -- 🚨 修复：无论距离是否变化，都要更新UI显示
                    -- 确保所有玩家的头像都能正确显示和更新
                    self:UpdatePlayerAvatarPosition(uin, flightData.flightDistance)
                    
                    -- 如果是本地玩家，更新距离显示
                    local localPlayer = gg.getClientLocalPlayer()
                    if localPlayer and localPlayer.UserId == uin then
                        self.currentPlayerDistance = flightData.flightDistance
                        self:UpdateDistanceDisplay(flightData.flightDistance)
                        
                        -- 调试日志（每1000米左右记录一次）
                        if flightData.flightDistance % 1000 < 100 then
                            gg.log(string.format("TournamentSc: 本地玩家 %s 飞行距离更新: %.1f米", uin, flightData.flightDistance))
                        end
                    end
                    
                    -- 🚨 新增：为所有玩家记录距离更新日志（调试用）
                    if flightData.flightDistance > oldDistance then
                        gg.log(string.format("TournamentSc: 玩家 %s 飞行距离更新: %.1f米 -> %.1f米", 
                            uin, oldDistance, flightData.flightDistance))
                    end
                end
            end
            
            ::continue::
        end
    end
end

--- 【新增】计算两个Vector3之间的距离（复制自RaceGameMode）
---@param pos1 Vector3 位置1
---@param pos2 Vector3 位置2
---@return number|nil 距离值，失败时返回nil
function TournamentSc:CalculateDistance(pos1, pos2)
    if not pos1 or not pos2 then
        return nil
    end
    
    -- 使用VectorUtils模块的距离计算方法（与服务端保持一致）
    local success, distance = pcall(function()
        return VectorUtils.Vec.Distance3(pos1, pos2)
    end)
    
    if success and type(distance) == "number" then
        return distance
    else
        -- 静默处理错误，避免日志干扰
        return nil
    end
end

--- 【新增】重置玩家飞行数据
---@param userId number 玩家ID
function TournamentSc:ResetPlayerFlightData(userId)
    if userId then
        self.clientFlightData[userId] = nil
        self.clientStartPositions[userId] = nil
    else
        -- 重置所有玩家数据
        self.clientFlightData = {}
        self.clientStartPositions = {}
    end
    self.currentPlayerDistance = 0
end

-- 【已移除】UpdatePlayerProgress 方法不再使用
-- 现在完全依赖客户端的实时位置计算来更新玩家头像位置

--- 【新增】根据飞行距离确定玩家应该在哪个进度条（支持循环）
---@param distance number 飞行距离
---@return number 进度条编号 (1-3)
function TournamentSc:GetProgressBarByDistance(distance)
    -- 计算当前循环周期（每10万米为一个周期）
    local cycle = math.floor(distance / 100000)
    -- 计算当前周期内的相对距离
    local relativeDistance = distance % 100000
    
    if relativeDistance <= 30000 then
        return 1
    elseif relativeDistance <= 50000 then
        return 2
    else
        return 3
    end
end

--- 【新增】计算玩家在当前进度条上的位置百分比（支持循环）
---@param distance number 飞行距离
---@param progressBarIndex number 进度条编号
---@return number 位置百分比 (0-1)
function TournamentSc:CalculatePositionPercentage(distance, progressBarIndex)
    -- 计算当前循环周期内的相对距离
    local relativeDistance = distance % 100000
    
    if progressBarIndex == 1 then
        -- 进度条1: 0-30000
        return math.min(1, relativeDistance / 30000)
    elseif progressBarIndex == 2 then
        -- 进度条2: 30000-50000
        return math.min(1, (relativeDistance - 30000) / 20000)
    else
        -- 进度条3: 50000-100000
        return math.min(1, (relativeDistance - 50000) / 50000)
    end
end

--- 【新增】更新玩家头像位置（支持循环进度条）
---@param userId number 玩家ID
---@param distance number 飞行距离
function TournamentSc:UpdatePlayerAvatarPosition(userId, distance)
    if not userId then return end

    -- 确定应该在哪个进度条
    local targetProgressBar = self:GetProgressBarByDistance(distance)
    
    -- 查找玩家当前的头像
    local currentAvatar = self.playerAvatars[userId]
    
    -- 如果玩家头像不存在或需要切换进度条，创建新头像
    if not currentAvatar or currentAvatar.progressBarIndex ~= targetProgressBar then
        self:CreatePlayerAvatar(userId, targetProgressBar)
        currentAvatar = self.playerAvatars[userId]
    end
    
    if not currentAvatar then return end
    
    -- 计算位置百分比
    local positionPercent = self:CalculatePositionPercentage(distance, targetProgressBar)
    
    -- 更新头像位置
    self:UpdateAvatarXPosition(currentAvatar, positionPercent)
end

--- 【新增】创建玩家头像
---@param userId number 玩家ID
---@param progressBarIndex number 进度条编号
function TournamentSc:CreatePlayerAvatar(userId, progressBarIndex)
    -- 清理旧头像
    if self.playerAvatars[userId] then
        if self.playerAvatars[userId].node and not self.playerAvatars[userId].node.isDestroyed then
            self.playerAvatars[userId].node:Destroy()
        end
        self.playerAvatars[userId] = nil
    end
    
    -- 获取对应的头像模板
    local avatarTemplate
    if progressBarIndex == 1 then 
        avatarTemplate = self.GameUserMag1
    elseif progressBarIndex == 2 then 
        avatarTemplate = self.GameUserMag2
    elseif progressBarIndex == 3 then 
        avatarTemplate = self.GameUserMag3
    end
    
    if not avatarTemplate or not avatarTemplate.node then
        --gg.log("警告: 找不到进度条 " .. progressBarIndex .. " 的头像模板")
        return
    end
    
    -- 获取玩家头像节点
    local headNode = self.CoreUI:GetHeadNode(tostring(userId))
    if not headNode then 
        --gg.log("警告: 无法获取玩家头像，userId: " .. tostring(userId))
        return 
    end
    
    -- 设置头像属性
    headNode.Parent = avatarTemplate.node.Parent
    headNode.Position = avatarTemplate.node.Position
    headNode.Size = avatarTemplate.node.Size
    headNode.Pivot = avatarTemplate.node.Pivot
    headNode.Visible = true
    
    -- 获取进度条容器大小
    local progressBar = self.progressBars[progressBarIndex]
    local progressBarSize = 0
    if progressBar and progressBar.container and progressBar.container.node then
        progressBarSize = progressBar.container.node.Size.x
    end
    
    -- 保存头像信息
    self.playerAvatars[userId] = {
        node = headNode,
        progressBarIndex = progressBarIndex,
        progressBarSize = progressBarSize,
        basePosition = headNode.Position
    }
    
    -- 隐藏模板
    avatarTemplate:SetVisible(false)
end

--- 【新增】更新头像X轴位置
---@param avatarData table 头像数据
---@param positionPercent number 位置百分比 (0-1)
function TournamentSc:UpdateAvatarXPosition(avatarData, positionPercent)
    if not avatarData or not avatarData.node or avatarData.node.isDestroyed then
        return
    end
    
    -- 计算新的X位置
    local moveDistance = avatarData.progressBarSize * positionPercent
    local basePos = avatarData.basePosition
    
    -- UI节点使用Vector2而不是Vector3
    local newPosition = Vector2.new(
        basePos.x + moveDistance,
        basePos.y
    )
    
    -- 更新位置
    avatarData.node.Position = newPosition
end

-- =================================
-- UI刷新方法（本地辅助）
-- =================================



--- 更新速度显示（保留示例接口）
-- @param data table 速度数据, 例如: { speed = 150 }
function TournamentSc:OnUpdateSpeed(data)
	if not data or not data.speed then return end
	-- 根据速度数据更新速度指针和仪表盘文本
end


-- =================================
-- 界面生命周期
-- =================================

function TournamentSc:OnOpen()
	--gg.log("比赛UI打开")
	self.basePanel:SetVisible(true)
end

function TournamentSc:OnClose()
	--gg.log("比赛UI关闭")
	self.basePanel:SetVisible(false)
end

return TournamentSc.New(script.Parent, uiConfig)