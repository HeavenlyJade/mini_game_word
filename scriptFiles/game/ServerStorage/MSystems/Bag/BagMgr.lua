local game     = game
local pairs    = pairs
local ipairs   = ipairs
local type     = type
local require = require

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local BagCloudDataMgr = require(ServerStorage.MSystems.Bag.BagCloudDataMgr) ---@type BagCloudDataMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ItemUtils = require(ServerStorage.MSystems.Bag.ItemUtils) ---@type ItemUtils

-- 所有玩家的背包装备管理，服务器侧

---@class BagMgr
local BagMgr = {
    server_player_bag_data = {}, ---@type table<number, Bag>
    need_sync_bag = {} ---@type table<Bag, boolean>
}



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
        -- 玩家离线时强制保存数据

       local bagData = BagCloudDataMgr.SavePlayerBag(uin, bag, true)
       if bagData then
            BagMgr.printBagData(uin, bagData)
       end
        -- 清理内存
        BagMgr.server_player_bag_data[uin] = nil
        BagMgr.need_sync_bag[bag] = nil
    end
end

---打印玩家背包数据详情
---@param uin number 玩家ID
---@param bagData table 背包数据
function BagMgr.printBagData(uin, bagData)
    if not bagData or not bagData.items then
        gg.log("玩家", uin, "背包数据为空或格式异常")
        return
    end
    
    gg.log("========== 玩家离线背包数据 ==========")
    gg.log("玩家UIN:", uin)
    
    -- 统计各类别物品数量
    local totalItems = 0
    for category, itemList in pairs(bagData.items) do
        if itemList and #itemList > 0 then
            gg.log("类别", category, "物品数量:", #itemList)
            
            -- 打印每个物品的详细信息
            for i, itemData in ipairs(itemList) do
                if itemData then
                    local itemInfo = string.format(
                        "  [%d] %s x%d (强化:%d) 位置:c%d-s%d", 
                        i,
                        itemData.name or "未知物品",
                        itemData.amount or 0,
                        itemData.enhanceLevel or 0,
                        itemData.bagPos and itemData.bagPos.c or 0,
                        itemData.bagPos and itemData.bagPos.s or 0
                    )
                    gg.log(itemInfo)
                    totalItems = totalItems + (itemData.amount or 0)
                end
            end
        end
    end
    
    gg.log("背包物品总数:", totalItems)
    gg.log("=====================================")
end

---玩家上线处理
---@param player MPlayer 玩家对象
---@return boolean 是否成功加载背包
function BagMgr.OnPlayerJoin(player)
    local ret, bag = BagMgr.LoadPlayerBagFromCloud(player)
    if ret == 0 and bag then
        return true
    else
        return false
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
    local bag = BagMgr.GetPlayerBag(player.uin)
    if bag then
        BagCloudDataMgr.SavePlayerBag(player.uin, bag, force_)
    end
end

---批量保存所有玩家背包数据
---@param players table 玩家列表
function BagMgr.BatchSaveAllPlayerBags(players)
    for _, player in pairs(players) do
        if player then
            local bag = BagMgr.GetPlayerBag(player.uin)
            if bag then
                BagCloudDataMgr.SavePlayerBag(player.uin, bag, true) -- 强制保存
            end
        end
    end
end

---保存指定玩家的背包数据（供统一存盘机制调用）
---@param uin number 玩家ID
function BagMgr.SaveAllOnlinePlayerBags(uin)
    local bag = BagMgr.server_player_bag_data[uin]
    if bag then
        BagCloudDataMgr.SavePlayerBag(uin, bag, false)
        --gg.log("统一存盘：已保存玩家", uin, "的背包数据")
    end
end

---清空玩家背包数据（慎用）
---@param uin number 玩家UIN
function BagMgr.ClearPlayerBag(uin)
    BagCloudDataMgr.ClearPlayerBag(uin)
    BagMgr.server_player_bag_data[uin] = nil
end

---给玩家添加物品（最重要的缺失函数）
---@param player MPlayer 玩家对象
---@param itemName string 物品名称
---@param amount number 数量
---@return boolean 是否添加成功
function BagMgr.AddItem(player, itemName, amount)
    if not player or not itemName or not amount or amount <= 0 then
        --gg.log("BagMgr.AddItem: 参数无效", player and (type(player) == "table" and player.uin or tostring(player)) or "nil", itemName, amount)
        return false
    end

    local bag = BagMgr.GetOrCreatePlayerBag(player.uin, player)
    if not bag then
        --gg.log("BagMgr.AddItem: 玩家背包不存在或创建失败", player.uin)
        return false
    end

    -- 创建物品数据
    local itemData = ItemUtils.CreateItemData(itemName, amount)
    if not itemData then
        --gg.log("BagMgr.AddItem: 创建物品数据失败", itemName)
        return false
    end

    local success = bag:AddItem(itemData)
    if success then
        bag:SyncToClient()
        --gg.log("BagMgr.AddItem: 成功给玩家", player.uin, "添加物品", itemName, "x" .. amount)
    else
        --gg.log("BagMgr.AddItem: 给玩家", player.uin, "添加物品失败", itemName, "x" .. amount)
    end

    return success
end

---给玩家添加多个物品
---@param player MPlayer 玩家对象
---@param items table 物品列表，格式: {物品名: 数量, ...}
---@return table 添加结果，格式: {物品名: 是否成功, ...}
function BagMgr.AddItems(player, items)
    if not player or not items then
        return {}
    end

    local results = {}
    for itemName, amount in pairs(items) do
        results[itemName] = BagMgr.AddItem(player, itemName, amount)
    end

    return results
end

---给玩家添加物品（通过UIN）
---@param uin number 玩家UIN
---@param itemName string 物品名称
---@param amount number 数量
---@return boolean 是否添加成功
function BagMgr.AddItemByUin(uin, itemName, amount)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    if not player then
        --gg.log("BagMgr.AddItemByUin: 玩家不存在", uin)
        return false
    end

    return BagMgr.AddItem(player, itemName, amount)
end

---移除玩家物品
---@param player MPlayer 玩家对象
---@param itemName string 物品名称
---@param amount number 数量
---@return boolean 是否移除成功
function BagMgr.RemoveItem(player, itemName, amount)
    if not player or not itemName or not amount or amount <= 0 then
        return false
    end

    local bag = BagMgr.GetPlayerBag(player.uin)
    if not bag then
        return false
    end

    -- 使用 Bag.lua 中已有的 RemoveItems 方法，它接受一个table作为参数
    local success = bag:RemoveItems({ [itemName] = amount })
    if success then
        --gg.log("BagMgr.RemoveItem: 成功移除玩家", player.uin, "的物品", itemName, "x" .. amount)
    else
        --gg.log("BagMgr.RemoveItem: 移除玩家", player.uin, "的物品失败 (可能数量不足)", itemName, "x" .. amount)
    end

    return success
end

---一次性扣除消耗列表中的所有物品（对外接口）
---@param player MPlayer 玩家对象
---@param costs table 消耗列表，格式为{ {item=物品名, amount=数量}, ... }
---@return boolean 是否全部扣除成功
function BagMgr.RemoveItemsByCosts(player, costs)
    if not player or not costs then
        return false
    end
    local bag = BagMgr.GetPlayerBag(player.uin)
    if not bag then
        return false
    end
    return bag:RemoveItemsByCosts(costs)
end

---检查玩家是否拥有足够的物品
---@param player MPlayer 玩家对象
---@param itemName string 物品名称
---@param amount number 需要的数量
---@return boolean 是否拥有足够的物品
function BagMgr.HasItem(player, itemName, amount)
    if not player or not itemName or not amount then
        return false
    end

    local bag = BagMgr.GetPlayerBag(player.uin)
    if not bag then
        return false
    end

    return bag:GetItemAmount(itemName) >= amount
end

---检查玩家是否拥有多个物品
---@param player MPlayer 玩家对象
---@param items table 物品列表，格式: {物品名: 数量, ...}
---@return boolean 是否拥有所有物品
function BagMgr.HasItems(player, items)
    if not player or not items then
        return false
    end

    local bag = BagMgr.GetPlayerBag(player.uin)
    if not bag then
        return false
    end

    return bag:HasItems(items)
end

---获取玩家物品数量
---@param player MPlayer 玩家对象
---@param itemName string 物品名称
---@return number 物品数量
function BagMgr.GetItemAmount(player, itemName)
    if not player or not itemName then
        return 0
    end

    local bag = BagMgr.GetPlayerBag(player.uin)
    if not bag then
        return 0
    end

    return bag:GetItemAmount(itemName)
end

---检查玩家背包是否有足够空间
---@param player MPlayer 玩家对象
---@param items table 要添加的物品列表
---@return boolean 是否有足够空间
function BagMgr.HasEnoughSpace(player, items)
    if not player or not items then
        return true
    end

    local bag = BagMgr.GetPlayerBag(player.uin)
    if not bag then
        return false
    end

    return bag:HasEnoughSpace(items)
end

---强制同步玩家背包到客户端
---@param uin number 玩家UIN
function BagMgr.ForceSyncToClient(uin)
    local bag = BagMgr.GetPlayerBag(uin)
    if bag then
        bag:MarkDirty(true)  -- 标记为全量同步
        bag:SyncToClient()
    end
end

---检测消耗列表中的所有物品是否足够（对外接口）
---@param player MPlayer 玩家对象
---@param costs table 消耗列表，格式为{ {item=物品名, amount=数量}, ... }
---@return boolean 是否全部足够
function BagMgr.HasItemsByCosts(player, costs)
    if not player or not costs then
        return false
    end
    local bag = BagMgr.GetPlayerBag(player.uin)
    if not bag then
        return false
    end
    local costMap = bag.CostsToMap(costs)
    return bag:HasItems(costMap)
end

--- 设置玩家物品数量
---@param uin number 玩家UIN
---@param itemName string 物品名称
---@param amount number 目标数量
---@return boolean 是否成功
function BagMgr.SetItemAmount(uin, itemName, amount)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    if not player then
        --gg.log("BagMgr.SetItemAmount: 玩家不存在", uin)
        return false
    end

    local bag = BagMgr.GetOrCreatePlayerBag(uin, player)
    if not bag then
        --gg.log("BagMgr.SetItemAmount: 玩家背包不存在或创建失败", uin)
        return false
    end

    local currentAmount = bag:GetItemAmount(itemName)
    local diff = amount - currentAmount

    if diff > 0 then
        -- 需要增加物品
        local itemData = ItemUtils.CreateItemData(itemName, diff)
        if not itemData then
            --gg.log("BagMgr.SetItemAmount: 创建物品数据失败", itemName)
            return false
        end
        return bag:AddItem(itemData)
    elseif diff < 0 then
        -- 需要减少物品
        return bag:RemoveItems({ [itemName] = -diff })
    else
        -- 数量不变
        return true
    end
end

return BagMgr

