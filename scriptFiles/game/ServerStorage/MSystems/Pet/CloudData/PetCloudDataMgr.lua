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
---@field activePetId string 当前激活的宠物ID
---@field petList table<number, PetData> 宠物数据列表 {slotIndex = petData} 对应背包槽位的宠物
---@field petSlots number 宠物背包槽位数量


---@class CloudPetDataAccessor
local CloudPetDataAccessor = {}

--- 加载玩家宠物数据
---@param uin number 玩家ID
---@return PlayerPetData 玩家宠物数据
function CloudPetDataAccessor:LoadPlayerPetData(uin)
    local ret, data = cloudService:GetTableOrEmpty('pet_player_' .. uin)

    if ret and data and data.petList then
        return data
    else
        -- 创建默认宠物数据
        return {
            activePetId = "",
            petList = {},
            petSlots = 50,
       
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
    cloudService:SetTableAsync('pet_player_' .. uin, petData, function(success)
        if not success then
            gg.log("保存玩家宠物数据失败", uin)
        else
            gg.log("保存玩家宠物数据成功", uin)
        end
    end)

    return true
end



return CloudPetDataAccessor