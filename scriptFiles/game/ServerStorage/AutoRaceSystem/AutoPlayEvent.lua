-- AutoPlayEvent.lua
-- 自动挂机事件管理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local AutoPlayManager = require(ServerStorage.AutoRaceSystem.AutoPlayManager) ---@type AutoPlayManager
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class AutoPlayEventManager
local AutoPlayEventManager = {}

-- 事件名称定义
AutoPlayEventManager.REQUEST = {
    AUTO_PLAY_TOGGLE = EventPlayerConfig.REQUEST.AUTO_PLAY_TOGGLE
}

AutoPlayEventManager.RESPONSE = {
    AUTO_PLAY_STATUS = "AutoPlayStatus"
}

AutoPlayEventManager.NOTIFY = {
    AUTO_PLAY_STARTED = "AutoPlayStarted",
    AUTO_PLAY_STOPPED = "AutoPlayStopped",
    NAVIGATE_TO_POSITION = EventPlayerConfig.NOTIFY.NAVIGATE_TO_POSITION
}

-- 初始化自动挂机事件管理器
function AutoPlayEventManager.Init()
    AutoPlayEventManager.RegisterEventHandlers()
end

-- 注册所有事件处理器
function AutoPlayEventManager.RegisterEventHandlers()
    -- 自动挂机开关
    ServerEventManager.Subscribe(AutoPlayEventManager.REQUEST.AUTO_PLAY_TOGGLE, function(evt) 
        AutoPlayEventManager.HandleAutoPlayToggle(evt) 
    end)
    
    --gg.log("已注册自动挂机事件处理器")
end

-- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function AutoPlayEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        --gg.log("自动挂机事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("自动挂机事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

-- 处理自动挂机开关请求
---@param evt table 事件数据 {enabled}
function AutoPlayEventManager.HandleAutoPlayToggle(evt)
    local player = AutoPlayEventManager.ValidatePlayer(evt)
    if not player then return end

    local enabled = evt.enabled
    local uin = player.uin
    
    -- 使用新的状态设置方法
    AutoPlayManager.SetPlayerAutoPlayState(player, enabled)
    
    if enabled then
        -- 发送启动通知
        AutoPlayEventManager.SendSuccessResponse(uin, AutoPlayEventManager.NOTIFY.AUTO_PLAY_STARTED, {
            enabled = true,
            message = "自动挂机已启动，正在寻找最佳挂机点..."
        })
        
        --gg.log("玩家", uin, "启动自动挂机")
    else
        -- 发送停止通知
        AutoPlayEventManager.SendSuccessResponse(uin, AutoPlayEventManager.NOTIFY.AUTO_PLAY_STOPPED, {
            enabled = false,
            message = "自动挂机已停止"
        })
        
        --gg.log("玩家", uin, "停止自动挂机")
    end
end

-- 发送成功响应
---@param uin number 玩家UIN
---@param eventName string 响应事件名
---@param data table 响应数据
function AutoPlayEventManager.SendSuccessResponse(uin, eventName, data)
    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = data
    })
end

return AutoPlayEventManager
