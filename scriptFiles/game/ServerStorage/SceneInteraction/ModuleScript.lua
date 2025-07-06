-- /scriptFiles/game/ServerStorage/SceneInteraction/handlers/SceneControllerHandler.lua
-- 该处理器继承了 SceneNodeHandlerBase，并实现了旧 Scene.lua 的核心功能，
-- 用于管理一个独立区域（场景）内的玩家、NPC、怪物，并驱动它们的更新。

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local gg = require(MainStorage.Code.Untils.MGlobal)
local NpcConfig = require(MainStorage.Code.Common.Config.NpcConfig)
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager)
local Npc = require(ServerStorage.EntityTypes.MNpc)

local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase)

---@class SceneControllerHandler : SceneNodeHandlerBase
local SceneControllerHandler = ClassMgr.Class("SceneControllerHandler", SceneNodeHandlerBase)

--------------------------------------------------------------------------------
-- 重写基类方法
--------------------------------------------------------------------------------

function SceneControllerHandler:OnInit(config, node)
    -- 1. 调用基类OnInit，它会初始化通用属性和事件绑定
    SceneNodeHandlerBase.OnInit(self, config, node)

    -- 2. 设置独立的更新频率，激活OnUpdate的调用
    self.updateInterval = 0.1 -- 每0.1秒更新一次

    -- 3. 获取自定义属性
    self.isSpawnScene = (self.config["自定义参数"] and self.config["自定义参数"]["是出生场景"]) or false
    self.bgmSound = (self.config["自定义参数"] and self.config["自定义参数"]["背景音乐"]) or ""

    if self.isSpawnScene then
        -- 这里需要一个新的全局变量来存储出生点处理器
        -- 我们暂时存在gg里，后续可以放入一个专门的SceneManager
        gg.spawnSceneHandler = self
    end
end

---当实体确认进入时调用
---@param entity Entity
function SceneControllerHandler:OnEntityEnter(entity)
    SceneNodeHandlerBase.OnEntityEnter(self, entity)
    
    -- 将自己作为场景上下文设置到实体上
    entity:ChangeScene(self)

    if entity.isPlayer then
        ---@cast entity MPlayer
        if not self.players[entity.uin] then
            self.players[entity.uin] = entity
            -- 发布玩家进入场景事件
            ServerEventManager.Publish("PlayerEnterSceneEvent", { player = entity, scene = self })
        end
    end
end

---当实体确认离开时调用
---@param entity Entity
function SceneControllerHandler:OnEntityLeave(entity)
    SceneNodeHandlerBase.OnEntityLeave(self, entity)

    if entity.isPlayer then
        ---@cast entity MPlayer
        if self.players[entity.uin] then
            self.players[entity.uin] = nil
            -- 发布玩家离开场景事件
            ServerEventManager.Publish("PlayerLeaveSceneEvent", { player = entity, scene = self })
        end
    end
end

---周期性更新，由基类定时器调用
function SceneControllerHandler:OnUpdate()
    SceneNodeHandlerBase.OnUpdate(self)

    if next(self.players) == nil then
        return -- 区域内没有玩家，不进行更新
    end
    
    -- 更新每一个玩家
    for _, player in pairs(self.players) do
        if player and player.update_player then
            player:update_player()
        end
    end
    -- 更新每一个怪物
    for _, monster in pairs(self.monsters) do
        if monster and monster.update_monster then
            monster:update_monster()
        end
    end
    -- 更新每一个NPC
    for _, npc in pairs(self.npcs) do
        if npc and npc.update_npc then
            npc:update_npc()
        end
    end
end

---初始化NPC
function SceneControllerHandler:initNpcs()
    local all_npcs = NpcConfig.GetAll()
    for npc_name, npc_data in pairs(all_npcs) do
        -- 检查NPC配置的场景名是否与本处理器的名字匹配
        if npc_data["场景"] == self.name then
            local npcNodeContainer = self.node["NPC"] -- 假设NPC模型都在一个叫"NPC"的子节点下
            if npcNodeContainer and npcNodeContainer[npc_data["节点名"]] then
                local actor = npcNodeContainer[npc_data["节点名"]]
                local npc = Npc.New(npc_data, actor)
                
                self.uuid2Entity[actor] = npc
                self.npcs[npc.uuid] = npc
                npc:ChangeScene(self) -- 让NPC知道自己属于哪个场景控制器

                gg.log("SceneControllerHandler: NPC创建成功：", npc_name, "UUID：", npc.uuid, "属于场景", self.name)
            else
                gg.logError(string.format("SceneControllerHandler: 在场景 '%s' 中找不到NPC '%s' 的节点 '%s'", self.name, npc_name, npc_data["节点名"]))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 从旧Scene.lua迁移过来的公共方法
--------------------------------------------------------------------------------

function SceneControllerHandler:PlaySound(soundAssetId, boundTo, volume, pitch, range)
    if not soundAssetId or soundAssetId == "" then
        return
    end
    for _, player in pairs(self.players) do
        player:PlaySound(soundAssetId, boundTo, volume, pitch, range)
    end
end

--- 在本区域内根据路径获取节点
---@param path string
---@return SandboxNode
function SceneControllerHandler:Get(path)
    local node = self.node
    local lastPart = ""
    for part in path:gmatch("[^/]+") do -- 用/分割字符串
        if part ~= "" then
            lastPart = part
            if not node then
                gg.log(string.format("场景控制器[%s]获取路径[%s]失败: 在[%s]处节点不存在", self.name, path, lastPart))
                return nil
            end
            node = node[part]
        end
    end
    return node
end


function SceneControllerHandler:OverlapSphereEntity(center, radius, filterGroup, filterFunc)
    local results = game:GetService('WorldService'):OverlapSphere(radius,
        Vector3.New(center.x, center.y, center.z), false, filterGroup)
    local retEntities = {}
    for _, v in ipairs(results) do
        local entity = Entity.node2Entity[v.obj]
        if entity and (not filterFunc or filterFunc(entity)) then
            table.insert(retEntities, entity)
        end
    end
    return retEntities
end


function SceneControllerHandler:OverlapBoxEntity(center, extent, angle, filterGroup, filterFunc)
    local results = game:GetService('WorldService'):OverlapBox(Vector3.New(extent.x, extent.y, extent.z),
        Vector3.New(center.x, center.y, center.z), Vector3.New(angle.x, angle.y, angle.z), false, filterGroup)
    local retEntities = {}
    for _, v in ipairs(results) do
        local entity = Entity.node2Entity[v.obj]
        if entity and (not filterFunc or filterFunc(entity)) then
            table.insert(retEntities, entity)
        end
    end
    return retEntities
end

return SceneControllerHandler 