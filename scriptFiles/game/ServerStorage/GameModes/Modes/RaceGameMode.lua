local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)  ---@type ClassMgr
local GameModeBase = require(ServerStorage.GameModes.GameModeBase) ---@type GameModeBase
local MPlayer             = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local VectorUtils = require(MainStorage.Code.Untils.VectorUtils) ---@type VectorUtils
-- 【已移除】不再需要直接引用 ServerEventManager

---@class RaceGameMode: GameModeBase
---@field participants MPlayer[]
---@field levelType LevelType 关卡配置的LevelType实例
---@field handlerId string 触发此模式的场景处理器的ID
---@field finishedPlayers table<number, boolean> 新增：用于记录已完成比赛的玩家 (uin -> true)
---@field flightData table<number, FlightPlayerData> 实时飞行数据 (uin -> FlightPlayerData)
---@field rankings table<number> 按飞行距离排序的玩家uin列表
---@field distanceTimer Timer 距离计算定时器
---@field startPositions table<number, Vector3> 玩家起始位置记录 (uin -> Vector3)
local RaceGameMode = ClassMgr.Class("RaceGameMode", GameModeBase)

-- 比赛状态
local RaceState = {
    WAITING = "WAITING",     -- 等待玩家加入
    RACING = "RACING",       -- 比赛进行中
    FINISHED = "FINISHED",   -- 比赛已结束
}

---@class FlightPlayerData
---@field uin number 玩家UIN
---@field name string 玩家名称
---@field startPosition Vector3 起始位置
---@field currentPosition Vector3 当前位置
---@field flightDistance number 飞行距离
---@field rank number 当前排名
---@field isFinished boolean 是否已完成比赛

function RaceGameMode:OnInit(instanceId, modeName, levelType)
    self.state = RaceState.WAITING
    self.participants = {} -- 存放所有参赛玩家的table, 使用数组形式
    self.levelType = levelType -- 存储完整的LevelType实例
    
    -- 调试信息：显示比赛模式初始化结果
    gg.log(string.format("RaceGameMode 初始化 - 实例ID: %s, 关卡: %s", 
           instanceId, levelType and levelType.name or "无关卡配置"))
    self.finishedPlayers = {} -- 【新增】初始化已完成玩家的记录表
    self.flightData = {} -- 实时飞行数据 (uin -> FlightPlayerData)
    self.rankings = {} -- 按飞行距离排序的玩家uin列表
    self.distanceTimer = nil -- 距离计算定时器
    self.startPositions = {} -- 玩家起始位置记录 (uin -> Vector3)
end

--- 当有玩家进入此游戏模式时调用
---@param player MPlayer
function RaceGameMode:OnPlayerEnter(player)
    -- 【核心修正】检查玩家是否已在比赛中，防止因触发器抖动等问题导致重复加入
    for _, p in ipairs(self.participants) do
        if p.uin == player.uin then
            return -- 如果已存在，则直接返回，不执行任何操作
        end
    end

    -- 注意：这里不再调用父类的 OnPlayerEnter, 因为父类将其作为字典处理
    -- 而比赛模式需要一个有序的列表来决定排名
    table.insert(self.participants, player)

    -- 如果是第一个加入的玩家，可以启动一个定时器开始比赛
    if #self.participants == 1 then
        self:Start()
    end
end

--- 当有玩家离开此游戏模式时调用
--- (重写父类方法，因为这里 participants 是数组)
---@param player MPlayer
function RaceGameMode:OnPlayerLeave(player)
    if not player then return end

    for i, p in ipairs(self.participants) do
        if p.uin == player.uin then
            table.remove(self.participants, i)
            break -- 找到并移除后即可退出循环
        end
    end
end

