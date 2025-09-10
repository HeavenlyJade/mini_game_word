--- 管理云数据存储部分
--- V109 miniw-haima


local print        = print
local setmetatable = setmetatable
local math         = math
local game         = game
local pairs        = pairs
local SandboxNode  = SandboxNode ---@type SandboxNode

local MainStorage   = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local cloudService      = game:GetService("CloudService")     --- @type CloudService
-- MServerDataManager
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local gg            = require(MainStorage.Code.Untils.MGlobal) ---@type gg


---@class MCloudDataMgr
local MCloudDataMgr = {
    last_time_player = {},     --最后一次玩家存盘时间
    -- 云存储key配置
    PLAYER_DATA_KEY_PREFIX = "player_cloud", -- 玩家数据key前缀
    SKILL_DATA_KEY_PREFIX = "skill_cloud", -- 技能数据key前缀
    GAME_TASK_KEY_PREFIX = "game_task_cloud", -- 游戏任务key前缀
}

function SaveAll()
    for _, player in pairs(MServerDataManager.server_players_list) do
        player:leaveGame()
    end
end


--读取玩家技能数据
function MCloudDataMgr.ReadSkillData( uin_ )
    local ret_, ret2_ = cloudService:GetTableOrEmpty( MCloudDataMgr.SKILL_DATA_KEY_PREFIX .. uin_ )
    --gg.log( '获取玩家技能数据信息', 'pd' .. uin_, ret_, ret2_ )
    if  ret_ then
        if  ret2_ and ret2_.uin == uin_ then
            return 0, ret2_
        end
        return 0, {}
    else
        return 1, {}       --数据失败，踢玩家下线，不然数据洗白了
    end
end




-- 读取玩家数据 等级 经验值
function MCloudDataMgr.ReadPlayerData( uin_ )
    local ret_, ret2_ = cloudService:GetTableOrEmpty( MCloudDataMgr.PLAYER_DATA_KEY_PREFIX .. uin_ )

    gg.log( '获取与玩家当前的经验和等级', 'pd' .. uin_, ret_, ret2_ )
    if  ret_ then
        if  ret2_ and ret2_.uin == uin_ then
            return 0, ret2_
        end
        return 0, {}
    else
        return 1, {}       --数据失败，踢玩家下线，不然数据洗白了
    end
end




-- 保存玩家数据 等级 经验值
-- force_:  立即存储，不检查时间间隔
function MCloudDataMgr.SavePlayerData( uin_,  force_ )


    local player_ = MServerDataManager.server_players_list[ uin_ ]
    if  player_ then
        local data_ = {
            uin   = uin_,
            exp   = player_.exp,
            level = player_.level,
            vars = player_.variables,
            isNew = true
        }
        cloudService:SetTableAsync( MCloudDataMgr.PLAYER_DATA_KEY_PREFIX .. uin_, data_, function ( ret_ )
        end )
    end
end




-- 读取玩家的任务配置
function MCloudDataMgr.ReadGameTaskData(player)
    local ret_, ret2_ = cloudService:GetTableOrEmpty(MCloudDataMgr.GAME_TASK_KEY_PREFIX .. player.uin)
    if ret_ then
        if ret2_ and ret2_.uin == player.uin then
            -- 重建任务
            for questId, questData in pairs(ret2_.quests) do
                local QuestConfig = require(MainStorage.code.common.config.QuestConfig) ---@type QuestConfig
                local quest = QuestConfig.Get(questId)  ---@type Quest
                if quest then
                    local AcceptedQuest = require(MainStorage.code.server.entity_types.player_data.AcceptedQuest)
                    local acceptedQuest = AcceptedQuest.New(quest, player)
                    acceptedQuest.progress = questData.progress
                    player.quests[questId] = acceptedQuest
                end
            end

            -- 设置已完成任务
            player.acceptedQuestIds = ret2_.acceptedQuestIds
            return 0
        end
    end

    -- 初始化空的任务数据
    player.quests = {}
    player.acceptedQuestIds = {}
    return 1
end

function MCloudDataMgr.SaveGameTaskData(player)
    -- 构建最小化的任务数据
    local questsData = {}
    for questId, quest in pairs(player.quests) do
        questsData[questId] = {
            progress = quest.progress
        }
    end

    local data_ = {
        uin = player.uin,
        quests = questsData,
        acceptedQuestIds = player.acceptedQuestIds
    }

    cloudService:SetTableAsync(MCloudDataMgr.GAME_TASK_KEY_PREFIX .. player.uin, data_, function(ret_)
    end)
end


function MCloudDataMgr.SaveSkillConfig(player)
    local skillData = {
        uin = player.uin,
        skills = {}
    }
    -- 保存所有技能数据
    if player.skills then
        for skillId, skill in pairs(player.skills) do
            skillData.skills[skillId] = {
                skill = skill.skillType.name,
                level = skill.level,
                slot = skill.equipSlot,
                star_level = skill.star_level,
                growth = skill.growth
            }
        end
    end
    cloudService:SetTableAsync( MCloudDataMgr.SKILL_DATA_KEY_PREFIX .. player.uin, skillData, function ( ret_ )
    end )
end

--- 检查玩家是否在其他房间中
---@param uin_ number 玩家UIN
---@param callback function 回调函数，参数为 (data_: table)
function MCloudDataMgr.CheckPlayerInOtherRoom(uin_, callback)
    -- 使用 CloudService 的 GetPlayerServer 方法查询玩家所在房间

end

--- 清空玩家核心数据（等级、经验、变量），同时处理在线和云端数据
---@param uin_ number 玩家UIN
---@return boolean
function MCloudDataMgr.ClearCorePlayerData(uin_)
    if not uin_ then
        --gg.log("ClearCorePlayerData: 无效的玩家UIN")
        return false
    end

    -- 1. 如果玩家在线，重置内存数据
    local player_ = MServerDataManager.server_players_list[uin_]
    if player_ then
        player_.level = 1
        player_.exp = 0
    
        if player_.variableSystem then
            -- 假设 variableSystem 有一个清空方法
            if player_.variableSystem.ClearAllVariables then
                 player_.variableSystem:ClearAllVariables()
            else
                player_.variables = {}
            end
        else
            player_.variables = {}
        end
        --gg.log("已重置在线玩家的内存基础数据:", player_.name)
    end

    -- 2. 清理云端数据
    local key = MCloudDataMgr.PLAYER_DATA_KEY_PREFIX .. uin_
    -- 设置为空表来清空数据
    cloudService:RemoveKeyAsync(key, function(success)
        if success then
            gg.log("成功清空玩家核心云端数据:", uin_)
        else
            --gg.log("清空玩家核心云端数据失败:", uin_)
        end
    end)

    return true
end

return MCloudDataMgr
