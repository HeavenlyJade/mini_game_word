local game     = game
local pairs    = pairs
local ipairs   = ipairs
local type     = type
local require = require

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local BagCloudDataMgr = require(ServerStorage.MSystems.Bag.BagCloudDataMgr) ---@type BagCloudDataMgr

-- 所有玩家的背包装备管理，服务器侧

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

-- ---分解所有低质量装备
-- ---@param uin_ number 玩家ID
-- ---@param args1_ table 参数
-- function BagMgr.HandleDpAllLowEq( uin_, args1_ )
--     local player_data_ = BagMgr.GetPlayerBag( uin_ )
--     player_data_:DecomposeAllLowQualityItems(ItemRankConfig.Get(args1_.rank))
-- end

---获得指定uin玩家的背包数据
---@param uin_ number 玩家ID
---@return Bag 玩家背包数据
function BagMgr.GetPlayerBag( uin_ )
    return  BagMgr.server_player_bag_data[ uin_ ]
end

---获取或创建玩家背包（如果不存在则创建新的）
---@param uin number 玩家ID
---@param player MPlayer|nil 玩家对象
---@return Bag 玩家背包数据
function BagMgr.GetOrCreatePlayerBag(uin, player)
    local bag = BagMgr.server_player_bag_data[uin]
    if not bag and player then
        local Bag = require(ServerStorage.MSystems.Bag.Bag)
        bag = Bag.New(player)
        BagMgr.server_player_bag_data[uin] = bag
    end
    return bag
end

---玩家离线处理
---@param uin number 玩家ID
function BagMgr.OnPlayerLeave(uin)
    local bag = BagMgr.server_player_bag_data[uin]
    if bag then
        -- 保存背包数据
        if bag.dirtySave then
            bag:Save()
        end
        -- 清理内存
        BagMgr.server_player_bag_data[uin] = nil
        BagMgr.need_sync_bag[bag] = nil
    end
end

---玩家上线处理
---@param player MPlayer 玩家对象
---@return boolean 是否成功加载背包
function BagMgr.OnPlayerJoin(player)
    local ret, bag = BagMgr.LoadPlayerBagFromCloud(player)
    if ret == 0 and bag then
        player.bag = bag
        return true
    else
        -- 创建新背包
        local Bag = require(ServerStorage.MSystems.Bag.Bag)
        local newBag = Bag.New(player)
        BagMgr.setPlayerBagData(player.uin, newBag)
        player.bag = newBag
        return true
    end
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
