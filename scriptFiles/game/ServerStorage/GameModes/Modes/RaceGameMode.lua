local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)  ---@type ClassMgr
local GameModeBase = require(ServerStorage.GameModes.GameModeBase) ---@type GameModeBase
local MPlayer             = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class RaceGameMode: GameModeBase
---@field participants MPlayer[]
---@field rules table
---@field handlerId string 触发此模式的场景处理器的ID
---@field checkTimer any 定时器句柄，用于检测比赛结束条件
---@field raceHasTrulyStarted boolean 标记比赛是否已真正开始（即，有玩家被检测到离地）
local RaceGameMode = ClassMgr.Class("RaceGameMode", GameModeBase)

-- 比赛状态
local RaceState = {
    WAITING = "WAITING",     -- 等待玩家加入
    RACING = "RACING",       -- 比赛进行中
    FINISHED = "FINISHED",   -- 比赛已结束
}

-- 飞行参数
local FLY_UPDATE_INTERVAL = 0.1 -- 每0.1秒更新一次飞行状态
local FLY_SPEED_FACTOR = 1.5 -- 飞行速度是默认速度的1.5倍

function RaceGameMode:OnInit(instanceId, modeName, rules)
    self.state = RaceState.WAITING
    self.participants = {} -- 存放所有参赛玩家的table, 使用数组形式
    self.rules = rules or {}
    self.checkTimer = nil -- 初始化定时器句柄
    self.raceHasTrulyStarted = false -- 【新增】用于标记比赛是否已正式开始（有玩家离地）
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
    local actor = player.actor ---@type Actor
    if not actor then
        gg.log(string.format("ERROR: 无法为玩家 %s 发射，因为找不到其 Actor", player.name))
        return
    end

    gg.log(string.format("LaunchPlayer: 正在向客户端 %s 发送跳跃指令...", player.name))
    player:SendEvent("S2C_Player_Jump")
    gg.log(string.format("玩家 %s 的跳跃指令已发送！", player.name))
end

--- 新增：检测比赛结束条件
function RaceGameMode:CheckRaceEndCondition()
    if self.state ~= RaceState.RACING then
        -- 如果比赛状态异常，则停止计时器
        if self.checkTimer then
            self:RemoveTimer(self.checkTimer)
            self.checkTimer = nil
        end
        return
    end

    if #self.participants == 0 then
        gg.log("所有玩家都已离开，比赛提前结束。")
        self:End()
        return
    end

    local allLanded = true
    for _, player in ipairs(self.participants) do
        if player.actor and player.actor.IsOnGround == false then
            -- 只要还有一个玩家在空中，比赛就继续
            allLanded = false
            -- 【核心修正】一旦检测到有玩家离地，就将比赛标记为"已真正开始"
            self.raceHasTrulyStarted = true
            break -- 只要有一个人在空中，就无需再检查其他人
        end
    end

    -- 【核心修正】结束条件变为：比赛必须真正开始过，并且现在所有人都已落地。
    if self.raceHasTrulyStarted and allLanded then
        gg.log("所有玩家均已落地，比赛结束！")
        self:End() -- 调用结束函数
    end
end


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

            -- 【核心改造】启动双重结束条件
            
            -- 条件1: 循环检测所有玩家是否落地
            gg.log("比赛已开始，正在监测玩家落地状态...")
            if self.checkTimer then self:RemoveTimer(self.checkTimer) end
            self.checkTimer = self:AddInterval(0.2, function()
                self:CheckRaceEndCondition()
            end)

            -- 条件2: 比赛到达最大时长后强制结束（超时保护）
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
    -- 【核心改造】在函数开始时，立刻停止循环检测的定时器
    if self.checkTimer then
        self:RemoveTimer(self.checkTimer)
        self.checkTimer = nil
        gg.log("已停止比赛结束条件检测。")
    end

    -- 懒加载 GameModeManager 和 ServerDataManager 以避免循环依赖
    local GameModeManager = require(ServerStorage.GameModes.GameModeManager)  ---@type GameModeManager
    local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    if self.state ~= RaceState.RACING then return end
    
    self.state = RaceState.FINISHED
    gg.log("比赛结束！")
    
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
        local handler = ServerDataManager.getSceneNodeHandler(self.handlerId)
        
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