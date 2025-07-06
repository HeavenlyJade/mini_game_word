

-- /scriptFiles/game/ServerStorage/SceneInteraction/SceneNodeHandlerBase.lua
-- 场景节点处理器的基类，提供了通用的事件处理和属性

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local gg = require(MainStorage.Code.Untils.MGlobal)
local ServerScheduler = require(MainStorage.Code.MServer.Scheduler.ServerScheduler)
local Entity = require(ServerStorage.EntityTypes.Entity)
local ServerDataManager = require(ServerStorage.Manager.MServerDataManager)

---@class SceneNodeHandlerBase
---@field config table # 节点配置
---@field node SandboxNode # 场景中的物理节点
---@field name string # 处理器实例名
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
end

---当实体确认离开时调用
---@param entity Entity
function SceneNodeHandlerBase:OnEntityLeave(entity)
end

---用于周期性更新，需要子类设置 self.updateInterval > 0 才会启用
function SceneNodeHandlerBase:OnUpdate()
end

---用于初始化NPC，由子类实现具体逻辑
function SceneNodeHandlerBase:initNpcs()
end

---销毁时调用
function SceneNodeHandlerBase:OnDestroy()
    if self.updateTask then
        ServerScheduler.cancel(self.updateTask)
        self.updateTask = nil
    end
end


--------------------------------------------------------------------------------
-- 基类核心逻辑
--------------------------------------------------------------------------------

---初始化
---@param config table # 来自SceneNodeConfig的配置
---@param node SandboxNode # 场景中对应的节点
function SceneNodeHandlerBase:OnInit(config, node)
    self.config = config
    self.node = node ---@type TriggerBox
    self.name = config["名字"] or node.Name

    -- 根据您的要求，在基类中初始化通用属性
    self.players = {}
    self.monsters = {}
    self.npcs = {}
    self.uuid2Entity = {}
    self.tick = 0

    -- 用于实现可靠的进入/离开事件的属性
    self.entitiesInZone = {}
    self.pendingLeaveEntities = {}

    -- 生成并注册UUID
    self.uuid = gg.create_uuid('u_SceneNodeHandler')
    ServerDataManager.addSceneNodeHandler(self)

    -- 如果子类设置了更新间隔，则启动定时器
    if self.updateInterval and self.updateInterval > 0 then
        self.updateTask = ServerScheduler.add(function()
            self.tick = self.tick + 1
            self:OnUpdate()
        end, 0, self.updateInterval)
    end

    -- 绑定物理触碰事件
    self:_connectTouchEvents()

    -- 调用空的initNpcs，如果子类重写了，则会执行子类的逻辑
    self:initNpcs()
end

---绑定物理节点的进入和离开事件，并处理物理抖动问题
function SceneNodeHandlerBase:_connectTouchEvents()
    if not self.node or not self.node.Touched or not self.node.TouchEnded then
        gg.log(string.format("场景节点处理器 '%s' 的物理节点无效或没有触碰事件。", self.name))
        return
    end

    -- 监听触碰开始
    self.node.Touched:Connect(function(touchedNode)
        if not touchedNode then return end
        
        local entity = Entity.node2Entity[touchedNode]
        if not entity then return end

        -- 如果实体正在待离开列表中，说明它在短暂离开后又迅速进入，我们取消离开操作
        if self.pendingLeaveEntities[entity.uuid] then
            self.pendingLeaveEntities[entity.uuid] = nil
            return
        end

        -- 只有当实体不在区域内时，才执行进入逻辑
        if not self.entitiesInZone[entity.uuid] then
            self.entitiesInZone[entity.uuid] = entity
            self:OnEntityEnter(entity) -- 调用可被子类重写的钩子方法
        end
    end)

    -- 监听触碰结束
    self.node.TouchEnded:Connect(function(touchedNode)
        if not touchedNode then return end
        local entity = Entity.node2Entity[touchedNode]
        if not entity then return end

        -- 如果实体已经因为某种原因在待离开列表里，则忽略
        if self.pendingLeaveEntities[entity.uuid] then
            return
        end
        
        -- 将实体加入待离开列表，并启动一个短暂的延迟检查
        self.pendingLeaveEntities[entity.uuid] = entity
        
        ServerScheduler.add(function()
            -- 在短暂延迟后，如果实体仍然在待离开列表中（说明它没有重新进入）
            if self.pendingLeaveEntities[entity.uuid] then
                -- 确认离开，执行离开逻辑
                self.pendingLeaveEntities[entity.uuid] = nil
                self.entitiesInZone[entity.uuid] = nil
                self:OnEntityLeave(entity) -- 调用可被子类重写的钩子方法
            end
        end, 0.1) -- 使用0.1秒的延迟来消除物理抖动
    end)
end

return SceneNodeHandlerBase