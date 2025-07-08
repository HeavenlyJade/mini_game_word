-- /scriptFiles/game/ServerStorage/SceneInteraction/SceneNodeHandlerBase.lua
-- 场景节点处理器的基类，提供了通用的事件处理和属性

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local gg = require(MainStorage.Code.Untils.MGlobal)
local ServerScheduler = require(MainStorage.Code.MServer.Scheduler.ServerScheduler) ---@type ServerScheduler
local Entity = require(ServerStorage.EntityTypes.Entity) ---@type Entity
local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local NpcConfig = require(MainStorage.Code.Common.Config.NpcConfig)  ---@type NpcConfig
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local Npc = require(ServerStorage.EntityTypes.MNpc) ---@type Npc

---@class SceneNodeHandlerBase
---@field config table # 节点配置
---@field node SandboxNode # 场景中的物理节点
---@field name string # 处理器实例名
---@field handlerId string # 处理器唯一ID (来自SceneNodeConfig中的'唯一ID')
---@field uuid string # 唯一ID
---@field players table<number, MPlayer> # 在此区域内的玩家列表 (由子类管理)
---@field monsters table<string, Monster> # 在此区域内的怪物列表 (由子类管理)
---@field npcs table<string, Npc> # 在此区域内的NPC列表 (由子类管理)
---@field uuid2Entity table<string, Entity> # 实体UUID到实体的映射 (由子类管理)
---@field entitiesInZone table<string, Entity> # 当前真正在区域内的实体
---@field pendingLeaveEntities table<string, Entity> # 待确认离开的实体
---@field tick number # tick计数
local SceneNodeHandlerBase = ClassMgr.Class("SceneNodeHandlerBase")

--------------------------------------------------------------------------------
-- 需要被子类重写的方法
--------------------------------------------------------------------------------

---当实体确认进入时调用
---@param entity Entity
function SceneNodeHandlerBase:OnEntityEnter(entity)
    -- 只处理玩家的通用进入/离开事件
    if entity.isPlayer then
        gg.log(string.format("DEBUG: SceneNodeHandlerBase:OnEntityEnter - 玩家 '%s' (uin: %s) 进入了一个由 '%s' 管理的区域。", (entity.GetName and entity:GetName()) or entity.uuid, entity.uin, self.name))
        ---@cast entity MPlayer
        if not self.players[entity.uin] then
            self.players[entity.uin] = entity
            ServerEventManager.Publish("PlayerEnterSceneEvent", { player = entity, scene = self })
        end
    end
end

---当实体确认离开时调用
---@param entity Entity
function SceneNodeHandlerBase:OnEntityLeave(entity)
    if entity.isPlayer then
        ---@cast entity MPlayer
        if self.players[entity.uin] then
            self.players[entity.uin] = nil
            ServerEventManager.Publish("PlayerLeaveSceneEvent", { player = entity, scene = self })
        end
    end
end

---用于周期性更新，需要子类设置 self.updateInterval > 0 才会启用
function SceneNodeHandlerBase:OnUpdate()
    if next(self.players) == nil then
        return
    end
    
    for _, player in pairs(self.players) do
        if player and player.update_player then
            player:update_player()
        end
    end
    for _, monster in pairs(self.monsters) do
        if monster and monster.update_monster then
            monster:update_monster()
        end
    end
    for _, npc in pairs(self.npcs) do
        if npc and npc.update_npc then
            npc:update_npc()
        end
    end
end

---用于初始化NPC，由子类实现具体逻辑
function SceneNodeHandlerBase:initNpcs()
    local all_npcs = NpcConfig.GetAll()
    for npc_name, npc_data in pairs(all_npcs) do
        if npc_data["场景"] == self.name then
            local npcNodeContainer = self.node["NPC"]
            if npcNodeContainer and npcNodeContainer[npc_data["节点名"]] then
                local actor = npcNodeContainer[npc_data["节点名"]]
                local npc = Npc.New(npc_data, actor)
                
                self.uuid2Entity[actor] = npc
                self.npcs[npc.uuid] = npc
                gg.log(string.format("SceneNodeHandlerBase: NPC创建成功：'%s' 属于场景 '%s'", npc_name, self.name))
            else
                gg.log(string.format("ERROR: SceneNodeHandlerBase: 在场景 '%s' 中找不到NPC '%s' 的节点 '%s'", self.name, npc_name, npc_data["节点名"]))
            end
        end
    end
end

---销毁时调用
function SceneNodeHandlerBase:OnDestroy()
    if self.updateTask then
        ServerScheduler.cancel(self.updateTask)
        self.updateTask = nil
    end
end

--- 强制让一个实体离开本区域，用于外部逻辑同步状态
---@param entity Entity
function SceneNodeHandlerBase:ForceEntityLeave(entity)
    if not entity then return end

    local entityId = entity.uuid
    local wasInZone = self.entitiesInZone[entityId]
    local wasPendingLeave = self.pendingLeaveEntities[entityId]

    if wasInZone or wasPendingLeave then
        gg.log(string.format("DEBUG: %s:ForceEntityLeave - 外部逻辑强制实体 '%s' 离开。", self.name, (entity.GetName and entity:GetName()) or entityId))
        self.pendingLeaveEntities[entityId] = nil
        self.entitiesInZone[entityId] = nil
        self:OnEntityLeave(entity)
    end
