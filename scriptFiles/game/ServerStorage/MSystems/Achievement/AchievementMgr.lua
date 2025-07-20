-- AchievementMgr.lua
-- 成就管理器 - 静态类，管理所有玩家的成就数据，负责解锁、升级、保存、同步等操作

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local Achievement = require(ServerStorage.MSystems.Achievement.Achievement) ---@type Achievement
local AchievementCloudDataMgr = require(ServerStorage.MSystems.Achievement.AchievementCloudDataMgr) ---@type AchievementCloudDataMgr

-- 所有玩家的成就数据管理，服务器侧

---@class AchievementMgr
local AchievementMgr = {
    server_player_achievement_data = {}, ---@type table<string, table<string, Achievement>> [playerId][achievementId]
}

-- 自动保存定时器
local function SaveAllPlayerAchievements()
    local count = 0
    for playerId in pairs(AchievementMgr.server_player_achievement_data) do
        AchievementMgr.SavePlayerAchievements(playerId, false)
        count = count + 1
    end
    gg.log("定时保存成就数据完成，保存了", count, "个玩家的成就")
end

local saveTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
saveTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
saveTimer.Name = 'ACHIEVEMENT_SAVE_ALL'
saveTimer.Delay = 60
saveTimer.Loop = true
saveTimer.Interval = 60
saveTimer.Callback = SaveAllPlayerAchievements
saveTimer:Start()

-- 玩家生命周期管理 --------------------------------------------------------

--- 玩家上线处理
---@param player table 玩家实例
---@return boolean 是否加载成功
function AchievementMgr.OnPlayerJoin(player)
    local playerId = tostring(player.uin)
    
    -- 从云端加载玩家成就数据
    local success, achievementData = AchievementCloudDataMgr.LoadPlayerAchievements(playerId)
    
    if success and achievementData then
        -- 恢复成就实例
        AchievementMgr._RestorePlayerAchievements(playerId, achievementData, player)
        gg.log("成功加载玩家成就数据:", playerId, "成就数量:", AchievementMgr.GetPlayerAchievementCount(playerId))
    else
        -- 初始化空的成就数据
        AchievementMgr.server_player_achievement_data[playerId] = {}
        gg.log("初始化新玩家成就数据:", playerId)
    end
    
    -- 应用所有已解锁成就的效果
    AchievementMgr._ApplyAllPlayerAchievementEffects(player)
    
    return true
end

--- 玩家离线处理
---@param player table 玩家实例
function AchievementMgr.OnPlayerLeave(player)
    local playerId = tostring(player.uin)
    
    -- 保存玩家成就数据到云端
    AchievementMgr.SavePlayerAchievements(playerId, true)
    
    -- 清理内存数据
    AchievementMgr.server_player_achievement_data[playerId] = nil
    
    gg.log("玩家离线，清理成就数据:", playerId)
end

--- 保存玩家成就数据到云端
---@param playerId string 玩家ID
---@param force boolean|nil 是否强制保存，默认false
function AchievementMgr.SavePlayerAchievements(playerId, force)
    local achievements = AchievementMgr.server_player_achievement_data[playerId]
    if not achievements then
        return
    end
    
    -- 转换为保存格式
    local saveData = {}
    for achievementId, achievement in pairs(achievements) do
        saveData[achievementId] = achievement:GetSaveData()
    end
    
    -- 保存到云端
    AchievementCloudDataMgr.SavePlayerAchievements(playerId, saveData, force)
end

--- 获取玩家成就数据
---@param playerId string 玩家ID
---@return table<string, Achievement> 玩家成就数据
function AchievementMgr.GetPlayerAchievements(playerId)
    return AchievementMgr.server_player_achievement_data[playerId] or {}
end

--- 获取或创建玩家成就数据（如果不存在则创建新的）
---@param playerId string 玩家ID
---@return table<string, Achievement> 玩家成就数据
function AchievementMgr.GetOrCreatePlayerAchievements(playerId)
    local achievements = AchievementMgr.server_player_achievement_data[playerId]
    if not achievements then
        achievements = {}
        AchievementMgr.server_player_achievement_data[playerId] = achievements
    end
    return achievements
end

-- 成就解锁与升级 --------------------------------------------------------

