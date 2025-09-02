-- MAchievementCom.lua
-- 成就系统指令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr) ---@type AchievementMgr
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class AchievementCommand
local AchievementCommand = {}

--- 主指令处理函数
---@param params table 指令参数
---@param player MPlayer 玩家实例
function AchievementCommand.main(params, player)
    local operationType = params["操作类型"]
    
    if operationType == "解锁天赋" then
        AchievementCommand.UnlockTalent(params, player)
    elseif operationType == "设置天赋等级" then
        AchievementCommand.SetTalentLevel(params, player)
    elseif operationType == "升级天赋" then
        AchievementCommand.UpgradeTalent(params, player)
    elseif operationType == "重置天赋" then
        AchievementCommand.ResetTalent(params, player)
    else
        gg.log("未知的成就操作类型:", operationType)
    end
end

--- 解锁天赋
---@param params table 指令参数
---@param player MPlayer 玩家实例
function AchievementCommand.UnlockTalent(params, player)
    local talentId = params["天赋ID"]
    local level = params["等级"] or 1
    
    if not talentId then
        gg.log("错误：缺少天赋ID参数")
        return
    end
    
    -- 获取玩家成就实例
    local playerAchievement = AchievementMgr.server_player_achievement_data[player.uin]
    if not playerAchievement then
        gg.log("错误：玩家成就数据不存在:", player.uin)
        return
    end
    
    -- 设置天赋等级（这会自动解锁天赋）
    playerAchievement:SetTalentLevel(talentId, level)
    
    -- 应用天赋效果
    playerAchievement:ApplyTalentEffect(talentId, player)
    
    gg.log(string.format("玩家[%s]解锁天赋[%s]成功，等级设置为%d", player.name, talentId, level))
    
    -- 向客户端发送成功通知
    -- player:SendHoverText(string.format("成功解锁天赋：%s (等级%d)", talentId, level))
end

--- 设置天赋等级
---@param params table 指令参数
---@param player MPlayer 玩家实例
function AchievementCommand.SetTalentLevel(params, player)
    local talentId = params["天赋ID"]
    local level = params["等级"]
    
    if not talentId or not level then
        gg.log("错误：缺少天赋ID或等级参数")
        return
    end
    
    -- 获取玩家成就实例
    local playerAchievement = AchievementMgr.server_player_achievement_data[player.uin]
    if not playerAchievement then
        gg.log("错误：玩家成就数据不存在:", player.uin)
        return
    end
    
    -- 移除旧等级效果
    local oldLevel = playerAchievement:GetTalentLevel(talentId)
    if oldLevel > 0 then
        playerAchievement:_RemoveTalentEffect(talentId, oldLevel, player)
    end
    
    -- 设置新等级
    playerAchievement:SetTalentLevel(talentId, level)
    
    -- 应用新等级效果
    playerAchievement:ApplyTalentEffect(talentId, player)
    
    gg.log(string.format("玩家[%s]天赋[%s]等级设置为%d", player.name, talentId, level))
    
    -- 向客户端发送成功通知
    -- player:SendHoverText(string.format("天赋等级设置成功：%s -> 等级%d", talentId, level))
end

--- 升级天赋
---@param params table 指令参数
---@param player MPlayer 玩家实例
function AchievementCommand.UpgradeTalent(params, player)
    local talentId = params["天赋ID"]
    
    if not talentId then
        gg.log("错误：缺少天赋ID参数")
        return
    end
    
    -- 获取玩家成就实例
    local playerAchievement = AchievementMgr.server_player_achievement_data[player.uin]
    if not playerAchievement then
        gg.log("错误：玩家成就数据不存在:", player.uin)
        return
    end
    
    -- 执行升级
    local success = playerAchievement:UpgradeTalent(talentId, player)
    
    if success then
        local newLevel = playerAchievement:GetTalentLevel(talentId)
        gg.log(string.format("玩家[%s]天赋[%s]升级成功，当前等级：%d", player.name, talentId, newLevel))
        -- player:SendHoverText(string.format("天赋升级成功：%s -> 等级%d", talentId, newLevel))
    else
        gg.log(string.format("玩家[%s]天赋[%s]升级失败", player.name, talentId))
        -- player:SendHoverText(string.format("天赋升级失败：%s", talentId))
    end
end

--- 重置天赋
---@param params table 指令参数
---@param player MPlayer 玩家实例
function AchievementCommand.ResetTalent(params, player)
    local talentId = params["天赋ID"]
    
    if not talentId then
        gg.log("错误：缺少天赋ID参数")
        return
    end
    
    -- 获取玩家成就实例
    local playerAchievement = AchievementMgr.server_player_achievement_data[player.uin]
    if not playerAchievement then
        gg.log("错误：玩家成就数据不存在:", player.uin)
        return
    end
    
    -- 执行重置
    playerAchievement:ResetTalent(talentId, player)
    
    gg.log(string.format("玩家[%s]天赋[%s]重置成功", player.name, talentId))
    -- player:SendHoverText(string.format("天赋重置成功：%s -> 等级1", talentId))
end

return AchievementCommand