end


--------------------------------------------------------------------------------
-- 基类核心逻辑
--------------------------------------------------------------------------------

---初始化
---@param config table # 来自SceneNodeConfig的配置
---@param node SandboxNode # 场景中对应的节点
function SceneNodeHandlerBase:OnInit(node, config)
    ---@cast node TriggerBox

    self.config = config
    self.node = node  ---@type TriggerBox
    self.name = config["名字"] or node.Name
    self.handlerId = config["唯一ID"] -- 从配置中获取ID

    self.soundAssetId = config["音效资源"] or ""
    self.enterCommand = config["进入指令"] or ""
    self.leaveCommand = config["离开指令"] or ""
    self.isSpawnScene = (self.config["自定义参数"] and self.config["自定义参数"]["是出生场景"]) or false
    self.bgmSound = (self.config["自定义参数"] and self.config["自定义参数"]["背景音乐"]) or ""
    if self.isSpawnScene then
        gg.spawnSceneHandler = self
    end

    self.players = {}
    self.monsters = {}
    self.npcs = {}
    self.uuid2Entity = {}
    self.tick = 0

    self.entitiesInZone = {}
    self.pendingLeaveEntities = {}

    ServerDataManager.addSceneNodeHandler(self)

    if config["定时指令列表"] and #config["定时指令列表"] > 0 then
        for _, cmd in ipairs(config["定时指令列表"]) do
            if cmd["指令"] == "UPDATE" and cmd["间隔"] then
                self.updateInterval = cmd["间隔"]
                break
            end
        end
    end

    if self.updateInterval and self.updateInterval > 0 then
        self.updateTask = ServerScheduler.add(function()
            self.tick = self.tick + 1
            self:OnUpdate()
        end, 0, self.updateInterval)
    end

    self:_connectTouchEvents()

    self:initNpcs()
end

---绑定物理节点的进入和离开事件，并处理物理抖动问题
function SceneNodeHandlerBase:_connectTouchEvents()

    self.node.Touched:Connect(function(touchedNode)
        gg.log(string.format("DEBUG: %s.Touched - 检测到物理触碰，来源: %s", self.name, touchedNode and touchedNode.Name or "一个未命名的对象"))
        if not touchedNode then return end
        
        local entity = Entity.node2Entity[touchedNode]
        if not entity then
            gg.log(string.format("DEBUG: %s.Touched - 触碰来源 '%s' 不是一个已注册的实体，忽略。", self.name, touchedNode.Name or "一个未命名的对象"))
            return
        end
        gg.log(string.format("DEBUG: %s.Touched - 识别到实体: %s (UUID: %s)", self.name, (entity.GetName and entity:GetName()) or entity.uuid or "未知实体", entity.uuid))

        if self.pendingLeaveEntities[entity.uuid] then
            gg.log(string.format("DEBUG: %s.Touched - 实体 '%s' 正在待离开列表，取消离开并重新进入。", self.name, (entity.GetName and entity:GetName()) or entity.uuid))
            self.pendingLeaveEntities[entity.uuid] = nil
            if self.entitiesInZone[entity.uuid] then
            return
            end
        end

        if not self.entitiesInZone[entity.uuid] then
            self.entitiesInZone[entity.uuid] = entity
            gg.log(string.format("DEBUG: %s.Touched - 确认实体 '%s' 进入，调用 OnEntityEnter。", self.name, (entity.GetName and entity:GetName()) or entity.uuid))
            self:OnEntityEnter(entity)
        end
    end)

    self.node.TouchEnded:Connect(function(touchedNode)
        if not touchedNode then return end
        local entity = Entity.node2Entity[touchedNode]
        if not entity then return end

        if self.pendingLeaveEntities[entity.uuid] then
            return
        end
        
        self.pendingLeaveEntities[entity.uuid] = entity
        
        ServerScheduler.add(function()
            if self.pendingLeaveEntities[entity.uuid] then
                self.pendingLeaveEntities[entity.uuid] = nil
                self.entitiesInZone[entity.uuid] = nil
                self:OnEntityLeave(entity)
            end
        end, 0.1)
    end)
end

function SceneNodeHandlerBase:PlaySound(soundAssetId, boundTo, volume, pitch, range)
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
function SceneNodeHandlerBase:Get(path)
    local node = self.node
    local lastPart = ""
    for part in path:gmatch("[^/]+") do
        if part ~= "" then
            lastPart = part
            if not node then
                gg.log(string.format("场景处理器[%s]获取路径[%s]失败: 在[%s]处节点不存在", self.name, path, lastPart))
                return nil
            end
            node = node[part]
        end
    end
    return node
end

function SceneNodeHandlerBase:OverlapSphereEntity(center, radius, filterGroup, filterFunc)
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

function SceneNodeHandlerBase:OverlapBoxEntity(center, extent, angle, filterGroup, filterFunc)
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

return SceneNodeHandlerBase