--- 解锁成就
---@param player table 玩家实例
---@param achievementId string 成就ID
---@param initialLevel number|nil 初始等级，默认为1
---@return boolean 是否解锁成功
function AchievementMgr.UnlockAchievement(player, achievementId, initialLevel)
    if not player or not achievementId then
        gg.log("AchievementMgr.UnlockAchievement: 参数无效", player and player.uin or "nil", achievementId)
        return false
    end
    
    local playerId = tostring(player.uin)
    initialLevel = initialLevel or 1
    
    -- 检查是否已解锁
    if AchievementMgr.HasAchievement(playerId, achievementId) then
        gg.log("成就已解锁:", playerId, achievementId)
        return false
    end
    
    -- 获取成就配置
    local ConfigLoader = require(MainStorage.Code.Common.Config.ConfigLoader)
    local achievementType = ConfigLoader.GetAchievement(achievementId)
    if not achievementType then
        gg.log("成就配置不存在:", achievementId)
        return false
    end
    
    -- 创建成就实例
    local achievement = Achievement.New(achievementType, playerId, os.time(), initialLevel)
    
    -- 添加到玩家成就列表
    local achievements = AchievementMgr.GetOrCreatePlayerAchievements(playerId)
    achievements[achievementId] = achievement
    
    -- 应用成就效果
    achievement:ApplyEffects(player)
    
    gg.log(string.format("玩家 %s 解锁成就: %s (等级:%d)", playerId, achievementId, initialLevel))
    
    return true
end

--- 升级成就（仅天赋成就）
---@param player table 玩家实例
---@param achievementId string 成就ID
---@return boolean 是否升级成功
function AchievementMgr.UpgradeAchievement(player, achievementId)
    if not player or not achievementId then
        gg.log("AchievementMgr.UpgradeAchievement: 参数无效")
        return false
    end
    
    local playerId = tostring(player.uin)
    local achievement = AchievementMgr.GetPlayerAchievement(playerId, achievementId)
    
    if not achievement then
        gg.log("成就不存在，无法升级:", playerId, achievementId)
        return false
    end
    
    if not achievement:IsTalentAchievement() then
        gg.log("普通成就无法升级:", playerId, achievementId)
        return false
    end
    
    -- 执行升级
    local success = achievement:Upgrade(player)
    if success then
        gg.log(string.format("玩家 %s 成就 %s 升级成功，当前等级: %d", 
            playerId, achievementId, achievement:GetCurrentLevel()))
    end
    
    return success
end

--- 检查成就是否可以升级
---@param player table 玩家实例
---@param achievementId string 成就ID
---@return boolean 是否可以升级
function AchievementMgr.CanUpgradeAchievement(player, achievementId)
    if not player or not achievementId then
        return false
    end
    
    local playerId = tostring(player.uin)
    local achievement = AchievementMgr.GetPlayerAchievement(playerId, achievementId)
    
    if not achievement then
        return false
    end
    
    return achievement:CanUpgrade(player)
end

-- 查询接口 --------------------------------------------------------

--- 玩家是否拥有指定成就
---@param playerId string 玩家ID
---@param achievementId string 成就ID
---@return boolean
function AchievementMgr.HasAchievement(playerId, achievementId)
    local achievements = AchievementMgr.server_player_achievement_data[playerId]
    return achievements and achievements[achievementId] ~= nil
end

--- 获取玩家指定成就
---@param playerId string 玩家ID
---@param achievementId string 成就ID
---@return Achievement|nil
function AchievementMgr.GetPlayerAchievement(playerId, achievementId)
    local achievements = AchievementMgr.server_player_achievement_data[playerId]
    return achievements and achievements[achievementId]
end

--- 获取玩家成就数量
---@param playerId string 玩家ID
---@return number
function AchievementMgr.GetPlayerAchievementCount(playerId)
    local achievements = AchievementMgr.server_player_achievement_data[playerId]
    if not achievements then
        return 0
    end
    
    local count = 0
    for _ in pairs(achievements) do
        count = count + 1
    end
    return count
end

--- 获取玩家天赋成就列表
---@param playerId string 玩家ID
---@return table<string, Achievement>
function AchievementMgr.GetPlayerTalentAchievements(playerId)
    local achievements = AchievementMgr.server_player_achievement_data[playerId] or {}
    local talents = {}
    
    for achievementId, achievement in pairs(achievements) do
        if achievement:IsTalentAchievement() then
            talents[achievementId] = achievement
        end
    end
    
    return talents
end

