-- /scriptFiles/game/ServerStorage/SceneInteraction/SceneNodeHandlerBase.lua
-- 场景节点处理器的基类，提供了通用的事件处理和属性

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local gg = require(MainStorage.Code.Untils.MGlobal)
local ServerScheduler = require(MainStorage.Code.MServer.Scheduler.ServerScheduler) ---@type ServerScheduler
local Entity = require(ServerStorage.EntityTypes.Entity) ---@type Entity
--【核心修正】不再在顶部require，以避免循环依赖
-- local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local NpcConfig = require(MainStorage.Code.Common.Config.NpcConfig)  ---@type NpcConfig
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local Npc = require(ServerStorage.EntityTypes.MNpc) ---@type Npc

---@class SceneNodeHandlerBase
---@field config table # 节点配置
---@field node TriggerBox # 场景中的包围盒节点
---@field name string # 处理器实例名
---@field handlerId string # 处理器唯一ID (来自SceneNodeConfig中的'唯一ID')
---@field uuid string # 唯一ID
---@field players table<number, MPlayer> # 在此区域内的玩家列表 (由子类管理)
---@field monsters table<string, Monster> # 在此区域内的怪物列表 (由子类管理)
---@field npcs table<string, Npc> # 在此区域内的NPC列表 (由子类管理)
---@field uuid2Entity table<string, Entity> # 实体UUID到实体的映射 (由子类管理)
---@field entitiesInZone table<string, Entity> # 当前真正在区域内的实体
---@field tick number # tick计数
---@field respawnNode SandboxNode|nil # 复活节点 (来自配置)
---@field teleportNode SandboxNode|nil # 传送节点 (来自配置)
---@field raceSceneNode SandboxNode|nil # 比赛场景的根节点 (来自配置)
local SceneNodeHandlerBase = ClassMgr.Class("SceneNodeHandlerBase")

--------------------------------------------------------------------------------
-- 需要被子类重写的方法
--------------------------------------------------------------------------------

---当实体确认进入时调用
---@param entity Entity
function SceneNodeHandlerBase:OnEntityEnter(entity)

end

---当实体确认离开时调用
---@param entity Entity
function SceneNodeHandlerBase:OnEntityLeave(entity)

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
            -- 【核心修正】应该在场景的【视觉节点】下查找NPC，而不是在逻辑节点(Area)下
            local npcNodeContainer = self.visualNode["NPC"]
            if npcNodeContainer and npcNodeContainer[npc_data["节点名"]] then
                local actor = npcNodeContainer[npc_data["节点名"]]
                local npc = Npc.New(npc_data, actor)

                self.uuid2Entity[actor] = npc
                self.npcs[npc.uuid] = npc
                --gg.log(string.format("SceneNodeHandlerBase: NPC创建成功：'%s' 属于场景 '%s'", npc_name, self.name))
            else
                --gg.log(string.format("ERROR: SceneNodeHandlerBase: 在场景 '%s' 中找不到NPC '%s' 的节点 '%s'", self.name, npc_name, npc_data["节点名"]))
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

    -- 移除对 self.createdNode 的检查，因为我们不再创建节点
end

--- 强制让一个实体离开本区域，用于外部逻辑同步状态
---@param entity Entity
function SceneNodeHandlerBase:ForceEntityLeave(entity)
    if not entity then return end

    local entityId = entity.uuid
    if self.entitiesInZone[entityId] then
        --gg.log(string.format("DEBUG: %s:ForceEntityLeave - 外部逻辑强制实体 '%s' 离开。", self.name, (entity.GetName and entity:GetName()) or entityId))
        self.entitiesInZone[entityId] = nil
        self:OnEntityLeave(entity)
    end
end


--------------------------------------------------------------------------------
-- 基类核心逻辑
--------------------------------------------------------------------------------

--- 内部辅助方法，根据路径获取节点。
-- 1. 如果路径包含'/'，则从workspace根目录查找。
-- 2. 否则，先从当前处理器的根节点(visualNode)下递归查找。
-- 3. 如果找不到，再从visualNode的父节点下递归查找。
---@param path string 节点路径
---@return SandboxNode|TriggerBox|nil
function SceneNodeHandlerBase:_getNodeFromPath(path)
    if not path or path == "" then
        return nil
    end

    -- 规则1: 绝对路径
    if string.find(path, "/", 1, true) then -- `true` for plain search
        return gg.GetChild(game.WorkSpace, path)
    end

    -- 规则2: 相对路径 - 先在当前节点下查找
    if self.visualNode then
        local foundNode = self.visualNode:FindFirstChild(path, true) -- 递归查找
        if foundNode then
            return foundNode
        end
    end

    -- 规则3: 相对路径 - 在父节点下查找 (处理兄弟节点的情况)
    if self.visualNode and self.visualNode.Parent then
        local foundNode = self.visualNode.Parent:FindFirstChild(path, true)
        if foundNode then
            return foundNode
        end
    end

    --gg.log(string.format("警告: _getNodeFromPath 在 '%s' 及其父节点下都找不到相对路径为 '%s' 的节点。", self.visualNode and self.visualNode.Name or "未知节点", path))
    return nil
end

