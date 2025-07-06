print("Hello world!")

local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase)
local gg = require(MainStorage.Code.Untils.MGlobal)

---@class JumpPlatformHandler : SceneNodeHandlerBase
local JumpPlatformHandler = ClassMgr.Class("JumpPlatformHandler", SceneNodeHandlerBase)

---当实体进入跳台区域时触发
---@param entity Entity
function JumpPlatformHandler:OnEntityEnter(entity)
    -- 调用父类的方法（虽然当前为空，但是个好习惯）
    SceneNodeHandlerBase.OnEntityEnter(self, entity)

    -- 检查进入的是否是玩家
    if entity and entity.isPlayer then
        ---@cast entity MPlayer
        
        -- 从配置中读取跳跃速度，如果配置中没有，则使用一个默认值
        -- 注意：我们约定在SceneNodeConfig的 "自定义参数" 表里存放特定处理器的数据
        local jumpSpeed = (self.config["自定义参数"] and self.config["自定义参数"]["跳跃速度"]) or 50
        
        gg.log(string.format("玩家 '%s' 进入了跳台 '%s'，施加跳跃力，速度为: %s", entity:GetName(), self.name, jumpSpeed))

        -- 检查actor是否存在并且有SetJumpInfo方法
        if entity.actor and entity.actor.SetJumpInfo then
            -- 设置一个巨大的一次性向上初速度
            entity.actor:SetJumpInfo(jumpSpeed, 0)
            -- 执行跳跃
            entity.actor:Jump(true)
        else
            gg.logError(string.format("JumpPlatformHandler: 玩家 '%s' 的 actor 无效或没有 SetJumpInfo 方法。", entity:GetName()))
        end
    end
end

return JumpPlatformHandler