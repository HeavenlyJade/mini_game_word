-- WingCloudDataMgr.lua
-- 翅膀云数据结构管理器
-- 负责定义翅膀数据的存储格式、序列化和反序列化逻辑

local game = game
local os = os

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService")   ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

---@class WingData
---@field wingName string 翅膀名称
---@field customName string 自定义名称
---@field level number 当前等级
---@field exp number 当前经验值
---@field starLevel number 星级
---@field learnedSkills table<string, boolean> 已学技能列表 {skillId1 = true, skillId2 = true}
---@field equipments table<number, string> 装备物品 {slot1 = itemId, slot2 = itemId}
---@field isActive boolean 是否为当前激活翅膀
---@field mood number 心情值 (0-100)

---@class PlayerWingData
---@field activeSlots table<string, number> 激活的翅膀槽位映射 {[装备栏ID] = 背包槽位ID}
---@field wingList table<number, WingData> 翅膀数据列表 {slotIndex = wingData} 对应背包槽位的翅膀
---@field wingSlots number 翅膀背包槽位数量
---@field unlockedEquipSlots number 玩家当前可携带(已解锁)的翅膀栏位数量

---@class CloudWingDataAccessor
local CloudWingDataAccessor = {
    -- 云存储key配置
    CLOUD_KEY_PREFIX = "wing_player_clound", -- 翅膀数据key前缀
}

--- 加载玩家翅膀数据
---@param uin number 玩家ID
---@return PlayerWingData 玩家翅膀数据
function CloudWingDataAccessor:LoadPlayerWingData(uin)
    local ret, data = cloudService:GetTableOrEmpty(CloudWingDataAccessor.CLOUD_KEY_PREFIX .. uin)

    if ret and data and data.wingList then
        return data
    else
        -- 创建默认翅膀数据
        return {
            activeSlots = {},
            wingList = {},
            wingSlots = 30,
            unlockedEquipSlots = 1, -- 默认解锁1个栏位
        }
    end
end

--- 保存玩家翅膀数据
---@param uin number 玩家ID
---@param wingData PlayerWingData
---@return boolean 是否成功
function CloudWingDataAccessor:SavePlayerWingData(uin, wingData)
    if not wingData then
        return false
    end

    -- 保存到云存储
    cloudService:SetTableAsync(CloudWingDataAccessor.CLOUD_KEY_PREFIX .. uin, wingData, function(success)
        if not success then
            --gg.log("保存玩家翅膀数据失败", uin)
        else
            -- --gg.log("保存玩家翅膀数据成功", uin)
        end
    end)

    return true
end

--- 清空玩家翅膀数据
---@param uin number 玩家ID
---@return boolean 是否成功
function CloudWingDataAccessor:ClearPlayerWingData(uin)
    -- 创建空的翅膀数据并保存
    local emptyWingData = {
        activeSlots = {},
        wingList = {},
        wingSlots = 30,
        unlockedEquipSlots = 1, -- 默认解锁1个栏位
    }

    -- 清空云存储数据
    cloudService:SetTableAsync(CloudWingDataAccessor.CLOUD_KEY_PREFIX .. uin, emptyWingData, function(success)
        if not success then
            gg.log("清空玩家翅膀云数据失败", uin)
        else
            gg.log("清空玩家翅膀云数据成功", uin)
        end
    end)

    return true
end

return CloudWingDataAccessor
