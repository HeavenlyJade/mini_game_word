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

-- 私有：处理广告观看完成
---@param evt table
function MServerEventManager.handleAdWatchCompleted(evt)
    -- 打印原始消息类型和内容
    
    -- 解析消息内容
    local msgData = evt.msg
    if type(evt.msg) == "string" then
        -- 尝试将字符串解析为JSON
        local json = require(MainStorage.Code.Untils.json) ---@type json
        local success, parsed = pcall(function()
            return json.decode(evt.msg)
        end)
        
        if success and parsed then
            msgData = parsed
            gg.log("广告观看完成 - 解析后的消息:", msgData)
        else
            gg.log("广告观看完成 - JSON解析失败，使用原始字符串")
        end
    end
    
    -- 打印解析后的消息结构
    gg.log("广告观看完成 - 最终消息类型:", type(msgData))
    gg.log("广告观看完成 - 最终消息内容:", msgData)
    
    -- 检查广告观看结果
    local player = MServerEventManager.ValidatePlayer(evt) ---@type MPlayer|nil
    if not player then
        return
    end
    
    local isSuccess = false
    if type(msgData) == "table" and msgData.result == true then
        isSuccess = true
    elseif type(msgData) == "string" and string.find(msgData, "true") then
        isSuccess = true
    else
        gg.log("广告观看失败，消息格式:", type(msgData), "内容:", msgData,player.name)
        return
    end
    
    -- 增加玩家广告观看次数
    player:AddAdWatchCount(1)
    
    -- 添加临时战力值buff（1分钟，2倍倍率）
    player:AddTempBuff("数据_固定值_战力值", 60, 10)
    gg.log("广告观看完成，为玩家添加临时战力值buff", player.name, "UIN:", player.uin, "倍率: 10", "持续时间: 60秒")
    
    -- 同步广告观看次数到客户端
    MServerEventManager.syncAdWatchCountToClient(player)
    
    gg.log("玩家广告观看完成", player.name, "UIN:", player.uin, "当前观看次数:", player:GetAdWatchCount())
end

-- 私有：同步广告观看次数到客户端
---@param player MPlayer
function MServerEventManager.syncAdWatchCountToClient(player)
    gg.network_channel:fireClient(player.uin, {
        cmd = EventPlayerConfig.NOTIFY.AD_WATCH_COUNT_UPDATE,
        watchCount = player:GetAdWatchCount()
    })
end

--- 初始化事件订阅
function MServerEventManager.Init()
    -- 订阅客户端上报好友数量
    ServerEventManager.Subscribe(EventPlayerConfig.REQUEST.FRIENDS_COUNT_REPORT, function(evt)
        MServerEventManager.handleFriendsCountReport(evt)
    end)
    
    -- 订阅广告观看完成事件
    ServerEventManager.Subscribe(EventPlayerConfig.REQUEST.AD_WATCH_COMPLETED, function(evt)
        MServerEventManager.handleAdWatchCompleted(evt)
    end)

    -- 可按需增加更多与 EventPlayerConfig 相关的服务端事件
end

return MServerEventManager


