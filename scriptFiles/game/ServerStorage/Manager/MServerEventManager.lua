local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class MServerEventManager
local MServerEventManager = {}

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function MServerEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        --gg.log("背包事件缺少玩家UIN参数")
        return nil
    end

    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("背包事件找不到玩家: " .. uin)
        return nil
    end

    return player
end
-- 私有：向所有在线玩家广播当前房间内玩家列表
local function broadcastRoomPlayers()
    local allPlayers = {}
    for u, _ in pairs(MServerDataManager.server_players_list) do
        table.insert(allPlayers, u)
    end
    for u, _ in pairs(MServerDataManager.server_players_list) do
        gg.network_channel:fireClient(u, {
            cmd = EventPlayerConfig.NOTIFY.ROOM_PLAYERS_BROADCAST,
            players = allPlayers,
        })
    end
end

-- 私有：处理客户端上报好友数量
---@param evt table
function MServerEventManager.handleFriendsCountReport(evt)
    -- evt.player 为环境玩家，evt.count 为好友数量
    local player = MServerEventManager.ValidatePlayer(evt) ---@type MPlayer|nil
    if not player then
        return
    end
    local count = tonumber(evt.count) or 0
    -- 更新玩家在线好友数量
    player.onlineFriendsCount = count
    -- 若需要联动其它逻辑，这里可以触发事件或立即回包
end

--- 初始化事件订阅
function MServerEventManager.Init()
    -- 订阅客户端上报好友数量
    ServerEventManager.Subscribe(EventPlayerConfig.REQUEST.FRIENDS_COUNT_REPORT, function(evt)
        MServerEventManager.handleFriendsCountReport(evt)
    end)

    -- 可按需增加更多与 EventPlayerConfig 相关的服务端事件
end

return MServerEventManager


