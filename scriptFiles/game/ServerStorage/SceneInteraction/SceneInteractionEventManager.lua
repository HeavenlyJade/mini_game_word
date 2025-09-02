-- scriptFiles/game/ServerStorage/SceneInteraction/SceneInteractionEventManager.lua
-- 场景交互事件管理器，负责处理与场景节点相关的客户端请求
local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")

local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
---@class SceneInteractionEventManager
local SceneInteractionEventManager = {}

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function SceneInteractionEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    if not env_player then
        --gg.log("场景交互事件缺少玩家参数")
        return nil
    end
    local uin = env_player.uin
    if not uin then
        --gg.log("场景交互事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("场景交互事件找不到玩家: " .. uin)
        return nil
    end

    return player
end
--- 处理客户端请求离开挂机点的事件
---@param evt table 事件数据，包含 player 对象
function SceneInteractionEventManager.OnRequestLeaveIdle(evt)
    gg.log("接收到离开挂机请求")
    ---@type MPlayer
    local player = SceneInteractionEventManager.ValidatePlayer(evt)
    -- 【新增】如果玩家正在自动挂机，则停止它
    local AutoPlayManager = require(ServerStorage.AutoRaceSystem.AutoPlayManager) ---@type AutoPlayManager
    local wasAutoPlaying = AutoPlayManager.IsPlayerAutoPlaying(player)
    AutoPlayManager.StopAutoPlayForPlayer(player, "手动离开挂机点")

    local idleSpotName = player:GetCurrentIdleSpotName()
    if not idleSpotName then
        gg.log("玩家 " .. player.name .. " 处于挂机状态，但无法找到挂机点名称。")
        return
    end

    -- 1. 根据名称从配置中获取场景节点配置
    local nodeConfig = ConfigLoader.GetSceneNode(idleSpotName)
    if not nodeConfig then
        gg.log(string.format("警告：无法在配置中找到名为 '%s' 的场景节点。", idleSpotName))
        return
    end

    -- 2. 从配置中获取唯一ID
    local handlerId = nodeConfig.uuid
    if not handlerId then
        gg.log(string.format("警告：场景节点 '%s' 的配置中缺少 'uuid'。", idleSpotName))
        return
    end

    -- 3. 使用唯一ID获取处理器实例
    local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local handler = ServerDataManager.getSceneNodeHandler(handlerId)
    
    if handler and handler.OnEntityLeave then
        gg.log(string.format("玩家 '%s' 通过UI请求离开挂机点 '%s'", player.name, idleSpotName))
        handler:OnEntityLeave(player)
    end
    SceneInteractionEventManager.NotifyLeaveIdleSuccess(player, wasAutoPlaying)


end

--- 【新增】强制让一个玩家离开他当前的挂机点
---@param player MPlayer
function SceneInteractionEventManager.ForcePlayerLeaveIdleSpot(player)
    if not player or not player:IsIdling() then
        return
    end

    local idleSpotName = player:GetCurrentIdleSpotName()
    if not idleSpotName then
        return
    end

    local nodeConfig = ConfigLoader.GetSceneNode(idleSpotName)
    if not nodeConfig then
        return
    end
    
    local handlerId = nodeConfig.uuid
    if not handlerId then
        return
    end

    local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local handler = ServerDataManager.getSceneNodeHandler(handlerId)

    if handler and handler.ForceEntityLeave then
        handler:ForceEntityLeave(player)
        --gg.log(string.format("已强制玩家 '%s' 离开挂机点 '%s'", player.name, idleSpotName))
    end
end

--- 初始化，订阅所有相关的客户端请求事件
function SceneInteractionEventManager.Init()
    ServerEventManager.Subscribe(EventPlayerConfig.REQUEST.REQUEST_LEAVE_IDLE, function(evt)
        SceneInteractionEventManager.OnRequestLeaveIdle(evt)
    end)
        --gg.log("场景交互事件管理器（SceneInteractionEventManager）初始化完成，已监听离开挂机请求。")
end

--- 【新增】通知客户端离开挂机成功
---@param player MPlayer 玩家对象
---@param wasAutoPlaying boolean 是否之前在自动挂机状态
function SceneInteractionEventManager.NotifyLeaveIdleSuccess(player, wasAutoPlaying)
    if not player or not player.uin then return end
    
    gg.network_channel:fireClient(player.uin, {
        cmd = EventPlayerConfig.NOTIFY.LEAVE_IDLE_SUCCESS,
        data = {
            success = true,
            wasAutoPlaying = wasAutoPlaying,
            message = "已成功离开挂机点"
        }
    })
    
    gg.log(string.format("已通知玩家 '%s' 离开挂机成功，之前自动挂机状态: %s", player.name, tostring(wasAutoPlaying)))
end
return SceneInteractionEventManager
