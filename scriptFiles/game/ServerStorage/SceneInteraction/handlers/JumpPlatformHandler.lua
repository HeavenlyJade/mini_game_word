local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase) ---@type SceneNodeHandlerBase
local gg = require(MainStorage.Code.Untils.MGlobal)

---@class JumpPlatformHandler : SceneNodeHandlerBase
local JumpPlatformHandler = ClassMgr.Class("JumpPlatformHandler", SceneNodeHandlerBase)

---当实体进入跳台区域时触发
---@param entity Entity
function JumpPlatformHandler:OnEntityEnter(entity)
    --gg.log(string.format("DEBUG: JumpPlatformHandler:OnEntityEnter - 实体 '%s' 已进入，准备执行跳台逻辑。", (entity.GetName and entity:GetName()) or entity.uuid or "未知实体"))
    -- 调用父类的方法
    SceneNodeHandlerBase.OnEntityEnter(self, entity)
end

---当实体离开跳台区域时触发
---@param entity Entity
function JumpPlatformHandler:OnEntityLeave(entity)
    -- 首先调用基类的方法，处理通用的离开逻辑（如从玩家列表中移除）
    SceneNodeHandlerBase.OnEntityLeave(self, entity)

    -- 只对玩家打印离开日志
    if entity and entity.isPlayer then
        --gg.log(string.format("玩家 '%s' 离开了跳台 '%s'。", (entity.GetName and entity:GetName()) or entity.uuid, self.name))
    end
end

return JumpPlatformHandler
