local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

-- 预加载所有可用的游戏模式，以避免在运行时动态require
local AVAILABLE_MODES = {
    ["飞车挑战赛"] = require(ServerStorage.GameModes.Modes.RaceGameMode) ---@type RaceGameMode
    -- 未来如果新增其他模式，在这里添加即可
}

---@class GameModeManager
local GameModeManager = {}

-- 存放当前所有激活的游戏模式实例
-- key 为 instanceId (string), value 为 mode instance (GameModeBase)
GameModeManager.activeModes = {}
-- 记录每个玩家所在的模式实例ID
-- key 为 player.uin (number), value 为 instanceId (string)
GameModeManager.playerModes = {} 

--- 将玩家添加到一个游戏模式中
---@param mPlayer MPlayer 玩家的Entity实例
---@param modeName string 模式的名称 (即模式的文件名, e.g., "RaceGameMode")
---@param instanceId string 此次游戏实例的唯一ID (通常是场景节点的路径或UUID)
---@param gameRules table 具体的游戏规则, 来自LevelConfig
---@param handlerId string 触发此模式的场景处理器的ID
function GameModeManager:AddPlayerToMode(mPlayer, modeName, instanceId, gameRules, handlerId)
    if not mPlayer then
        gg.log("错误: GameModeManager:AddPlayerToMode - 传入了无效的mPlayer实例。")
        return
    end

    -- 检查玩家是否已经在另一场比赛中
    local existingInstanceId = self.playerModes[mPlayer.uin]
    if existingInstanceId and existingInstanceId ~= instanceId then
        gg.log(string.format("警告: 玩家 %s 已在另一场比赛 (%s) 中，无法加入 %s。", mPlayer.name, existingInstanceId, instanceId))
        return
    end

    local mode = self.activeModes[instanceId]

    -- 如果模式实例不存在，则创建并激活它
    if not mode then
        local modeClass = AVAILABLE_MODES[modeName]
        if modeClass then
            mode = modeClass.New(instanceId, modeName, gameRules)
            mode.handlerId = handlerId -- 将处理器ID存入比赛实例中
            self.activeModes[instanceId] = mode
            gg.log(string.format("游戏模式管理器: 已激活新模式'%s'，实例ID为'%s'。", modeName, instanceId))
        else
            gg.log(string.format("错误: 未找到游戏模式'%s'。", modeName))
            return
        end
    end

    -- 将玩家加入到模式中
    mode:OnPlayerEnter(mPlayer)
    self.playerModes[mPlayer.uin] = instanceId
end

--- 从一个游戏模式中移除玩家
---@param mPlayer MPlayer
function GameModeManager:RemovePlayerFromCurrentMode(mPlayer)
    if not mPlayer then return end

    local instanceId = self.playerModes[mPlayer.uin]
    if not instanceId then return end

    local mode = self.activeModes[instanceId]
    if not mode then
        -- 如果找不到mode, 说明可能已经被清理, 直接移除玩家记录
        self.playerModes[mPlayer.uin] = nil
        return
    end

    mode:OnPlayerLeave(mPlayer)    
    self.playerModes[mPlayer.uin] = nil

    -- 检查比赛是否还有玩家, 如果没有了, 则销毁这个实例
    if #mode.participants == 0 then
        mode:Destroy() -- 清理定时器等资源
        self.activeModes[instanceId] = nil
        gg.log(string.format("游戏模式管理器: 实例'%s'已空，已被移除。", instanceId))
        -- 这里可以调用一个 mode:Destroy() 方法来做一些清理工作，如果需要的话
    end
end


-- 监听玩家离开事件，自动将其从模式中移除
game:GetService("Players").PlayerRemoving:Connect(function(player)
    -- 玩家离开时，我们仍然得到的是引擎原生的player对象
    -- 我们需要根据它找到我们的MPlayer实例，然后再调用移除方法
    local mPlayer = MServerDataManager.getPlayerByUin(player.uin)
    if mPlayer then
        GameModeManager:RemovePlayerFromCurrentMode(mPlayer)
    else
        -- 如果此时已经找不到MPlayer实例（可能已被清理），
        -- 我们需要一种备用方式来从比赛中移除该玩家的记录
        local instanceId = GameModeManager.playerModes[player.uin]
        if instanceId then
             GameModeManager.playerModes[player.uin] = nil
             gg.log(string.format("游戏模式管理器: 玩家(UIN: %d)的实例已不存在，但已成功从比赛记录中移除。", player.uin))
        end
    end
end)


return GameModeManager
