local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)  ---@type ClassMgr
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase) ---@type SceneNodeHandlerBase
local GameModeManager = require(ServerStorage.GameModes.GameModeManager) ---@type GameModeManager
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class RaceTriggerHandler : SceneNodeHandlerBase
---@field super SceneNodeHandlerBase
local RaceTriggerHandler = ClassMgr.Class("RaceTriggerHandler", SceneNodeHandlerBase)

--- 当有实体进入触发区域时调用
---@param player MPlayer
function RaceTriggerHandler:OnEntityEnter(player)
    -- 核心修正：直接检查 isPlayer 属性，这是最简单且最正确的判断方法
    if not player or not player.isPlayer then
        return
    end

    -- 【核心修正】从处理器配置中获取关联的关卡ID，使用面向对象的方式访问
    local levelId = self.config.linkedLevel
    if not levelId then
        gg.log(string.format("错误: 飞车触发器(%s) - 场景节点配置中缺少'linkedLevel'字段。", self.name))
        return
    end

    -- 2. 使用关卡ID，从LevelConfig中获取详细的关卡规则
    -- 在函数内部require, 避免循环依赖
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local levelConfig = ConfigLoader.Levels
    local levelData = levelConfig and levelConfig[levelId]
    if not levelData then
        gg.log(string.format("错误: 飞车触发器(%s) - 在LevelConfig中找不到ID为'%s'的关卡配置。", self.name, levelId))
        return
    end
    
    -- 3. 从关卡规则中，获取游戏模式的名称
    local gameModeName = levelData.defaultGameMode
    if not gameModeName or gameModeName == "" then
        gg.log(string.format("错误: 飞车触发器(%s) - 关卡'%s'的配置中缺少'默认玩法'字段。", self.name, levelId))
        return
    end
    
    -- 4. 获取玩法规则，并准备将其传递给GameModeManager
    local gameRules = levelData:GetRules()

    -- 5. 调用GameModeManager，请求将玩家加入比赛
    -- 我们使用场景节点配置中的'唯一ID'作为这场比赛的唯一实例ID
    local instanceId = self.config.uuid
    if not instanceId then
        gg.log(string.format("错误: 飞车触发器(%s) - 场景节点配置中缺少'uuid'字段。", self.name))
        return
    end
    
    GameModeManager:AddPlayerToMode(player, gameModeName, instanceId, gameRules, self.handlerId)

    gg.log(string.format("成功: 飞车触发器 - 玩家 %s 已被请求加入游戏模式 %s (实例ID: %s)", player.name, gameModeName, instanceId))
end

--- 当实体离开触发区域时调用
---@param player MPlayer
function RaceTriggerHandler:OnEntityLeave(player)
    if not player then return end
    gg.log(string.format("玩家 %s 离开了 '%s' 触发区域。", player.name, self.name))
    -- 目前，离开区域不会将玩家从比赛中移除，只记录日志。
    -- 这是为了防止玩家在比赛开始前误操作离开区域。
end

return RaceTriggerHandler 