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

    -- 关键：只对玩家执行跳台逻辑
    if entity and entity.isPlayer then
        ---@cast entity MPlayer

        -- 从配置中读取跳跃速度
        local jumpSpeed = (self.config["自定义参数"] and self.config["自定义参数"]["跳跃速度"]) or 1000
        -- 从配置中读取音效资源ID
        local soundAssetId = self.soundAssetId

        --gg.log(string.format("玩家 '%s' 进入了跳台 '%s'，施加跳跃力，速度为: %s", (entity.GetName and entity:GetName()) or entity.uuid, self.name, jumpSpeed))

        -- 播放音效
        if soundAssetId and soundAssetId ~= "" then
            -- 直接在触发的玩家身上播放音效
            entity:PlaySound(soundAssetId, entity.actor)
            --gg.log(string.format("JumpPlatformHandler: 为玩家 '%s' 播放跳台音效: %s", (entity.GetName and entity:GetName()) or entity.uuid, soundAssetId))
        end

        -- 检查actor是否存在并且有SetJumpInfo方法
        if entity.actor and entity.actor.SetJumpInfo then
            -- 设置一个巨大的一次性向上初速度
            entity.actor:SetJumpInfo(jumpSpeed, 0)
            -- 执行跳跃
            entity.actor:Jump(true)
            -- 核心：更新玩家状态为空中
            entity.movementState = 'air'
            --gg.log(string.format("玩家 '%s' 状态切换为 'air'。", (entity.GetName and entity:GetName()) or entity.uuid))
        else
            --gg.log(string.format("JumpPlatformHandler: 玩家 '%s' 的 actor 无效或没有 SetJumpInfo 方法。", (entity.GetName and entity:GetName()) or entity.uuid))
        end
    end
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
