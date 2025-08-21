-- AutoPlayEvent.lua
-- 自动挂机事件管理器 - 新增传送相关事件

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
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
    AUTO_PLAY_STOPPED = "AutoPlayStopped"
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
    
    -- 如果启用自动挂机，先检查并停止自动比赛
    if enabled then
        local autoRaceManager = require(ServerStorage.AutoRaceSystem.AutoRaceManager) ---@type AutoRaceManager
        if autoRaceManager.IsPlayerAutoRacing(player) then
            -- 停止自动比赛
            autoRaceManager.SetPlayerAutoRaceState(player, false)
            -- 发送自动比赛停止通知
            local autoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
            autoRaceEventManager.SendSuccessResponse(uin, autoRaceEventManager.NOTIFY.AUTO_RACE_STOPPED, {
                enabled = false,
                message = "自动比赛已停止（因启动自动挂机）"
            })
        end
    end
    
    -- 使用新的状态设置方法（延迟 require 以避免循环依赖）
    local autoPlayManager = require(ServerStorage.AutoRaceSystem.AutoPlayManager) ---@type AutoPlayManager
    autoPlayManager.SetPlayerAutoPlayState(player, enabled)
    
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

-- 【新增】发送自动挂机开始事件到客户端（供AutoPlayManager调用时也可直接使用）
---@param uin number 玩家UIN
---@param player MPlayer 玩家对象
---@param targetPosition Vector3|nil 目标传送位置
-- 删除：客户端传送改为服务端直接传送，不再发送 AUTO_PLAY_START

-- 删除：自动挂机的传送成功/失败客户端提示，不再使用

--  发送导航指令到客户端
---@param uin number 玩家UIN
---@param targetPosition Vector3 目标位置
---@param message string 可选的消息
function AutoPlayEventManager.SendNavigateToPosition(uin, targetPosition, message)
    
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