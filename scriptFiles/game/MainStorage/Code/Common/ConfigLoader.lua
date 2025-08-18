-- ConfigLoader.lua
-- 负责加载所有配置文件，并将其数据实例化为对应的Type对象
-- 这是一个单例模块，在游戏启动时初始化，为其他系统提供统一的配置数据访问接口

local MainStorage = game:GetService('MainStorage')

-- 引用所有 Type 的定义

local ItemType = require(MainStorage.Code.Common.TypeConfig.ItemType)
local SkillTypes = require(MainStorage.Code.Common.TypeConfig.SkillTypes) 
local EffectType = require(MainStorage.Code.Common.TypeConfig.EffectType)
local LevelType = require(MainStorage.Code.Common.TypeConfig.LevelType)
local PetType = require(MainStorage.Code.Common.TypeConfig.PetType)
local TrailType = require(MainStorage.Code.Common.TypeConfig.TrailType)
local PlayerInitType = require(MainStorage.Code.Common.TypeConfig.PlayerInitType)
local SceneNodeType = require(MainStorage.Code.Common.TypeConfig.SceneNodeType)
local AchievementType = require(MainStorage.Code.Common.TypeConfig.AchievementType)
local ActionCostType = require(MainStorage.Code.Common.TypeConfig.ActionCostType) ---@type ActionCostType
local RewardType = require(MainStorage.Code.Common.TypeConfig.RewardType) ---@type RewardType
local LotteryType = require(MainStorage.Code.Common.TypeConfig.LotteryType) ---@type LotteryType
local ShopItemType = require(MainStorage.Code.Common.TypeConfig.ShopItemType) ---@type ShopItemType
local TeleportPointType = require(MainStorage.Code.Common.TypeConfig.TeleportPointType) ---@type TeleportPointType

-- 引用所有 Config 的原始数据
local ActionCostConfig = require(MainStorage.Code.Common.Config.ActionCostConfig)

local ItemTypeConfig = require(MainStorage.Code.Common.Config.ItemTypeConfig)
local SkillConfig = require(MainStorage.Code.Common.Config.SkillConfig)
local EffectTypeConfig = require(MainStorage.Code.Common.Config.EffectTypeConfig)
local LevelConfig = require(MainStorage.Code.Common.Config.LevelConfig)
local SceneNodeConfig = require(MainStorage.Code.Common.Config.SceneNodeConfig)
local AchievementConfig = require(MainStorage.Code.Common.Config.AchievementConfig)
local PetConfig = require(MainStorage.Code.Common.Config.PetConfig)
local PartnerConfig = require(MainStorage.Code.Common.Config.PartnerConfig)
local WingConfig = require(MainStorage.Code.Common.Config.WingConfig)
local TrailConfig = require(MainStorage.Code.Common.Config.TrailConfig)
local PlayerInitConfig = require(MainStorage.Code.Common.Config.PlayerInitConfig)
local VariableNameConfig = require(MainStorage.Code.Common.Config.VariableNameConfig)
local GameModeConfig = require(MainStorage.Code.Common.Config.GameModeConfig)
local RewardConfig = require(MainStorage.Code.Common.Config.RewardConfig)
local LotteryConfig = require(MainStorage.Code.Common.Config.LotteryConfig)
local ShopItemConfig = require(MainStorage.Code.Common.Config.ShopItemConfig)
local TeleportPointConfig = require(MainStorage.Code.Common.Config.TeleportPointConfig)

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
ConfigLoader.Partners = {} -- 新增伙伴配置存储
ConfigLoader.Wings = {} -- 新增翅膀配置存储
ConfigLoader.Trails = {} -- 新增尾迹配置存储
ConfigLoader.TeleportPoints = {} -- 新增传送点配置存储
ConfigLoader.ActionCosts = {}
ConfigLoader.ItemTypes = {}
ConfigLoader.PlayerInits = {}
ConfigLoader.VariableNames = {}
ConfigLoader.GameModes = {}
ConfigLoader.Rewards = {} -- 新增奖励配置存储
ConfigLoader.Lotteries = {} -- 新增抽奖配置存储
ConfigLoader.ShopItems = {} -- 新增商城商品配置存储
ConfigLoader.MiniShopItems = {} -- 迷你币商品映射表：miniItemId -> ShopItemType

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
    ConfigLoader.LoadConfig(ActionCostConfig, ActionCostType, ConfigLoader.ActionCosts, "ActionCost")
    ConfigLoader.LoadConfig(ItemTypeConfig, ItemType, ConfigLoader.Items, "Item")
    ConfigLoader.LoadConfig(LevelConfig, LevelType, ConfigLoader.Levels, "Level")
    ConfigLoader.LoadConfig(PartnerConfig, PetType, ConfigLoader.Partners, "Partner")
    ConfigLoader.LoadConfig(PetConfig, PetType, ConfigLoader.Pets, "Pet")
    ConfigLoader.LoadConfig(WingConfig, PetType, ConfigLoader.Wings, "Wing")
    ConfigLoader.LoadConfig(TrailConfig, TrailType, ConfigLoader.Trails, "Trail")
    ConfigLoader.LoadConfig(PlayerInitConfig, PlayerInitType, ConfigLoader.PlayerInits, "PlayerInit")
    ConfigLoader.LoadConfig(SceneNodeConfig, SceneNodeType, ConfigLoader.SceneNodes, "SceneNode")
    ConfigLoader.LoadConfig(VariableNameConfig,nil,ConfigLoader.VariableNames,"VariableName")
    ConfigLoader.LoadConfig(GameModeConfig,nil,ConfigLoader.GameModes,"GameMode")
    ConfigLoader.LoadConfig(SkillConfig, SkillTypes, ConfigLoader.Skills, "Skill")
    ConfigLoader.LoadConfig(AchievementConfig, AchievementType, ConfigLoader.Achievements, "Achievement")
    ConfigLoader.LoadConfig(RewardConfig, RewardType, ConfigLoader.Rewards, "Reward")
    ConfigLoader.LoadConfig(LotteryConfig, LotteryType, ConfigLoader.Lotteries, "Lottery")
    ConfigLoader.LoadConfig(ShopItemConfig, ShopItemType, ConfigLoader.ShopItems, "ShopItem")
    ConfigLoader.LoadConfig(TeleportPointConfig, TeleportPointType, ConfigLoader.TeleportPoints, "TeleportPoint")

    -- 构建迷你币商品映射表
    ConfigLoader.BuildMiniShopMapping()

    -- ConfigLoader.LoadConfig(ItemQualityConfig, nil, ConfigLoader.ItemQualities, "ItemQuality") -- 暂无ItemQualityType
    -- ConfigLoader.LoadConfig(MailConfig, nil, ConfigLoader.Mails, "Mail") -- 暂无MailType
    -- ConfigLoader.LoadConfig(NpcConfig, nil, ConfigLoader.Npcs, "Npc") -- 暂无NpcType