--- 将玩家发射出去
---@param player MPlayer
function RaceGameMode:LaunchPlayer(player)
    if not player or not player.actor then
        return
    end

    -- 记录玩家起始位置，用于计算飞行距离
    if player.actor and player.actor.Position then
        self.startPositions[player.uin] = player.actor.Position
        -- 初始化飞行数据
        self.flightData[player.uin] = {
            uin = player.uin,
            name = player.name,
            startPosition = player.actor.Position,
            currentPosition = player.actor.Position,
            flightDistance = 0,
            rank = #self.participants, -- 初始排名为最后一名
            isFinished = false
        }
    end

    -- 【规范化】从配置中读取事件名称和参数，避免硬编码
    local eventName = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER
    local launchParams = EventPlayerConfig.GetActionParams(eventName)
    
    -- 获取关卡配置的比赛时长
    local raceTime = self.levelType.raceTime or 60

    local eventData = gg.clone(launchParams) or {} -- 克隆参数表，如果为nil则创建一个新表
    eventData.cmd = eventName
    eventData.gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME
    eventData.gravity = 0
    eventData.recoveryDelay = raceTime  -- 传送关卡配置的比赛时长作为客户端的恢复延迟
    
    -- 【核心改造】通过网络通道向指定客户端发送事件
    if gg.network_channel then
        gg.network_channel:fireClient(player.uin, eventData)
    end
end

--- 【核心改造】处理玩家落地，由 RaceGameEventManager 调用
---@param player MPlayer 已经确认落地并且属于本场比赛的玩家
function RaceGameMode:OnPlayerLanded(player)
    -- 检查该玩家是否已经报告过落地
    if self.finishedPlayers[player.uin] then
        return -- 防止重复处理
    end

    -- 如果比赛已经结束，则不再处理后续的落地事件
    if self.state == RaceState.FINISHED then
        return
    end

    -- 记录该玩家已完成
    self.finishedPlayers[player.uin] = true
    
    -- 标记玩家为已完成状态（用于停止距离计算）
    self:_markPlayerFinished(player.uin)

    -- 【核心修正】手动计算已完成玩家的数量。
    -- 在 Lua 中，对以非连续数字（如uin）为键的 table 使用 '#' 操作符会返回 0，这是一个已知的语言特性。
    local finishedCount = 0
    for _ in pairs(self.finishedPlayers) do
        finishedCount = finishedCount + 1
    end

    -- 获取玩家当前排名信息
    local flightData = self:GetPlayerFlightData(player.uin)
    local rankInfo = flightData and string.format("第%d名，飞行距离%.1f米", flightData.rank, flightData.flightDistance) or "排名计算中"
    
    player:SendHoverText(string.format("已落地！%s 等待其他玩家...", rankInfo))

    -- 使用正确的计数值检查是否所有人都已完成
    if finishedCount >= #self.participants then
        self:End()
    end
end

--- 【移除】旧的比赛结束检测函数，该功能已被事件驱动的 OnPlayerLanded 取代
-- function RaceGameMode:CheckRaceEndCondition() ... end


--- 开始比赛
function RaceGameMode:Start()
    if self.state ~= RaceState.WAITING then return end

    -- 从LevelType实例获取玩法规则
    local prepareTime = self.levelType.prepareTime or 10
    
    -- 准备阶段
    self:AddDelay(prepareTime, function()
        if self.state == RaceState.WAITING then
            self.state = RaceState.RACING
            gg.log("比赛开始准备！")

            -- 1. 先传送所有玩家到传送节点
            local teleportSuccess = self:TeleportAllPlayersToStartPosition()
            
            if teleportSuccess then
                -- 2. 给传送一点时间完成，然后发射玩家
                self:AddDelay(0.5, function()
                    gg.log("传送完成，开始发射玩家！")
                    for _, player in ipairs(self.participants) do
                        self:LaunchPlayer(player)
                    end
                    -- 启动实时飞行距离计算
                    self:_startFlightDistanceTracking()
                end)
            else
                gg.log("传送失败，直接开始比赛")
                -- 如果传送失败，直接发射（保持向后兼容）
                for _, player in ipairs(self.participants) do
                    self:LaunchPlayer(player)
                end
                self:_startFlightDistanceTracking()
            end
        end
    end)
end

