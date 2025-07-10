local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)  ---@type ClassMgr
local GameModeBase = require(ServerStorage.GameModes.GameModeBase) ---@type GameModeBase
local MPlayer             = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
-- 【已移除】不再需要直接引用 ServerEventManager

---@class RaceGameMode: GameModeBase
---@field participants MPlayer[]
---@field rules table
---@field handlerId string 触发此模式的场景处理器的ID
---@field finishedPlayers table<number, boolean> 新增：用于记录已完成比赛的玩家 (uin -> true)
local RaceGameMode = ClassMgr.Class("RaceGameMode", GameModeBase)

-- 比赛状态
local RaceState = {
    WAITING = "WAITING",     -- 等待玩家加入
    RACING = "RACING",       -- 比赛进行中
    FINISHED = "FINISHED",   -- 比赛已结束
}



function RaceGameMode:OnInit(instanceId, modeName, rules)
    self.state = RaceState.WAITING
    self.participants = {} -- 存放所有参赛玩家的table, 使用数组形式
    self.rules = rules or {}
    self.finishedPlayers = {} -- 【新增】初始化已完成玩家的记录表
end

--- 当有玩家进入此游戏模式时调用
---@param player MPlayer
function RaceGameMode:OnPlayerEnter(player)
    -- 【核心修正】检查玩家是否已在比赛中，防止因触发器抖动等问题导致重复加入
    for _, p in ipairs(self.participants) do
        if p.uin == player.uin then
            gg.log(string.format("玩家 %s 已在比赛中，忽略重复的加入请求。", player.name))
            return -- 如果已存在，则直接返回，不执行任何操作
        end
    end

    -- 注意：这里不再调用父类的 OnPlayerEnter, 因为父类将其作为字典处理
    -- 而比赛模式需要一个有序的列表来决定排名
    table.insert(self.participants, player)
    gg.log(string.format("玩家 %s 已加入比赛。当前参赛人数: %d", player.name, #self.participants))

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
            gg.log(string.format("玩家 %s 已离开比赛。剩余人数: %d", player.name, #self.participants))
            break -- 找到并移除后即可退出循环
        end
    end
end

--- 将玩家发射出去
---@param player MPlayer
function RaceGameMode:LaunchPlayer(player)
    if not player or not player.actor then
        gg.log(string.format("ERROR: 无法为玩家 %s 发射，因为找不到其 MPlayer 实例或 Actor", tostring(player)))
        return
    end

    gg.log(string.format("LaunchPlayer: 准备向客户端 %s 发送发射指令...", player.name))

    -- 【规范化】从配置中读取事件名称和参数，避免硬编码
    local eventName = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER
    local launchParams = EventPlayerConfig.GetActionParams(eventName)

    -- 【核心修正】将事件名(cmd)和参数合并到一个新的 table 中发送，以匹配网络框架的期望
    local eventData = gg.clone(launchParams) or {} -- 克隆参数表，如果为nil则创建一个新表
    eventData.cmd = eventName
    
    -- 【核心改造】通过网络通道向指定客户端发送事件
    if gg.network_channel then
        gg.network_channel:fireClient(player.uin, eventData)
        gg.log(string.format("LaunchPlayer: 已向玩家 %s (uin: %s) 发送事件，数据: %s", player.name, player.uin, gg.table2str(eventData)))
    else
        gg.log("ERROR: gg.network_channel 未初始化，无法发送客户端事件！")
    end
    
    gg.log(string.format("玩家 %s 的发射指令已发送！", player.name))
end

--- 【核心改造】处理玩家落地，由 RaceGameEventManager 调用
---@param player MPlayer 已经确认落地并且属于本场比赛的玩家
function RaceGameMode:OnPlayerLanded(player)
    -- 检查该玩家是否已经报告过落地
    if self.finishedPlayers[player.uin] then
        gg.log(string.format("玩家 %s 已经报告过落地，忽略重复的 OnPlayerLanded 调用。", player.name))
        return -- 防止重复处理
    end

    -- 记录该玩家已完成
    self.finishedPlayers[player.uin] = true
    gg.log(string.format("比赛实例 %s: 玩家 %s 已完成。当前进度: %d/%d", self.instanceId, player.name, #self.finishedPlayers, #self.participants))
    player:SendHoverText("已落地！等待其他玩家...")

    -- 检查是否所有人都已完成
    if #self.finishedPlayers >= #self.participants then
        gg.log("所有参赛玩家均已落地，比赛立即结束！")
        self:End()
    end
end

--- 【移除】旧的比赛结束检测函数，该功能已被事件驱动的 OnPlayerLanded 取代
-- function RaceGameMode:CheckRaceEndCondition() ... end


--- 开始比赛
function RaceGameMode:Start()
    if self.state ~= RaceState.WAITING then return end

    local prepareTime = self.rules["准备时间"] or 10
    local raceTime = self.rules["比赛时长"] or 60 -- 【恢复】读取比赛时长配置
    
    gg.log(string.format("比赛将在 %d 秒后开始...", prepareTime))
    
    -- 准备阶段
    self:AddDelay(prepareTime, function()
        -- 倒计时结束后
        if self.state == RaceState.WAITING then -- 增加状态检查，防止重复执行
            self.state = RaceState.RACING
            gg.log("比赛开始！")

            -- 将所有参赛者发射出去
            for _, player in ipairs(self.participants) do
                self:LaunchPlayer(player)
            end

            -- 【已移除】事件订阅逻辑已移至 RaceGameEventManager
            gg.log("比赛已开始，等待 RaceGameEventManager 的落地报告...")

            -- 【保留】比赛到达最大时长后强制结束（超时保护）
            gg.log(string.format("比赛最长持续 %d 秒。", raceTime))
            self:AddDelay(raceTime, function()
                if self.state == RaceState.RACING then
                    gg.log("比赛达到最大时长，强制结束！")
                    self:End()
                end
            end)
        end
    end)
end

--- 结束比赛
function RaceGameMode:End()
    if self.state ~= RaceState.RACING then return end
    self.state = RaceState.FINISHED

    -- 【已移除】不再需要取消订阅，因为订阅逻辑已移至外部管理器
    gg.log("比赛实例 %s 正在结束...", self.instanceId)
    
    -- 懒加载 GameModeManager 和 ServerDataManager 以避免循环依赖
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager  ---@type GameModeManager
    
    gg.log("比赛结束！")
    
    -- TODO: 在这里向客户端发送一个结构化的比赛结束事件（如 S2C_RaceFinished），
    -- 而不是仅仅发送悬浮文字，以便客户端可以展示结算UI。
    -- 例如: ServerEventManager.PublishToGroup(participants, "S2C_RaceFinished", { ranks = ... })

    -- 打印基础的结算信息，并通知玩家
    gg.log("--- 比赛结算 ---")
    for i, player in ipairs(self.participants) do
        local rankText = string.format("第 %d 名: %s", i, player.name)
        gg.log(rankText)
        player:SendHoverText(rankText) -- 使用 MPlayer 的方法在屏幕上显示文字
    end
    gg.log("--------------------")

    -- 使用关卡配置的"准备时间"作为结算展示时长，之后清理实例
    local cleanupDelay = self.rules["准备时间"] or 10
    gg.log(string.format("将在 %d 秒后清理比赛实例...", cleanupDelay))

    self:AddDelay(cleanupDelay, function()
        gg.log(string.format("正在清理比赛实例: %s", self.instanceId))
        


        -- 获取触发这个比赛的场景处理器
        local handler = serverDataMgr.getSceneNodeHandler(self.handlerId)
        
        -- 重点：必须创建一个参与者副本进行遍历，因为 RemovePlayerFromCurrentMode 会修改原始的 self.participants 表
        local playersToRemove = {}
        for _, p in ipairs(self.participants) do
            table.insert(playersToRemove, p)
        end
        
        for _, playerInstance in ipairs(playersToRemove) do
            playerInstance:SendHoverText("已离开比赛。")
            -- OnPlayerLeave 会自动调用 StopFly, 所以这里只需要调用 GameModeManager 的移除方法即可
            GameModeManager:RemovePlayerFromCurrentMode(playerInstance)

            -- 如果找到了处理器，就强制让玩家离开，同步状态
            if handler then
                handler:ForceEntityLeave(playerInstance)
            end
        end
    end)
end

return RaceGameMode