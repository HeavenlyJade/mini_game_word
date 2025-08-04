-- TrailCloudDataMgr.lua
-- 尾迹云数据结构管理器
-- 负责定义尾迹数据的存储格式、序列化和反序列化逻辑

local game = game
local os = os

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService")   ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

---@class TrailData
---@field trailName string 尾迹名称
---@field customName string 自定义名称
---@field level number 当前等级
---@field exp number 当前经验值
---@field starLevel number 星级
---@field equipments table<number, string> 装备物品 {slot1 = itemId, slot2 = itemId}
---@field isActive boolean 是否为当前激活尾迹
---@field isLocked boolean 是否已锁定

---@class PlayerTrailData
---@field activeSlots table<string, number> 激活的尾迹槽位映射 {[装备栏ID] = 背包槽位ID}
---@field companionList table<number, TrailData> 尾迹数据列表 {slotIndex = trailData} 对应背包槽位的尾迹
---@field trailSlots number 尾迹背包槽位数量
---@field unlockedEquipSlots number 玩家当前可携带(已解锁)的尾迹栏位数量

---@class CloudTrailDataAccessor
local CloudTrailDataAccessor = {}

--- 加载玩家尾迹数据
---@param uin number 玩家ID
---@return PlayerTrailData 玩家尾迹数据
function CloudTrailDataAccessor:LoadPlayerTrailData(uin)
    local ret, data = cloudService:GetTableOrEmpty('trail_player_' .. uin)

    if ret and data and data.companionList then
        return data
    else
        -- 创建默认尾迹数据
        return {
            activeSlots = {},
            companionList = {},
            trailSlots = 30,
            unlockedEquipSlots = 1, -- 默认解锁1个栏位
        }
    end
end

--- 保存玩家尾迹数据
---@param uin number 玩家ID
---@param trailData PlayerTrailData
---@return boolean 是否成功
function CloudTrailDataAccessor:SavePlayerTrailData(uin, trailData)
    if not trailData then
        return false
    end

    -- 保存到云存储
    cloudService:SetTableAsync('trail_player_' .. uin, trailData, function(success)
        if not success then
            --gg.log("保存玩家尾迹数据失败", uin)
        else
            -- --gg.log("保存玩家尾迹数据成功", uin)
        end
    end)

    return true
end

return CloudTrailDataAccessor 