end

--- 构建迷你币商品映射表
--- 提取所有配置了迷你币支付且有miniItemId的商品，建立miniItemId -> ShopItemType的映射
function ConfigLoader.BuildMiniShopMapping()
    print("开始构建迷你币商品映射表")
    local count = 0
    
    for shopItemId, shopItem in pairs(ConfigLoader.ShopItems) do
        -- 检查是否配置了迷你币类型且有有效的miniItemId
        if shopItem.price and 
           shopItem.price.miniCoinType == "迷你币" and
           shopItem.specialProperties and 
           shopItem.specialProperties.miniItemId and 
           shopItem.specialProperties.miniItemId > 0 then
            
            local miniItemId = shopItem.specialProperties.miniItemId
            
            -- 检查是否有重复的miniItemId
            if ConfigLoader.MiniShopItems[miniItemId] then
                print(string.format("警告：发现重复的迷你商品ID %d，商品：%s 和 %s", 
                    miniItemId, 
                    ConfigLoader.MiniShopItems[miniItemId].configName,
                    shopItem.configName))
            end
            
            -- 建立映射关系
            ConfigLoader.MiniShopItems[miniItemId] = shopItem
            count = count + 1
            
            print(string.format("注册迷你币商品：ID=%d, 名称=%s, 价格=%d迷你币", 
                miniItemId, 
                shopItem.configName, 
                shopItem.price.miniCoinAmount or 0))
        end
    end
    
    print(string.format("迷你币商品映射表构建完成，共注册 %d 个商品", count))
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
---@return PlayerInitType
function ConfigLoader.GetPlayerInit(id)
    return ConfigLoader.PlayerInits[id]
end

---@return table<string, PlayerInitType>
function ConfigLoader.GetAllPlayerInits()
    return ConfigLoader.PlayerInits
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

