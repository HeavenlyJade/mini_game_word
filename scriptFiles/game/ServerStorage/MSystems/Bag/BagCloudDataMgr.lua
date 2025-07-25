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
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local CONST_CLOUD_SAVE_TIME = 30 -- 每30秒存盘一次

---@class BagCloudItemData
---@field name string 物品名称
---@field amount number 数量
---@field enhanceLevel number 强化等级
---@field level number 等级
---@field pos number 位置
---@field itypeIndex number 物品类型索引
---@field starLevel number 星级等级

---@class BagCloudData
---@field items table<number, BagCloudItemData[]> 按类别分的物品列表 (key是物品类型索引)

---@class BagCloudDataMgr
local BagCloudDataMgr = {
    last_time_bag = 0, -- 最后一次背包存盘时间
}

-- 读取玩家的背包数据
-- 标准格式: { items = { [1] = [{name="铁矿", ...}], [4] = [{...}] } }
---@param player MPlayer 玩家对象
---@return number, Bag 返回值: 0表示成功, 1表示失败, 背包数据
function BagCloudDataMgr.ReadPlayerBag(player)
    local Bag = require(ServerStorage.MSystems.Bag.Bag) ---@type Bag
    ---@type BagCloudData
    local ret_, ret2_ = cloudService:GetTableOrEmpty('inv' .. player.uin)
    print("读取玩家背包数据", 'inv' .. player.uin, ret_, ret2_)

    if ret_ then
        local bag = Bag.New(player)

        if ret2_ and ret2_.items then
            -- 开发阶段，不进行兼容转换，直接加载
            bag:Load(ret2_)
            gg.log("从云端加载背包数据成功", ret2_)
        else
            gg.log("云端无背包数据，已创建空背包", player.uin)
        end
        return 0, bag
    else
        gg.log("读取云端背包失败，为玩家创建新背包", player.uin)
        return 1, Bag.New(player) -- 读取失败，返回新背包
    end
end

-- 保存玩家背包数据
---@param uin number
---@param bag Bag
---@param force_ boolean 是否强制保存，不检查时间间隔
function BagCloudDataMgr.SavePlayerBag(uin, bag, force_)
    if force_ == false then
        local now_ = os.time()
        if now_ - BagCloudDataMgr.last_time_bag < CONST_CLOUD_SAVE_TIME then
            return
        else
            BagCloudDataMgr.last_time_bag = now_
        end
    end

    if uin and bag then
        -- Bag:Save() 现在只返回标准格式的数据
        local bagData = bag:Save()
        if bagData then
            cloudService:SetTableAsync('inv' .. uin, bagData, function(ret_)
                if ret_ then
                    -- gg.log("背包数据保存成功", uin)
                else
                    gg.log("背包数据保存失败", uin)
                end
            end)
        end
    end
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

return BagCloudDataMgr 