--- 结束比赛
function RaceGameMode:End()
    if self.state ~= RaceState.RACING then return end
    self.state = RaceState.FINISHED

    -- 懒加载 GameModeManager 和 ServerDataManager 以避免循环依赖
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager  ---@type GameModeManager
    
    gg.log("比赛结束！")

    -- 停止实时飞行距离追踪
    self:_stopFlightDistanceTracking()
    
    -- 最终排名确认（基于实际飞行距离）
    self:_updateRankings()
    
    -- 结算基础奖励和排名奖励
    self:_calculateAndDistributeRewards()
    
    -- 打印基础的结算信息，并通知玩家（按真实排名顺序）
    for _, uin in ipairs(self.rankings) do
        local flightData = self.flightData[uin]
        if flightData then
            local rankText = string.format("第 %d 名: %s (%.1f米)", 
                                          flightData.rank, flightData.name, flightData.flightDistance)
            
            -- 找到对应的玩家实例发送消息
            for _, player in ipairs(self.participants) do
                if player.uin == uin then
                    player:SendHoverText(rankText)
                    break
                end
            end
        end
    end

    -- 使用关卡配置的准备时间作为结算展示时长，之后清理实例
    local cleanupDelay = self.levelType.prepareTime or 10

    self:AddDelay(cleanupDelay, function()
        -- 1. 传送所有玩家
        self:_teleportAllPlayersToRespawn()

        -- 2. 将所有玩家从比赛模式中移除
        if GameModeManager then
            -- 必须从后往前遍历，因为 RemovePlayerFromCurrentMode 可能会修改 self.participants
            for i = #self.participants, 1, -1 do
                local p = self.participants[i]
                if p then
                    GameModeManager:RemovePlayerFromCurrentMode(p)
                end
            end
        end
        
        -- 确保停止所有定时任务
        self:_stopFlightDistanceTracking()
    end)
end

--- 【简化】传送所有参赛者到复活点（使用基类方法）
function RaceGameMode:_teleportAllPlayersToRespawn()
    return self:TeleportAllPlayersToRespawn()
end

