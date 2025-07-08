local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local SceneNodeHandlerBase = require(ServerStorage.SceneInteraction.SceneNodeHandlerBase) ---@type SceneNodeHandlerBase
local GameModeManager = require(ServerStorage.GameModes.GameModeManager) ---@type GameModeManager
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class RaceTriggerHandler : SceneNodeHandlerBase
local RaceTriggerHandler = ClassMgr.Class("RaceTriggerHandler", SceneNodeHandlerBase)

--- 当实体确认进入时调用
---@param entity MPlayer
function RaceTriggerHandler:OnEntityEnter(entity)
    -- 首先，调用父类的方法来处理通用的进入逻辑
    self.super.OnEntityEnter(self, entity)

    -- 我们只处理玩家实体
    if not entity or not entity:Is("MPlayer") then
        return
    end

    -- 1. 从本节点的配置中，获取关联的关卡ID
    local levelId = self.config["关联关卡"]
    if not levelId then
        gg.log(string.format("错误: 飞车触发器(%s) - 场景节点配置中缺少'关联关卡'字段。", self.name))
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
    local instanceId = self.config['唯一ID']
    if not instanceId then
        gg.log(string.format("错误: 飞车触发器(%s) - 场景节点配置中缺少'唯一ID'字段。", self.name))
        return
    end
    
    GameModeManager:AddPlayerToMode(entity, gameModeName, instanceId, gameRules, self.handlerId)

    gg.log(string.format("成功: 飞车触发器 - 玩家 %s 已被请求加入游戏模式 %s (实例ID: %s)", entity.name, gameModeName, instanceId))
end

return RaceTriggerHandler 