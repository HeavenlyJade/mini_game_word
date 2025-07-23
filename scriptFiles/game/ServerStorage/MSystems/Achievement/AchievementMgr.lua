-- AchievementMgr.lua
-- 成就管理器 - 简化版，只保留核心功能

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local PlayerAchievement = require(ServerStorage.MSystems.Achievement.Achievement) ---@type PlayerAchievement
local AchievementCloudDataMgr = require(ServerStorage.MSystems.Achievement.AchievementCloudDataMgr) ---@type AchievementCloudDataMgr
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class AchievementMgr
local AchievementMgr = {
    server_player_achievement_data = {}, ---@type table<number, PlayerAchievement> [playerId] = PlayerAchievement实例
}

-- 玩家生命周期 --------------------------------------------------------

--- 玩家上线处理
---@param playerId number 玩家ID
function AchievementMgr.OnPlayerJoin(playerId)
    
    -- 从云端加载数据
    local success, achievementData = AchievementCloudDataMgr.LoadPlayerAchievements(playerId)
    
    -- 创建玩家成就实例
    local playerAchievement = PlayerAchievement.New() ---@type PlayerAchievement
    playerAchievement:OnInit(playerId)
    
    -- 恢复数据
    if success and achievementData then
        playerAchievement:RestoreFromSaveData(achievementData)
        gg.log("加载玩家成就数据:", playerId)
    else
        gg.log("初始化新玩家成就数据:", playerId)
    end
    
    -- 存储到管理器
    AchievementMgr.server_player_achievement_data[playerId] = playerAchievement
    
    -- 应用天赋效果（变量系统在PlayerAchievement内部管理）
    local player = MServerDataManager.getPlayerInfoByUin(playerId)
    playerAchievement:ApplyAllTalentEffects(player)
end


--- 玩家离线处理
---@param playerId number 玩家ID
function AchievementMgr.OnPlayerLeave(playerId)
    
    -- 保存数据
    AchievementMgr.SavePlayerAchievements(playerId)
    
    -- 清理内存
    AchievementMgr.server_player_achievement_data[playerId] = nil
    
    gg.log("玩家离线，清理成就数据:", playerId)
end

-- 数据保存 --------------------------------------------------------

--- 保存玩家成就数据
---@param playerId number 玩家ID
function AchievementMgr.SavePlayerAchievements(playerId)
    local playerAchievement = AchievementMgr.server_player_achievement_data[playerId]
    if not playerAchievement then
        return
    end
    
    local saveData = playerAchievement:GetSaveData()
    AchievementCloudDataMgr.SavePlayerAchievements(playerId, saveData)
end

-- 天赋操作 --------------------------------------------------------

--- 获取天赋等级
---@param playerId number 玩家ID
---@param talentId string 天赋ID
---@return number 天赋等级
function AchievementMgr.GetTalentLevel(playerId, talentId)
    local playerAchievement = AchievementMgr.server_player_achievement_data[playerId]
    return playerAchievement and playerAchievement:GetTalentLevel(talentId) or 0
end

--- 升级天赋
---@param playerId number 玩家ID
---@param talentId string 天赋ID
---@return boolean 是否升级成功
function AchievementMgr.UpgradeTalent(playerId, talentId)
    local playerAchievement = AchievementMgr.server_player_achievement_data[playerId]
    
    if playerAchievement then
        return playerAchievement:UpgradeTalent(talentId)
    end
    
    return false
end

--- 重置所有天赋
---@param playerId number 玩家ID
function AchievementMgr.ResetAllTalents(playerId)
    local playerAchievement = AchievementMgr.server_player_achievement_data[playerId]
    
    if playerAchievement then
        playerAchievement:ResetAllTalents()
    end
end

-- 普通成就操作 --------------------------------------------------------

--- 解锁成就
---@param playerId number 玩家ID
---@param achievementId string 成就ID
---@return boolean 是否解锁成功
function AchievementMgr.UnlockAchievement(playerId, achievementId)
    local playerAchievement = AchievementMgr.server_player_achievement_data[playerId]
    
    if playerAchievement then
        return playerAchievement:UnlockNormalAchievement(achievementId)
    end
    
    return false
end

--- 检查成就是否已解锁
---@param playerId number 玩家ID
---@param achievementId string 成就ID
---@return boolean 是否已解锁
function AchievementMgr.HasAchievement(playerId, achievementId)
    local playerAchievement = AchievementMgr.server_player_achievement_data[playerId]
    
    if playerAchievement then
        return playerAchievement:IsNormalAchievementUnlocked(achievementId)
    end
    
    return false
end

-- 定时保存 --------------------------------------------------------

local function SaveAllPlayerAchievements()
    local count = 0
    for playerId in pairs(AchievementMgr.server_player_achievement_data) do
        AchievementMgr.SavePlayerAchievements(playerId)
        count = count + 1
    end
    gg.log("定时保存成就数据完成，保存了", count, "个玩家的数据")
end

-- 定时器
local saveTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
saveTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
saveTimer.Name = 'ACHIEVEMENT_SAVE_ALL'
saveTimer.Delay = 60
saveTimer.Loop = true
saveTimer.Interval = 60
saveTimer.Callback = SaveAllPlayerAchievements
saveTimer:Start()

return AchievementMgr