--- 【核心重构】计算并发放奖励，直接使用 LevelType 实例
function RaceGameMode:_calculateAndDistributeRewards()
    if not self.levelType then
        gg.log("错误: [RaceGameMode] 关卡实例(levelType)为空，无法发放奖励。")
        return
    end
    
    gg.log(string.format("信息: [RaceGameMode] 开始计算奖励，参与玩家数: %d", #self.participants))
    
    -- 按照真实排名顺序处理奖励
    for _, uin in ipairs(self.rankings) do
        local flightData = self.flightData[uin]
        if flightData then
            local player = self:GetPlayerByUin(uin)
            
            if player then
                -- 准备要传递给 LevelType 计算方法的数据
                local playerData = {
                    rank = flightData.rank,
                    distance = flightData.flightDistance,
                    playerName = flightData.name,
                    uin = flightData.uin
                }
                
                gg.log(string.format("信息: [RaceGameMode] 开始为玩家 %s (第%d名) 计算奖励...", playerData.playerName, playerData.rank))
                
                -- 1. 计算并分发基础奖励
                local baseRewards = self.levelType:CalculateBaseRewards(playerData)
                if baseRewards and next(baseRewards) then
                    gg.log(" -> 开始发放基础奖励...")
                    for itemName, amount in pairs(baseRewards) do
                        if amount > 0 then
                            gg.log(string.format("    - 基础奖励: %s x%d", itemName, amount))
                            self:_giveItemToPlayer(player, itemName, amount)
                        end
                    end
                else
                    gg.log(" -> 无基础奖励可发放。")
                end
                
                -- 2. 获取并分发排名奖励
                local rankRewards = self.levelType:GetRankRewards(playerData.rank)
                if rankRewards and #rankRewards > 0 then
                    gg.log(" -> 开始发放排名奖励...")
                    for _, rewardItem in ipairs(rankRewards) do
                        local itemName = rewardItem["物品"]
                        local amount = rewardItem["数量"]
                        if itemName and amount and amount > 0 then
                            gg.log(string.format("    - 排名奖励: %s x%d", itemName, amount))
                            self:_giveItemToPlayer(player, itemName, amount)
                        end
                    end
                else
                    gg.log(string.format(" -> 玩家 %s (第%d名) 无排名奖励可发放。", playerData.playerName, playerData.rank))
                end
            else
                gg.log(string.format("警告: [RaceGameMode] 未找到 UIN %d 对应的玩家实例，无法发放奖励。", uin))
            end
        end
    end
end

--- 【新增】给玩家发放物品
---@param player MPlayer
---@param itemName string 物品名称
---@param amount number 物品数量
function RaceGameMode:_giveItemToPlayer(player, itemName, amount)
    if not player or not itemName or amount <= 0 then
        gg.log(string.format("RaceGameMode: 发放物品失败，参数无效 - player: %s, itemName: %s, amount: %s", 
               tostring(player), tostring(itemName), tostring(amount)))
        return
    end
    
    gg.log(string.format("RaceGameMode: 尝试给玩家 %s 发放物品 %s x%d", player.name or "未知", itemName, amount))
    
    -- 这里集成背包系统来发放物品
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local BagMgr = serverDataMgr.BagMgr
    
    if BagMgr and BagMgr.AddItem then
        local success = BagMgr.AddItem(player, itemName, amount)
        if success then
            gg.log(string.format("RaceGameMode: 物品发放成功 - %s x%d", itemName, amount))
            -- 向玩家发送奖励通知
            player:SendHoverText(string.format("获得 %s x%d", itemName, amount))
        else
            gg.log(string.format("RaceGameMode: 物品发放失败 - %s x%d", itemName, amount))
        end
    else
        gg.log("RaceGameMode: 背包系统不可用，发送提示消息")
        -- 如果背包系统不可用，至少给玩家发送提示
        player:SendHoverText(string.format("应获得 %s x%d (系统暂不可用)", itemName, amount))
    end
end

--- 【新增】启动实时飞行距离追踪
function RaceGameMode:_startFlightDistanceTracking()
    if self.distanceTimer then
        self:RemoveTimer(self.distanceTimer)
    end
    
    -- 每0.5秒更新一次飞行距离和排名
    self.distanceTimer = self:AddInterval(0.5, function()
        self:_updateFlightDistances()
        self:_updateRankings()
    end)
end

--- 【新增】停止实时飞行距离追踪
function RaceGameMode:_stopFlightDistanceTracking()
    if self.distanceTimer then
        self:RemoveTimer(self.distanceTimer)
        self.distanceTimer = nil
    end
end

--- 【新增】更新所有玩家的飞行距离
function RaceGameMode:_updateFlightDistances()
    -- 只在比赛进行中才更新距离
    if self.state ~= RaceState.RACING then
        return
    end
    
    for _, player in ipairs(self.participants) do
        if player and player.actor and self.flightData[player.uin] then
            local flightData = self.flightData[player.uin]
            
            -- 只处理未完成的玩家
            if not flightData.isFinished then
                -- 获取当前位置
                local currentPos = player.actor.Position
                if currentPos then
                    flightData.currentPosition = currentPos
                    
                    -- 计算从起始位置到当前位置的距离
                    local startPos = flightData.startPosition
                    local distance = self:_calculateDistance(currentPos, startPos)
                    
                    -- 更新飞行距离（只增不减，取最大值）
                    if distance then
                        flightData.flightDistance = math.max(flightData.flightDistance, distance)
                    end
                end
            end
        end
    end
end

--- 【新增】根据飞行距离更新排名
function RaceGameMode:_updateRankings()
    -- 创建一个包含所有玩家飞行数据的临时表
    local playerList = {}
    for uin, flightData in pairs(self.flightData) do
        table.insert(playerList, flightData)
    end
    
    -- 按飞行距离降序排序（距离越远排名越高）
    table.sort(playerList, function(a, b)
        return a.flightDistance > b.flightDistance
    end)
    
    -- 更新排名和rankings列表
    self.rankings = {}
    for i, flightData in ipairs(playerList) do
        flightData.rank = i
        table.insert(self.rankings, flightData.uin)
    end
end

--- 【新增】获取玩家当前排名信息
---@param uin number 玩家UIN
---@return FlightPlayerData|nil
function RaceGameMode:GetPlayerFlightData(uin)
    return self.flightData[uin]
end

--- 【新增】根据UIN获取玩家实例
---@param uin number
---@return MPlayer|nil
function RaceGameMode:GetPlayerByUin(uin)
    for _, p in ipairs(self.participants) do
        if p.uin == uin then
            return p
        end
    end
    return nil
end

--- 【新增】获取当前排名列表
---@return table<number> 按排名顺序的玩家UIN列表
function RaceGameMode:GetCurrentRankings()
    return self.rankings
end

--- 【新增】标记玩家为已完成状态
---@param uin number 玩家UIN
function RaceGameMode:_markPlayerFinished(uin)
    if self.flightData[uin] then
        self.flightData[uin].isFinished = true
    end
end

--- 【简化】计算两个Vector3之间的距离
---@param pos1 Vector3 位置1
---@param pos2 Vector3 位置2
---@return number|nil 距离值，失败时返回nil
function RaceGameMode:_calculateDistance(pos1, pos2)
    if not pos1 or not pos2 then
        return nil
    end
    
    -- 【更新】使用 VectorUtils 模块的距离计算函数
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

return RaceGameMode