--- 获取玩家普通成就列表
---@param playerId string 玩家ID
---@return table<string, Achievement>
function AchievementMgr.GetPlayerNormalAchievements(playerId)
    local achievements = AchievementMgr.server_player_achievement_data[playerId] or {}
    local normals = {}
    
    for achievementId, achievement in pairs(achievements) do
        if not achievement:IsTalentAchievement() then
            normals[achievementId] = achievement
        end
    end
    
    return normals
end

-- 客户端同步 --------------------------------------------------------

--- 获取玩家成就同步数据
---@param playerId string 玩家ID
---@return table 客户端同步数据
function AchievementMgr.GetPlayerSyncData(playerId)
    local achievements = AchievementMgr.server_player_achievement_data[playerId] or {}
    local syncData = {}
    
    for achievementId, achievement in pairs(achievements) do
        local data = achievement:GetSyncData()
        -- 添加升级能力检查（需要玩家实例，这里暂时设为false）
        data.canUpgrade = false
        syncData[achievementId] = data
    end
    
    return {
        achievements = syncData,
        totalCount = AchievementMgr.GetPlayerAchievementCount(playerId)
    }
end

--- 同步玩家成就数据到客户端
---@param player table 玩家实例
function AchievementMgr.SyncToClient(player)
    if not player then
        return
    end
    
    local playerId = tostring(player.uin)
    local syncData = AchievementMgr.GetPlayerSyncData(playerId)
    
    -- 更新升级能力检查
    for achievementId, data in pairs(syncData.achievements) do
        data.canUpgrade = AchievementMgr.CanUpgradeAchievement(player, achievementId)
    end
    
    -- 发送同步事件（需要根据你的事件系统调整）
    -- ServerEventManager.SendToClient(player, "AchievementSync", syncData)
    
    gg.log("同步成就数据到客户端:", playerId, "成就数量:", syncData.totalCount)
end

--- 强制同步玩家成就到客户端
---@param playerId string 玩家ID
function AchievementMgr.ForceSyncToClient(playerId)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(tonumber(playerId))
    if player then
        AchievementMgr.SyncToClient(player)
    end
end

-- 批量操作 --------------------------------------------------------

--- 批量保存所有玩家成就数据
function AchievementMgr.BatchSaveAllPlayerAchievements()
    local count = 0
    for playerId in pairs(AchievementMgr.server_player_achievement_data) do
        AchievementMgr.SavePlayerAchievements(playerId, true)
        count = count + 1
    end
    gg.log("批量保存成就数据完成，保存了", count, "个玩家的数据")
end

--- 清空玩家成就数据（慎用）
---@param playerId string 玩家ID
function AchievementMgr.ClearPlayerAchievements(playerId)
    AchievementCloudDataMgr.ClearPlayerAchievements(playerId)
    AchievementMgr.server_player_achievement_data[playerId] = nil
    gg.log("清空玩家成就数据:", playerId)
end

-- 私有方法 --------------------------------------------------------

--- 恢复玩家成就实例
---@param playerId string 玩家ID
---@param saveData table 保存的成就数据
---@param player table 玩家实例
function AchievementMgr._RestorePlayerAchievements(playerId, saveData, player)
    if not AchievementMgr.server_player_achievement_data[playerId] then
        AchievementMgr.server_player_achievement_data[playerId] = {}
    end
    
    local ConfigLoader = require(MainStorage.Code.Common.Config.ConfigLoader)
    
    for achievementId, data in pairs(saveData) do
        -- 获取成就配置
        local achievementType = ConfigLoader.GetAchievement(achievementId)
        if achievementType then
            -- 创建成就实例
            local achievement = Achievement.New(
                achievementType,
                data.playerId,
                data.unlockTime,
                data.currentLevel
            )
            
            AchievementMgr.server_player_achievement_data[playerId][achievementId] = achievement
        else
            gg.log("警告：成就配置不存在，跳过加载:", achievementId)
        end
    end
end

--- 应用玩家所有成就效果
---@param player table 玩家实例
function AchievementMgr._ApplyAllPlayerAchievementEffects(player)
    local playerId = tostring(player.uin)
    local achievements = AchievementMgr.server_player_achievement_data[playerId] or {}
    
    for achievementId, achievement in pairs(achievements) do
        achievement:ApplyEffects(player)
    end
    
    gg.log("应用玩家所有成就效果完成:", playerId)
end

return AchievementMgr