---初始化
---@param config SceneNodeType # 来自ConfigLoader的已实例化配置对象
---@param node SandboxNode # 场景中对应的节点
---@param debugId number|nil # 用于调试的唯一ID
function SceneNodeHandlerBase:OnInit(node, config, debugId)
    --gg.log("创建节点",node, config, debugId)
    self.config = config
    self.name = config.name
    self.handlerId = config.uuid
    self.visualNode = node
    self.node = nil ---@type TriggerBox

    -- 【核心修正】改回正确的方式，使用 SceneNodeType 提供的扁平化属性
    self.respawnNode = self:_getNodeFromPath(config.respawnNodeName)
    self.teleportNode = self:_getNodeFromPath(config.teleportNodeName)
    self.raceSceneNode = self:_getNodeFromPath(config.raceScenePath)
    local triggerName = config.triggerBoxNodeName
    local triggerNode = self:_getNodeFromPath(triggerName)
    self.node = triggerNode
    self:_connectTriggerEvents() -- 为找到的节点绑定事件


    self.soundAssetId = config.soundAsset or ""
    self.enterCommand = config.enterCommand or ""
    self.leaveCommand = config.leaveCommand or ""
    self.isSpawnScene = (self.config.gameplayRules and self.config.gameplayRules["是出生场景"] == true) or false
    self.bgmSound = (self.config.gameplayRules and self.config.gameplayRules["背景音乐"]) or ""
    if self.isSpawnScene then
        gg.spawnSceneHandler = self
    end

    self.players = {}
    self.monsters = {}
    self.npcs = {}
    self.uuid2Entity = {}
    self.tick = 0
    self.entitiesInZone = {}


    if config.timedCommands and #config.timedCommands > 0 then
        for _, cmd in ipairs(config.timedCommands) do
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

    -- 初始化NPC
    self:initNpcs()
end

---绑定 TriggerBox 节点的物理触碰事件
function SceneNodeHandlerBase:_connectTriggerEvents()
    if not self.node or self.node.ClassType ~= 'TriggerBox' then
        --gg.log(string.format("错误: %s 的节点无效或不是 TriggerBox 类型，无法绑定事件。", self.name))
        return
    end

    self.node.Touched:Connect(function(actor)
        -- 事件的参数是一个通用的物理 actor，我们需要从中找到对应的游戏实体
        if not actor then return end

        local entity = nil
        if actor.UserId then
            -- 如果 actor 有 UserId 属性，说明它是一个玩家的 Actor
            --gg.log(string.format("DEBUG: %s.Touched - 检测到玩家Actor触碰，ID: %s, 名字: %s", self.name, actor.UserId, actor.Name))
            local ServerDataManager = require(ServerStorage.Manager.MServerDataManager)
            entity = ServerDataManager.getPlayerByUin(actor.UserId)
            if not entity then
                --gg.log(string.format("警告: %s.Touched - 找到了玩家Actor，但在DataManager中找不到对应的MPlayer实体 (UIN: %s)", self.name, actor.UserId))
                return
            end
        else
            -- 否则，它可能是怪物、NPC或其他可交互物体的 Actor
            -- TODO: 在此实现通过 actor 查找非玩家实体的逻辑 (例如 MMonster, MNpc)
            -- 实现方式可能包括：
            -- 1. 遍历 ServerDataManager 中的怪物/NPC列表，通过 entity.actor == actor 匹配
            -- 2. 在创建怪物/NPC时，给其 actor 对象添加一个自定义属性(如 "EntityUUID")，在此处获取该属性来反向查找
            --gg.log(string.format("DEBUG: %s.Touched - 检测到非玩家Actor触碰: %s。实体查找逻辑待实现。", self.name, actor.Name))
            return -- 暂时不对非玩家实体做任何处理
        end

        -- 后续是通用逻辑，无论找到的是玩家还是怪物
        local entityId = entity.uuid
        if not self.entitiesInZone[entityId] then
            --gg.log(string.format("DEBUG: %s.Touched - 确认实体 '%s' 进入，调用 OnEntityEnter。", self.name, entity.name or entityId))
            self.entitiesInZone[entityId] = entity
            self:OnEntityEnter(entity)
        end
    end)

    self.node.TouchEnded:Connect(function(actor)
        if not actor then return end

        local entity = nil
        if actor.UserId then
            --gg.log(string.format("DEBUG: %s.TouchEnded - 玩家Actor接触结束，ID: %s, 名字: %s", self.name, actor.UserId, actor.Name))
            local ServerDataManager = require(ServerStorage.Manager.MServerDataManager)
            entity = ServerDataManager.getPlayerByUin(actor.UserId)
            if not entity then
                return
            end
        else
            --gg.log(string.format("DEBUG: %s.TouchEnded - 非玩家Actor接触结束: %s。实体查找逻辑待实现。", self.name, actor.Name))
            return
        end

        local entityId = entity.uuid
        if self.entitiesInZone[entityId] then
            --gg.log(string.format("DEBUG: %s.TouchEnded - 确认实体 '%s' 离开，调用 OnEntityLeave。", self.name, entity.name or entityId))
            self.entitiesInZone[entityId] = nil
            self:OnEntityLeave(entity)
        end
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
                --gg.log(string.format("场景处理器[%s]获取路径[%s]失败: 在[%s]处节点不存在", self.name, path, lastPart))
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
