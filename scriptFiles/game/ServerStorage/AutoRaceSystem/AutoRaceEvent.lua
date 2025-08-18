-- AutoRaceEvent.lua
-- 自动比赛事件管理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local AutoRaceManager = require(ServerStorage.AutoRaceSystem.AutoRaceManager) ---@type AutoRaceManager
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class AutoRaceEventManager
local AutoRaceEventManager = {}

-- 事件名称定义
AutoRaceEventManager.REQUEST = {
    AUTO_RACE_TOGGLE = "AutoRaceToggle"
}

AutoRaceEventManager.RESPONSE = {
    AUTO_RACE_STATUS = "AutoRaceStatus"
}

AutoRaceEventManager.NOTIFY = {
    AUTO_RACE_STARTED = "AutoRaceStarted",
    AUTO_RACE_STOPPED = "AutoRaceStopped",
    NAVIGATE_TO_POSITION = EventPlayerConfig.NOTIFY.NAVIGATE_TO_POSITION
}

-- 初始化自动比赛事件管理器
function AutoRaceEventManager.Init()
    AutoRaceEventManager.RegisterEventHandlers()
end

-- 注册所有事件处理器
function AutoRaceEventManager.RegisterEventHandlers()
    -- 自动比赛开关
    ServerEventManager.Subscribe(AutoRaceEventManager.REQUEST.AUTO_RACE_TOGGLE, function(evt) 
        AutoRaceEventManager.HandleAutoRaceToggle(evt) 
    end)
    
    --gg.log("已注册自动比赛事件处理器")
end

-- 发送导航指令到客户端
---@param uin number 玩家UIN
---@param targetPosition Vector3 目标位置
---@param message string 可选的消息
function AutoRaceEventManager.SendNavigateToPosition(uin, targetPosition, message)
    if not uin or not targetPosition then
        --gg.log("导航指令参数不完整")
        return
    end
    
    -- 将 Vector3 转换为 table 以便网络传输
    local positionData = { x = targetPosition.x, y = targetPosition.y, z = targetPosition.z }
    
    gg.network_channel:fireClient(uin, {
        cmd = EventPlayerConfig.NOTIFY.NAVIGATE_TO_POSITION,
        position = positionData,
        message = message or "导航到指定位置"
    })
    
    --gg.log("已发送导航指令给玩家", uin, "，目标位置:", tostring(targetPosition))
end

-- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function AutoRaceEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        --gg.log("自动比赛事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("自动比赛事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

-- 处理自动比赛开关请求
---@param evt table 事件数据 {enabled}
function AutoRaceEventManager.HandleAutoRaceToggle(evt)
    local player = AutoRaceEventManager.ValidatePlayer(evt)
    if not player then return end

    local enabled = evt.enabled
    local uin = player.uin
    
    -- 使用新的状态设置方法
    AutoRaceManager.SetPlayerAutoRaceState(player, enabled)
    
    if enabled then
        -- 发送启动通知
        AutoRaceEventManager.SendSuccessResponse(uin, AutoRaceEventManager.NOTIFY.AUTO_RACE_STARTED, {
            enabled = true,
            message = "自动比赛已启动"
        })
        
        --gg.log("玩家", uin, "启动自动比赛")
    else
        -- 发送停止通知
        AutoRaceEventManager.SendSuccessResponse(uin, AutoRaceEventManager.NOTIFY.AUTO_RACE_STOPPED, {
            enabled = false,
            message = "自动比赛已停止"
        })
        
        --gg.log("玩家", uin, "停止自动比赛")
    end
end

-- 发送成功响应
---@param uin number 玩家UIN
---@param eventName string 响应事件名
---@param data table 响应数据
function AutoRaceEventManager.SendSuccessResponse(uin, eventName, data)
    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = data
    })
end

return AutoRaceEventManager