--- 按所属场景与场景类型筛选场景节点
---@param belongScene string|nil 所属场景，nil 表示不过滤
---@param sceneType string|nil 场景类型，nil 表示不过滤
---@return SceneNodeType[] 满足条件的场景节点列表
function ConfigLoader.GetSceneNodesBy(belongScene, sceneType)
    local result = {}
    for _, node in pairs(ConfigLoader.SceneNodes) do
        local matchScene = (belongScene == nil) or (node.belongScene == belongScene)
        local matchType = (sceneType == nil) or (node.sceneType == sceneType)
        if matchScene and matchType then
            table.insert(result, node)
        end
    end
    return result
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

---@param id string
---@return PetType 伙伴配置与宠物格式相同，所以返回PetType
function ConfigLoader.GetPartner(id)
    return ConfigLoader.Partners[id]
end

---@return table<string, PetType> 伙伴配置与宠物格式相同，所以返回PetType表
function ConfigLoader.GetAllPartners()
    return ConfigLoader.Partners
end

---@param id string
---@return PetType 翅膀配置与宠物格式相同，所以返回PetType
function ConfigLoader.GetWing(id)
    return ConfigLoader.Wings[id]
end

---@return table<string, PetType> 翅膀配置与宠物格式相同，所以返回PetType表
function ConfigLoader.GetAllWings()
    return ConfigLoader.Wings
end

---@param id string
---@return TrailType 尾迹配置
function ConfigLoader.GetTrail(id)
    return ConfigLoader.Trails[id]
end

---@return table<string, TrailType> 尾迹配置表
function ConfigLoader.GetAllTrails()
    return ConfigLoader.Trails
end

---@param id string
---@return ActionCostType
function ConfigLoader.GetActionCost(id)
    return ConfigLoader.ActionCosts[id]
end

---@param id string
---@return RewardType
function ConfigLoader.GetReward(id)
    return ConfigLoader.Rewards[id]
end

---@return table<string, RewardType>
function ConfigLoader.GetAllRewards()
    return ConfigLoader.Rewards
end

---@param id string
---@return LotteryType
function ConfigLoader.GetLottery(id)
    return ConfigLoader.Lotteries[id]
end

---@return table<string, LotteryType>
function ConfigLoader.GetAllLotteries()
    return ConfigLoader.Lotteries
end

---@param id string
---@return ShopItemType
function ConfigLoader.GetShopItem(id)
    return ConfigLoader.ShopItems[id]
end

---@return table<string, ShopItemType>
function ConfigLoader.GetAllShopItems()
    return ConfigLoader.ShopItems
end

---@param id string
---@return TeleportPointType
function ConfigLoader.GetTeleportPoint(id)
    return ConfigLoader.TeleportPoints[id]
end

---@return table<string, TeleportPointType>
function ConfigLoader.GetAllTeleportPoints()
    return ConfigLoader.TeleportPoints
end

---@param category string 商品分类（如"伙伴"、"宠物"、"翅膀"等）
---@return ShopItemType[] 该分类下的所有商品（按品质排序）
function ConfigLoader.GetShopItemsByCategory(category)
    local itemsArray = {}
    
    -- 收集该分类下的所有商品
    for id, shopItem in pairs(ConfigLoader.ShopItems) do
        if shopItem.category == category then
            table.insert(itemsArray, shopItem)
        end
    end
    
    -- 按品质等级排序
    local qualityOrder = {UR = 1, SSR = 2, SR = 3, R = 4, N = 5}
    table.sort(itemsArray, function(a, b)
        local qualityA = a:GetBackgroundStyle() or "N"
        local qualityB = b:GetBackgroundStyle() or "N"
        local orderA = qualityOrder[qualityA] or 6
        local orderB = qualityOrder[qualityB] or 6
        return orderA < orderB
    end)
    
    return itemsArray
end

--- 根据迷你商品ID获取对应的商城商品配置
---@param miniItemId number 迷你商品ID
---@return ShopItemType|nil 商城商品配置
function ConfigLoader.GetMiniShopItem(miniItemId)
    return ConfigLoader.MiniShopItems[miniItemId]
end

--- 获取所有迷你币商品映射
---@return table<number, ShopItemType> 迷你币商品映射表
function ConfigLoader.GetAllMiniShopItems()
    return ConfigLoader.MiniShopItems
end

--- 检查指定迷你商品ID是否存在
---@param miniItemId number 迷你商品ID
---@return boolean 是否存在
function ConfigLoader.HasMiniShopItem(miniItemId)
    return ConfigLoader.MiniShopItems[miniItemId] ~= nil
end

--- 获取迷你币商品数量
---@return number 迷你币商品数量
function ConfigLoader.GetMiniShopItemCount()
    local count = 0
    for _ in pairs(ConfigLoader.MiniShopItems) do
        count = count + 1
    end
    return count
end

return ConfigLoader 