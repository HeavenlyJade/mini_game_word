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

function RaceGameMode:OnInit(instanceId, modeName, rules)
    self.state = RaceState.WAITING
    self.participants = {} -- 存放所有参赛玩家的table, 使用数组形式
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

    for i, p in ipairs(self.participants) do
        if p.uin == player.uin then
            table.remove(self.participants, i)
            gg.log(string.format("玩家 %s 已离开比赛。剩余人数: %d", player.name, #self.participants))
            break -- 找到并移除后即可退出循环
        end
    end
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

        -- 模拟比赛持续
        gg.log(string.format("比赛将持续 %d 秒。", raceTime))
        self:AddDelay(raceTime, function()
            self:End()
        end)
    end)
end

--- 结束比赛
function RaceGameMode:End()
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
        
        -- 懒加载 GameModeManager 和 ServerDataManager 以避免循环依赖
        local GameModeManager = require(ServerStorage.GameModes.GameModeManager)
        local ServerDataManager = require(ServerStorage.Manager.MServerDataManager)

        -- 获取触发这个比赛的场景处理器
        local handler = ServerDataManager.getSceneNodeHandler(self.handlerId)
        
        -- 重点：必须创建一个参与者副本进行遍历，因为 RemovePlayerFromCurrentMode 会修改原始的 self.participants 表
        local playersToRemove = {}
        for _, p in ipairs(self.participants) do
            table.insert(playersToRemove, p)
        end
        
        for _, playerInstance in ipairs(playersToRemove) do
            playerInstance:SendHoverText("已离开比赛。")
            GameModeManager:RemovePlayerFromCurrentMode(playerInstance)

            -- 如果找到了处理器，就强制让玩家离开，同步状态
            if handler then
                handler:ForceEntityLeave(playerInstance)
            end
        end
    end)
end

return RaceGameMode