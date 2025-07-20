-- ConfigLoader.lua
-- 负责加载所有配置文件，并将其数据实例化为对应的Type对象
-- 这是一个单例模块，在游戏启动时初始化，为其他系统提供统一的配置数据访问接口

local MainStorage = game:GetService('MainStorage')

-- 引用所有 Type 的定义
local ItemType = require(MainStorage.Code.Common.TypeConfig.ItemType)
local SkillTypes = require(MainStorage.Code.Common.TypeConfig.SkillTypes) 
local EffectType = require(MainStorage.Code.Common.TypeConfig.EffectType)
local LevelType = require(MainStorage.Code.Common.TypeConfig.LevelType)
local SceneNodeType = require(MainStorage.Code.Common.TypeConfig.SceneNodeType)
local AchievementType = require(MainStorage.Code.Common.TypeConfig.AchievementType)
local PetType = require(MainStorage.Code.Common.TypeConfig.PetType)

-- 引用所有 Config 的原始数据
local ItemTypeConfig = require(MainStorage.Code.Common.Config.ItemTypeConfig)
local SkillConfig = require(MainStorage.Code.Common.Config.SkillConfig)
local EffectTypeConfig = require(MainStorage.Code.Common.Config.EffectTypeConfig)
local LevelConfig = require(MainStorage.Code.Common.Config.LevelConfig)
local SceneNodeConfig = require(MainStorage.Code.Common.Config.SceneNodeConfig)
local AchievementConfig = require(MainStorage.Code.Common.Config.AchievementConfig)
local PetConfig = require(MainStorage.Code.Common.Config.PetConfig)
-- local NpcConfig = require(MainStorage.Code.Common.Config.NpcConfig) -- 已移除
-- local ItemQualityConfig = require(MainStorage.Code.Common.Config.ItemQualityConfig) -- 已移除

---@class ConfigLoader
local ConfigLoader = {}

-- 用来存放实例化后的配置对象
ConfigLoader.Items = {}
ConfigLoader.Skills = {}
ConfigLoader.Effects = {}
ConfigLoader.Talents = {}
ConfigLoader.Levels = {}
ConfigLoader.ItemQualities = {}
ConfigLoader.Npcs = {}
ConfigLoader.SceneNodes = {}
ConfigLoader.Achievements = {}
ConfigLoader.Pets = {}

--- 一个通用的加载函数，避免重复代码
---@param configData table 从Config目录加载的原始数据
---@param typeClass table 从TypeConfig目录加载的类
---@param storageTable table 用来存储实例化后对象的表
---@param configName string 配置的名称，用于日志打印
function ConfigLoader.LoadConfig(configData, typeClass, storageTable, configName)
    -- 检查Type定义是否是一个有效的类（包含New方法）
    if not typeClass or not typeClass.New then
        print(string.format("Warning: No valid Type class found for %s. Raw data will be stored.", configName))
        -- 如果没有对应的Type类，可以选择直接存储原始数据
        for id, data in pairs(configData.Data) do
            storageTable[id] = data
        end
        return
    end

    -- 实例化配置
    for id, data in pairs(configData.Data) do
        -- 使用配置的键 (例如 "加速卡", "火球") 作为唯一ID
        storageTable[id] = typeClass.New(data)
    end
end

-- 模块初始化函数，一次性加载所有配置
function ConfigLoader.Init()
    print("开始装载配置")

    ConfigLoader.LoadConfig(ItemTypeConfig, ItemType, ConfigLoader.Items, "Item")
    ConfigLoader.LoadConfig(SkillConfig, SkillTypes, ConfigLoader.Skills, "Skill")
    ConfigLoader.LoadConfig(EffectTypeConfig, EffectType, ConfigLoader.Effects, "Effect")
    ConfigLoader.LoadConfig(LevelConfig, LevelType, ConfigLoader.Levels, "Level")
    ConfigLoader.LoadConfig(SceneNodeConfig, SceneNodeType, ConfigLoader.SceneNodes, "SceneNode")
    ConfigLoader.LoadConfig(AchievementConfig, AchievementType, ConfigLoader.Achievements, "Achievement")
    ConfigLoader.LoadConfig(PetConfig, PetType, ConfigLoader.Pets, "Pet")
    -- ConfigLoader.LoadConfig(ItemQualityConfig, nil, ConfigLoader.ItemQualities, "ItemQuality") -- 暂无ItemQualityType
    -- ConfigLoader.LoadConfig(MailConfig, nil, ConfigLoader.Mails, "Mail") -- 暂无MailType
    -- ConfigLoader.LoadConfig(NpcConfig, nil, ConfigLoader.Npcs, "Npc") -- 暂无NpcType
end

--- 提供给外部系统访问实例化后数据的接口
---@param id string
---@return ItemType
function ConfigLoader.GetItem(id)
    return ConfigLoader.Items[id]
end

---@return table<string, ItemType>
function ConfigLoader.GetAllItems()
    return ConfigLoader.Items
end

---@param id string
---@return table -- SkillTypes 实现后应返回 SkillType
function ConfigLoader.GetSkill(id)
    return ConfigLoader.Skills[id]
end

---@param id string
---@return EffectType
function ConfigLoader.GetEffect(id)
    return ConfigLoader.Effects[id]
end

---@param id string
---@return table
function ConfigLoader.GetItemQuality(id)
    return ConfigLoader.ItemQualities[id]
end

function ConfigLoader.GetLevel(id)
    return ConfigLoader.Levels[id]
end

---@param id string
---@return SceneNodeType
function ConfigLoader.GetSceneNode(id)
    return ConfigLoader.SceneNodes[id]
end

---@return table<string, SceneNodeType>
function ConfigLoader.GetAllSceneNodes()
    return ConfigLoader.SceneNodes
end

---@param id string
---@return AchievementType
function ConfigLoader.GetAchievement(id)
    return ConfigLoader.Achievements[id]
end

---@return table<string, AchievementType>
function ConfigLoader.GetAllAchievements()
    return ConfigLoader.Achievements
end

---@param id string
---@return PetType
function ConfigLoader.GetPet(id)
    return ConfigLoader.Pets[id]
end

---@return table<string, PetType>
function ConfigLoader.GetAllPets()
    return ConfigLoader.Pets
end

return ConfigLoader 