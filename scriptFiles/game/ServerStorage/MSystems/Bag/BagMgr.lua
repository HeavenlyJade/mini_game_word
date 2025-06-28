local game     = game
local pairs    = pairs
local ipairs   = ipairs
local type     = type
local require = require

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg              = require(MainStorage.code.common.MGlobal)   ---@type gg
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
-- local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local BagCloudDataMgr = require(ServerStorage.MSystems.Bag.BagCloudDataMgr) ---@type BagCloudDataMgr

-- 所有玩家的背包装备管理，服务器侧

---@class Bag : Class
---@field player MPlayer 玩家实例
---@field uin number 玩家ID
---@field bag_index table<string, BagPosition[]> 物品名称索引 (物品名称 -> 位置数组)
---@field bag_items BagItems 背包物品 (分类 -> 物品数据数组)
---@field loaded boolean 是否已加载
---@field dirtySyncSlots table 需要同步的槽位列表
---@field dirtySave boolean 是否需要保存
---@field dirtySyncAll boolean 是否需要全量同步
---@field New fun( player: MPlayer):Bag
local Bag = ClassMgr.Class("Bag") ---@type Bag

---@class BagMgr
local BagMgr = {
    server_player_bag_data = {}, ---@type table<number, Bag>
    need_sync_bag = {} ---@type table<Bag, boolean>
}

function SyncAll()
    for bag, _ in pairs(BagMgr.need_sync_bag) do
        bag:SyncToClient()
    end
    BagMgr.need_sync_bag = {}
end

-- 使用Timer替代ServerScheduler
local timer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
timer.Name = 'BAG_SYNC_ALL'
timer.Delay = 0.1
timer.Loop = true      -- 是否循环
timer.Interval = 2     -- 循环间隔多少秒 (0.2秒 = 2帧, 1秒=10帧)
timer.Callback = SyncAll
timer:Start()

-- ---刷新玩家的背包数据（服务器 to 客户端）
-- ---@param uin_ number 玩家ID
-- ---@param param table 参数
-- function BagMgr.s2c_PlayerBagItems( uin_, param )
--     local player_data_ = BagMgr.GetPlayerBag( uin_ )
--     BagMgr.returnBagInfoByVer( uin_, player_data_ )
-- end

---使用物品
---@param uin_ number 玩家ID
---@param param table 参数
function BagMgr.handleBtnUseItem( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:UseItem(param.slot)
end

---分解装备
---@param uin_ number 玩家ID
---@param param table 参数
function BagMgr.handleBtnDecompose( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:DecomposeItem(param.slot)
end

---玩家交换背包数据
---@param uin_ number 玩家ID
---@param param table 参数
function BagMgr.handlePlayerItemsChange( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:SwapItem(param.pos1, param.pos2)
end

---打开所有宝箱
---@param uin_ number 玩家ID
function BagMgr.handleUseAllBox( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:UseAllBoxes()
end

---分解所有低质量装备
---@param uin_ number 玩家ID
---@param args1_ table 参数
function BagMgr.HandleDpAllLowEq( uin_, args1_ )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:DecomposeAllLowQualityItems(ItemRankConfig.Get(args1_.rank))
end

---获得指定uin玩家的背包数据
---@param uin_ number 玩家ID
---@return Bag 玩家背包数据
function BagMgr.GetPlayerBag( uin_ )
    return  BagMgr.server_player_bag_data[ uin_ ]
end

---云读取数据后，设置给玩家
---@param uin_ number 玩家ID
---@param bag Bag 背包数据
function BagMgr.setPlayerBagData( uin_, bag )
    BagMgr.server_player_bag_data[ uin_ ] = bag
end

---从云端读取玩家背包数据
---@param player MPlayer 玩家对象
---@return number, Bag 返回值: 0表示成功, 1表示失败, 背包数据
function BagMgr.LoadPlayerBagFromCloud(player)
    local ret, bag = BagCloudDataMgr.ReadPlayerBag(player)
    if ret == 0 then
        BagMgr.setPlayerBagData(player.uin, bag)
    end
    return ret, bag
end

---保存玩家背包数据到云端
---@param player MPlayer 玩家对象
---@param force_ boolean 是否强制保存
function BagMgr.SavePlayerBagToCloud(player, force_)
    BagCloudDataMgr.SavePlayerBag(player, force_)
end

---批量保存所有玩家背包数据
---@param players table 玩家列表
function BagMgr.BatchSaveAllPlayerBags(players)
    BagCloudDataMgr.BatchSavePlayerBags(players)
end

---清空玩家背包数据（慎用）
---@param uin number 玩家UIN
function BagMgr.ClearPlayerBag(uin)
    BagCloudDataMgr.ClearPlayerBag(uin)
    BagMgr.server_player_bag_data[uin] = nil
end

return BagMgr
