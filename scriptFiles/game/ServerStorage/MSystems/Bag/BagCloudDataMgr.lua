--- 背包系统云数据管理器
--- 负责背包数据的云存储读取、保存和格式转换
--- V109 miniw-haima

local print        = print
local setmetatable = setmetatable
local math         = math
local game         = game
local pairs        = pairs
local SandboxNode  = SandboxNode ---@type SandboxNode

local MainStorage   = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")      
local cloudService = game:GetService("CloudService") ---@type CloudService
local gg = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg

local CONST_CLOUD_SAVE_TIME = 30 -- 每30秒存盘一次

---@class BagCloudDataMgr
local BagCloudDataMgr = {
    last_time_bag = 0, -- 最后一次背包存盘时间
}

-- 读取玩家的背包数据
-- 新格式: ret2_ { items={ material=[{itemType="material", name="铁矿", amount=10, ...}], weapon=[{...}] } }
---@param player MPlayer 玩家对象
---@return number, Bag 返回值: 0表示成功, 1表示失败, 背包数据
function BagCloudDataMgr.ReadPlayerBag(player)
    local Bag = require(ServerStorage.MSystems.Bag.Bag) ---@type Bag
    local ret_, ret2_ = cloudService:GetTableOrEmpty('inv' .. player.uin)
    print("读取玩家背包数据", 'inv' .. player.uin, ret_, ret2_)
    
    if ret_ then
        gg.log("读取玩家背包数据", ret2_)
        local bag = Bag.New(player)
        
        if ret2_ then
            -- 检查数据格式并进行兼容性处理
            local bagData = BagCloudDataMgr.ConvertBagDataFormat(ret2_)
            bag:Load(bagData)
            return 0, bag
        end
        
        return 0, bag
    else
        return 1, Bag.New(player) -- 数据失败，踢玩家下线，不然数据洗白了
    end
end

-- 保存玩家背包数据
---@param player MPlayer 玩家对象
---@param force_ boolean 是否强制保存，不检查时间间隔
function BagCloudDataMgr.SavePlayerBag(player, force_)
    if force_ == false then
        local now_ = os.time()
        if now_ - BagCloudDataMgr.last_time_bag < CONST_CLOUD_SAVE_TIME then
            return
        else
            BagCloudDataMgr.last_time_bag = now_
        end
    end

    if player and player.bag then
        local bagData = player.bag:Save()
        cloudService:SetTableAsync('inv' .. player.uin, bagData, function(ret_)
            if ret_ then
                gg.log("背包数据保存成功", player.uin)
            else
                gg.log("背包数据保存失败", player.uin)
            end
        end)
    end
end

-- 转换背包数据格式，兼容旧格式
---@param data table 原始背包数据
---@return table 转换后的背包数据
function BagCloudDataMgr.ConvertBagDataFormat(data)
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

-- 获取背包云存储键名
---@param uin number 玩家UIN
---@return string 云存储键名
function BagCloudDataMgr.GetBagCloudKey(uin)
    return 'inv' .. uin
end

-- 清空玩家背包数据（慎用）
---@param uin number 玩家UIN
function BagCloudDataMgr.ClearPlayerBag(uin)
    cloudService:SetTableAsync('inv' .. uin, { items = {} }, function(ret_)
        if ret_ then
            gg.log("背包数据清空成功", uin)
        else
            gg.log("背包数据清空失败", uin)
        end
    end)
end

-- 批量保存多个玩家的背包数据
---@param players table 玩家列表
function BagCloudDataMgr.BatchSavePlayerBags(players)
    for _, player in pairs(players) do
        if player and player.bag then
            BagCloudDataMgr.SavePlayerBag(player, true) -- 强制保存
        end
    end
end

return BagCloudDataMgr 