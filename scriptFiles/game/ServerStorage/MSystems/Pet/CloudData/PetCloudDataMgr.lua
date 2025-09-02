-- PetCloudDataMgr.lua
-- 宠物云数据结构管理器
-- 负责定义宠物数据的存储格式、序列化和反序列化逻辑

local game = game
local os = os

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService")   ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

---@class PetData
---@field petName string 宠物名称
---@field customName string 自定义名称
---@field level number 当前等级
---@field exp number 当前经验值
---@field starLevel number 星级
---@field learnedSkills table<string, boolean> 已学技能列表 {skillId1 = true, skillId2 = true}
---@field equipments table<number, string> 装备物品 {slot1 = itemId, slot2 = itemId}
---@field isActive boolean 是否为当前激活宠物
---@field mood number 心情值 (0-100)

---@class PlayerPetData
---@field activeSlots table<string, number> 激活的宠物槽位映射 {[装备栏ID] = 背包槽位ID}
---@field petList table<number, PetData> 宠物数据列表 {slotIndex = petData} 对应背包槽位的宠物
---@field petSlots number 宠物背包槽位数量
---@field unlockedEquipSlots number 玩家当前可携带(已解锁)的宠物栏位数量


---@class CloudPetDataAccessor
local CloudPetDataAccessor = {
    -- 云存储key配置
    CLOUD_KEY_PREFIX = "pet_player_cloud", -- 宠物数据key前缀
}

--- 加载玩家宠物数据
---@param uin number 玩家ID
---@return PlayerPetData 玩家宠物数据
function CloudPetDataAccessor:LoadPlayerPetData(uin)
    local ret, data = cloudService:GetTableOrEmpty(CloudPetDataAccessor.CLOUD_KEY_PREFIX .. uin)

    if ret and data and data.petList then
        return data
    else
        -- 创建默认宠物数据
        return {
            activeSlots = {},
            petList = {},
            petSlots = 50,
            unlockedEquipSlots = 3, -- 默认解锁1个栏位

        }
    end
end

--- 保存玩家宠物数据
---@param uin number 玩家ID
---@param petData PlayerPetData
---@return boolean 是否成功
function CloudPetDataAccessor:SavePlayerPetData(uin, petData)
    if not petData then
        return false
    end

    -- 保存到云存储
    cloudService:SetTableAsync(CloudPetDataAccessor.CLOUD_KEY_PREFIX .. uin, petData, function(success)
        if not success then
            --gg.log("保存玩家宠物数据失败", uin)
        else
            -- --gg.log("保存玩家宠物数据成功", uin)
        end
    end)

    return true
end

--- 清空玩家宠物数据
---@param uin number 玩家ID
---@return boolean 是否成功
function CloudPetDataAccessor:ClearPlayerPetData(uin)
    -- 创建空的宠物数据并保存
    local emptyPetData = {
        activeSlots = {},
        petList = {},
        petSlots = 50,
        unlockedEquipSlots = 3, -- 默认解锁3个栏位
    }

    -- 清空云存储数据
    cloudService:SetTableAsync(CloudPetDataAccessor.CLOUD_KEY_PREFIX .. uin, emptyPetData, function(success)
        if not success then
            gg.log("清空玩家宠物云数据失败", uin)
        else
            gg.log("清空玩家宠物云数据成功", uin)
        end
    end)

    return true
end

return CloudPetDataAccessor
