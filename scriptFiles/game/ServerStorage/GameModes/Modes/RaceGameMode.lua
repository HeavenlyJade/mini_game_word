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
    self.playerStates = {} -- 存储玩家原始状态， key: uin, value: { originalGravity, flyTimer, originalSpeed }
    self.rules = rules or {}
end

--- 当有玩家进入此游戏模式时调用
---@param player MPlayer
function RaceGameMode:OnPlayerEnter(player)
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

    -- 停止飞行并恢复状态
    self:StopFly(player)

    for i, p in ipairs(self.participants) do
        if p.uin == player.uin then
            table.remove(self.participants, i)
            gg.log(string.format("玩家 %s 已离开比赛。剩余人数: %d", player.name, #self.participants))
            break -- 找到并移除后即可退出循环
        end
    end
end

--- 为指定玩家开启飞行模式
---@param player MPlayer
function RaceGameMode:StartFly(player)
    local actor = player.actor ---@type Actor
    if not actor then
        gg.log(string.format("ERROR: 无法为玩家 %s 开启飞行模式，因为找不到其 Actor", player.name))
        return
    end

    -- 保存原始状态
    local originalGravity = actor.Gravity
    local originalSpeed = actor.Movespeed
    self.playerStates[player.uin] = {
        originalGravity = originalGravity,
        originalSpeed = originalSpeed,
        flyTimer = nil
    }
    
    -- 设置无重力并提升速度
    actor.Gravity = 0
    actor.Movespeed = originalSpeed * FLY_SPEED_FACTOR
    gg.log(string.format("玩家 %s 的重力已设为0，速度提升至 %s，开启飞行模式。", player.name, tostring(actor.Movespeed)))
    
    -- 启动持续推进的定时器
    local timer = self:AddInterval(FLY_UPDATE_INTERVAL, function()
        if player.isDestroyed or not player.actor then
            -- 如果玩家或actor已失效，清除定时器
            self:StopFly(player)
            return
        end
        -- 给予一个持续的、基于摄像机朝向的向前推力
        player.actor:Move(Vector3.new(0, 0, 1), true)
    end)
    
    self.playerStates[player.uin].flyTimer = timer
end

--- 为指定玩家关闭飞行模式
---@param player MPlayer
function RaceGameMode:StopFly(player)
    if not player or not self.playerStates[player.uin] then return end

    local state = self.playerStates[player.uin]
    local actor = player.actor

    -- 恢复重力和速度
    if actor then
        actor.Gravity = state.originalGravity
        actor.Movespeed = state.originalSpeed
        actor:StopMove() -- 显式停止移动
        gg.log(string.format("玩家 %s 的重力已恢复为 %s，速度恢复为 %s。", player.name, tostring(state.originalGravity), tostring(state.originalSpeed)))
    end

    -- 停止飞行定时器
    if state.flyTimer then
        self:RemoveTimer(state.flyTimer)
        gg.log(string.format("已停止玩家 %s 的飞行定时器。", player.name))
    end
    
    -- 清理状态记录
    self.playerStates[player.uin] = nil
end

--- 开始比赛
function RaceGameMode:Start()
    if self.state ~= RaceState.WAITING then return end

    local prepareTime = self.rules["准备时间"] or 10
    local raceTime = self.rules["比赛时长"] or 60

    gg.log(string.format("比赛将在 %d 秒后开始...", prepareTime))
    
    -- 准备阶段
    self:AddDelay(prepareTime, function()
        -- 倒计时结束后
        self.state = RaceState.RACING
        gg.log("比赛开始！")

        -- 为所有参赛者开启飞行模式
        for _, player in ipairs(self.participants) do
            self:StartFly(player)
        end

        -- 模拟比赛持续
        gg.log(string.format("比赛将持续 %d 秒。", raceTime))
        self:AddDelay(raceTime, function()
            self:End()
        end)
    end)
end

--- 结束比赛
function RaceGameMode:End()
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