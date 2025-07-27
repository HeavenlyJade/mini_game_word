-- PartnerCloudDataMgr.lua
-- 伙伴云数据结构管理器
-- 负责定义伙伴数据的存储格式、序列化和反序列化逻辑

local game = game
local os = os

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService")   ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

---@class PartnerData
---@field partnerName string 伙伴名称
---@field customName string 自定义名称
---@field level number 当前等级
---@field exp number 当前经验值
---@field starLevel number 星级
---@field learnedSkills table<string, boolean> 已学技能列表 {skillId1 = true, skillId2 = true}
---@field equipments table<number, string> 装备物品 {slot1 = itemId, slot2 = itemId}
---@field isActive boolean 是否为当前激活伙伴
---@field mood number 心情值 (0-100)

---@class PlayerPartnerData
---@field activePartnerSlot number 当前激活的伙伴槽位 (0表示无激活)
---@field partnerList table<number, PartnerData> 伙伴数据列表 {slotIndex = partnerData} 对应背包槽位的伙伴
---@field partnerSlots number 伙伴背包槽位数量

---@class CloudPartnerDataAccessor
local CloudPartnerDataAccessor = {}

--- 加载玩家伙伴数据
---@param uin number 玩家ID
---@return PlayerPartnerData 玩家伙伴数据
function CloudPartnerDataAccessor:LoadPlayerPartnerData(uin)
    local ret, data = cloudService:GetTableOrEmpty('partner_player_' .. uin)

    if ret and data and data.partnerList then
        return data
    else
        -- 创建默认伙伴数据
        return {
            activePartnerSlot = 0,
            partnerList = {},
            partnerSlots = 30,
        }
    end
end

--- 保存玩家伙伴数据
---@param uin number 玩家ID
---@param partnerData PlayerPartnerData
---@return boolean 是否成功
function CloudPartnerDataAccessor:SavePlayerPartnerData(uin, partnerData)
    if not partnerData then
        return false
    end

    -- 保存到云存储
    cloudService:SetTableAsync('partner_player_' .. uin, partnerData, function(success)
        if not success then
            gg.log("保存玩家伙伴数据失败", uin)
        else
            -- gg.log("保存玩家伙伴数据成功", uin)
        end
    end)

    return true
end

return CloudPartnerDataAccessor