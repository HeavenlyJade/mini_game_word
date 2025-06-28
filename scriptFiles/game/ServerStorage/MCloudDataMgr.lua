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
local cloudDataMgr = require(ServerStorage.MCloudDataMgr) ---@type MCloudDataMgr
local MServerDataManager = require(ServerStorage.MServerDataManager) ---@type MServerDataManager
local gg            = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg


local  CONST_CLOUD_SAVE_TIME = 30    --每60秒存盘一次

---@class MCloudDataMgr
local MCloudDataMgr = {
    last_time_player = 0,     --最后一次玩家存盘时间
    last_time_bag    = 0,     --最后一次背包存盘时间
}

function SaveAll()
    for _, player in pairs(MServerDataManager.server_players_list) do
        player:leaveGame()
    end
end


--读取玩家技能数据
function MCloudDataMgr.ReadSkillData( uin_ )
    local ret_, ret2_ = cloudService:GetTableOrEmpty( 'sk' .. uin_ )
    gg.log( '获取玩家技能数据信息', 'pd' .. uin_, ret_, ret2_ )
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
    local ret_, ret2_ = cloudService:GetTableOrEmpty( 'pd' .. uin_ )

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

    if  force_ == false then
        local now_ = os.time()
        if  now_ - MCloudDataMgr.last_time_player < CONST_CLOUD_SAVE_TIME then
            return
        else
            MCloudDataMgr.last_time_player = now_
        end
    end


    local player_ = MServerDataManager.server_players_list[ uin_ ]
    if  player_ then
        local data_ = {
            uin   = uin_,
            exp   = player_.exp,
            level = player_.level,
            vars = player_.variables
        }
        cloudService:SetTableAsync( 'pd' .. uin_, data_, function ( ret_ )
        end )
    end
end


-- 读取玩家的背包数据
-- 新格式: ret2_ { items={ material=[{itemType="material", name="铁矿", amount=10, ...}], weapon=[{...}] } }
---@return number, Bag 返回值: 0表示成功, 1表示失败, 背包数据
function MCloudDataMgr.ReadPlayerBag( player )
    local Bag = require(ServerStorage.MSystems.Bag.Bag) ---@type Bag
    local ret_, ret2_ = cloudService:GetTableOrEmpty( 'inv' .. player.uin )
    print("读取玩家背包数据", 'inv' .. player.uin, ret_, ret2_)
    
    if ret_ then
        gg.log("读取玩家背包数据", ret2_)
        local bag = Bag.New(player)
        
        if ret2_ then
            -- 检查数据格式并进行兼容性处理
            local bagData = MCloudDataMgr.ConvertBagDataFormat(ret2_)
            bag:Load(bagData)
            return 0, bag
        end
        
        return 0, bag
    else
        return 1, Bag.New(player)       --数据失败，踢玩家下线，不然数据洗白了
    end
end

-- 转换背包数据格式，兼容旧格式
---@param data table 原始背包数据
---@return table 转换后的背包数据
function MCloudDataMgr.ConvertBagDataFormat(data)
    if not data or not data.items then
        return { items = {} }
    end
    
    -- 检查是否已经是新格式 (ItemCategory -> ItemData[])
    local isNewFormat = false
    for category, itemList in pairs(data.items) do
        if type(itemList) == "table" and itemList[1] and itemList[1].name then
            isNewFormat = true
            break
        end
    end
    
    if isNewFormat then
        -- 已经是新格式，直接返回
        gg.log("背包数据已经是新格式")
        return data
    end
    
    -- 转换旧格式到新格式
    gg.log("转换背包数据格式从旧格式到新格式")
    local newData = { items = {} }
    
    for category, slots in pairs(data.items) do
        if type(slots) == "table" then
            newData.items[category] = {}
            for slot, itemData in pairs(slots) do
                if itemData and type(itemData) == "table" then
                    -- 确保物品数据包含必要字段
                    local convertedItem = {
                        itemType = itemData.itype or category,
                        name = itemData.name or itemData.itype or "未知物品",
                        amount = itemData.amount or 1,
                        enhanceLevel = itemData.el or 0,
                        uuid = itemData.uuid or "",
                        quality = itemData.quality,
                        level = itemData.level or 1,
                        pos = itemData.pos or 0,
                        itype = itemData.itype or category
                    }
                    table.insert(newData.items[category], convertedItem)
                end
            end
        end
    end
    
    return newData
end


-- 读取玩家的任务配置
function MCloudDataMgr.ReadGameTaskData(player)
    local ret_, ret2_ = cloudService:GetTableOrEmpty('game_task' .. player.uin)
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

    cloudService:SetTableAsync('game_task' .. player.uin, data_, function(ret_)
    end)
end


function MCloudDataMgr.SaveSkillConfig(player)
    local skillData = {
        uin = player.uin,
        skills = {}
    }
    -- 保存所有技能数据
    for skillId, skill in pairs(player.skills) do
        skillData.skills[skillId] = {
            skill = skill.skillType.name,
            level = skill.level,
            slot = skill.equipSlot,
            star_level = skill.star_level,
            growth = skill.growth
        }
    end
    cloudService:SetTableAsync( 'sk' .. player.uin, skillData, function ( ret_ )
    end )
end
return MCloudDataMgr
