-- scriptFiles/game/ServerStorage/SceneInteraction/SceneInteractionEventManager.lua
-- 场景交互事件管理器，负责处理与场景节点相关的客户端请求
local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")

local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class SceneInteractionEventManager
local SceneInteractionEventManager = {}

--- 处理客户端请求离开挂机点的事件
---@param evt table 事件数据，包含 player 对象
function SceneInteractionEventManager.OnRequestLeaveIdle(evt)
    ---@type MPlayer
    local player = evt.player
    if not player or not player.isPlayer then
        return
    end

    -- 【新增】如果玩家正在自动挂机，则停止它
    local AutoPlayManager = require(ServerStorage.AutoRaceSystem.AutoPlayManager) ---@type AutoPlayManager
    AutoPlayManager.StopAutoPlayForPlayer(player, "手动离开挂机点")

    -- 检查玩家是否真的在挂机
    if not player:IsIdling() then
        --gg.log("玩家 " .. player.name .. " 请求离开挂机，但当前并未处于挂机状态。")
        return
    end

    local idleSpotName = player:GetCurrentIdleSpotName()
    if not idleSpotName then
        --gg.log("玩家 " .. player.name .. " 处于挂机状态，但无法找到挂机点名称。")
        return
    end

    -- 1. 根据名称从配置中获取场景节点配置
    local nodeConfig = ConfigLoader.GetSceneNode(idleSpotName)
    if not nodeConfig then
        --gg.log(string.format("警告：无法在配置中找到名为 '%s' 的场景节点。", idleSpotName))
        return
    end

    -- 2. 从配置中获取唯一ID
    local handlerId = nodeConfig.uuid
    if not handlerId then
        --gg.log(string.format("警告：场景节点 '%s' 的配置中缺少 'uuid'。", idleSpotName))
        return
    end

    -- 3. 使用唯一ID获取处理器实例
    local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local handler = ServerDataManager.getSceneNodeHandler(handlerId)
    
    if handler and handler.OnEntityLeave then
        --gg.log(string.format("玩家 '%s' 通过UI请求离开挂机点 '%s'", player.name, idleSpotName))
        handler:OnEntityLeave(player)
    else
        --gg.log(string.format("警告：玩家 '%s' 请求离开挂机点 '%s'，但找不到对应的处理器 (ID: %s)。", player.name, idleSpotName, handlerId))
    end
end

--- 初始化，订阅所有相关的客户端请求事件
function SceneInteractionEventManager.Init()
    ServerEventManager.Subscribe(EventPlayerConfig.REQUEST.REQUEST_LEAVE_IDLE, SceneInteractionEventManager.OnRequestLeaveIdle)
    --gg.log("场景交互事件管理器（SceneInteractionEventManager）初始化完成，已监听离开挂机请求。")
end

return SceneInteractionEventManager
