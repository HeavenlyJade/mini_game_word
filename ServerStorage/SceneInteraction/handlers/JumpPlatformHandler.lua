-- File: JumpPlatformHandler.lua
-- Desc: "跳台"功能的具体实现

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase)
local gg = require(MainStorage.Code.Untils.MGlobal)

---@class JumpPlatformHandler:SceneNodeHandlerBase
local JumpPlatformHandler = ClassMgr.Class("JumpPlatformHandler", SceneNodeHandlerBase)

---当节点被"碰撞"时，由管理器调用
---@param player MPlayer
function JumpPlatformHandler:OnTouch(player)
    -- 1. 检查冷却
    if self:IsInCooldown(player) then
        return
    end

    -- 2. 获取跳跃速度
    local jumpSpeed = (self.config["功能参数"] and self.config["功能参数"]["跳跃基础速度"]) or 50.0

    -- 3. 发送客户端执行跳跃的指令
    if gg.network_channel then
        gg.network_channel:fireClient(player.uin, {
            cmd = "S2C_PERFORM_VEHICLE_JUMP",
            data = { speed = jumpSpeed, continueSpeed = 0 }
        })
        gg.log(string.format("SceneNode(JumpPlatform): 向玩家 %s 发送跳跃指令", player.name))
    end

    -- 4. 执行服务器指令 (如果有的话)
    local commands = self.config["进入指令"]
    if commands and #commands > 0 and gg.CommandManager then
        player:ExecuteCommands(commands)
        gg.log(string.format("SceneNode(JumpPlatform): 为玩家 %s 执行进入指令", player.name))
    end
    
    -- 5. 记录触发时间
    self:RecordTriggerTime(player)
end

return JumpPlatformHandler 