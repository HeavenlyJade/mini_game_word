local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ItemType = require(MainStorage.Code.Common.TypeConfig.ItemType) ---@type ItemType
local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig
local ItemUtils = require(ServerStorage.MSystems.Bag.ItemUtils) ---@type ItemUtils
local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local common_config = require(MainStorage.Code.Common.GameConfig.MConfig) ---@type common_config

---@class Bag:Class
---@field uin number 玩家UIN
---@field bag_items table<number, ItemData[]> 存放所有物品, 按物品类型的数字分类索引
---@field bag_index table<string, BagPosition[]> 按物品名称索引, 方便快速查找
---@field loaded boolean 是否已从云端加载
---@field dirtySyncSlots BagPosition[] 需要同步到客户端的槽位
---@field dirtySave boolean 数据是否需要保存到云端
---@field dirtySyncAll boolean 是否需要全量同步到客户端
---@field New fun(player: MPlayer): Bag
local Bag = ClassMgr.Class("Bag")

---@param player MPlayer 玩家实例
function Bag:OnInit(player)
    self.uin = player.uin
    self.bag_index = {}
    self.bag_items = {}

    self.loaded = false
    self.dirtySyncSlots = {}
    self.dirtySave = false
    self.dirtySyncAll = false
    
    -- 初始化所有货币类型为0（如果背包中没有的话）
    self:InitializeCurrencies()
end

---获取玩家实例
---@return MPlayer|nil 玩家实例
function Bag:GetPlayer()
    return MServerDataManager.getPlayerByUin(self.uin)
end

---将物品类型编号转换为分类编号
---@param itemCategoryNumber number 物品类型编号
---@return number 分类编号
function Bag:GetCategoryFromItemCategory(itemCategoryNumber)
    local common_config = require(MainStorage.Code.Common.GameConfig.MConfig) ---@type common_config
    
    -- 验证传入的编号是否有效
    if itemCategoryNumber and common_config.ItemTypeNames[itemCategoryNumber] then
        return itemCategoryNumber
    else
        return 0
    end
end

---初始化货币类型
function Bag:InitializeCurrencies()
    
    -- 获取所有物品类型
    local allItemTypes = ConfigLoader.GetAllItems()
    
    -- 筛选出货币类型的物品
    local currencyTypes = {}
    for itemName, itemType in pairs(allItemTypes) do
        if itemType.isMoney and itemType.moneyIndex > 0 then
            table.insert(currencyTypes, {
                name = itemType.name,
                index = itemType.moneyIndex,
                itemType = itemType
            })
        end
    end
    
    -- 按货币序号排序
    table.sort(currencyTypes, function(a, b)
        return a.index < b.index
    end)
    
    -- 初始化每种货币
    for _, currencyInfo in ipairs(currencyTypes) do
        -- 检查背包中是否已有该货币
        if self:GetItemAmount(currencyInfo.name) == 0 then
            -- 如果没有，添加初始货币（数量为0）
            local currencyData = {
                name = currencyInfo.name,
                itemCategory = common_config.ItemTypeEnum["货币"], -- 货币类型编号
                amount = 0,
                enhanceLevel = 0,
                itemType = currencyInfo.name,
                itype = currencyInfo.name
            }
            self:AddItem(currencyData)
            gg.log("初始化货币:", currencyInfo.name, "序号:", currencyInfo.index)
        end
    end
end

---@param data table 背包数据
function Bag:Load(data)
    gg.log("Bag:Load", data)
    if not data or not data.items then
        return
    end

    -- 清空现有数据
    self.bag_index = {}
    self.bag_items = {}

    -- 加载物品数据并重建索引
    for category, itemList in pairs(data.items) do
        gg.log("Bag:Load category:", category, "itemList:", itemList)
        
        if itemList and type(itemList) == "table" then
            self.bag_items[category] = {}
            
            for i, itemData in ipairs(itemList) do
                if itemData and type(itemData) == "table" then
                    -- 确保物品数据包含itemCategory字段
                    itemData.itemCategory = category

                    -- 使用云端保存的bagPos，如果没有则重建
                    if not itemData.bagPos then
                        itemData.bagPos = {c = category, s = i}
                    end
                    
                    -- 添加到背包
                    table.insert(self.bag_items[category], itemData)
                    
                    -- 添加到名称索引
                    local itemName = itemData.name
                    if itemName then
                        if not self.bag_index[itemName] then
                            self.bag_index[itemName] = {}
                        end
                        table.insert(self.bag_index[itemName], itemData.bagPos)
                    end
                end
            end
        end
    end

    gg.log("Bag:Load完成，bag_items:", self.bag_items)
    gg.log("Bag:Load完成，bag_index:", self.bag_index)
    self:MarkDirty(true)
end

function Bag:Save()
    -- 清理数据，保留槽位信息，移除itemType和itype字段
    local cleanItems = {}
    for category, itemList in pairs(self.bag_items) do
        if itemList and #itemList > 0 then
            cleanItems[category] = {}
            for _, itemData in ipairs(itemList) do
                if itemData then
                    -- 创建清理后的物品数据副本
                    local cleanItem = {}
                    local allowed = { bagPos = true, name = true, amount = true, enhanceLevel = true }
                    for k, v in pairs(itemData) do
                        if allowed[k] then
                            cleanItem[k] = v
                        end
                    end
                    table.insert(cleanItems[category], cleanItem)
                end
            end
        end
    end

    local data = {
        items = cleanItems
    }

    gg.log("准备背包数据用于保存:", data)
    return data
end

---@param position BagPosition 背包位置
---@return ItemData|nil 物品数据
function Bag:GetItemByPosition(position)
    local itemList = self.bag_items[position.c]
    if not itemList or not itemList[position.s] then
        return nil
    end
    return itemList[position.s]
end

---@param itemName string 物品名称
---@return ItemData[] 物品列表
function Bag:GetItemByName(itemName)
    local items = {}
    local positions = self.bag_index[itemName] or {}
    for _, position in ipairs(positions) do
        local item = self:GetItemByPosition(position)
        if item then
            table.insert(items, item)
        end
    end
    return items
end

---@param itemData ItemData 物品数据
---@return boolean 是否添加成功
function Bag:AddItem(itemData)
    gg.log("Bag:AddItem 开始 - itemData:", itemData)
    if not itemData or not itemData.name then
        gg.log("物品数据无效")
        return false
    end

    -- 获取物品配置，验证物品是否存在
    local itemType = ItemUtils.GetItemType(itemData)
    if not itemType then
        gg.log("找不到物品配置:", itemData.name)
        return false
    end
    
    -- 确保物品有正确的类型分类
    if not itemData.itemCategory then
        itemData.itemCategory = self:GetCategoryFromItemType(itemType)
    end

    -- 检查是否可堆叠（货币或配置允许堆叠）
    local canStack = itemType.isMoney or (itemType.isStackable and (itemType.maxStack or 1) > 1)
    
    if canStack then
        -- 查找现有同名同类型物品进行合并
        local existingItems = self:GetItemByName(itemData.name)
        for _, existingItem in ipairs(existingItems) do
            -- 检查是否可以合并（同类型、同强化等级）
            if existingItem.itemCategory == itemData.itemCategory and 
               (existingItem.enhanceLevel or 0) == (itemData.enhanceLevel or 0) then
                
                local addAmount = itemData.amount or 1
                local currentAmount = existingItem.amount or 1
                
                -- 对于货币类型，无堆叠限制
                if itemType.isMoney then
                    existingItem.amount = currentAmount + addAmount
                    self:MarkDirty(existingItem.bagPos)
                    gg.log("货币堆叠成功:", itemData.name, "新数量:", existingItem.amount)
                    return true
                -- 对于其他可堆叠物品，检查堆叠上限
                elseif itemType.maxStack then
                    local maxStack = itemType.maxStack
                    if currentAmount + addAmount <= maxStack then
                        existingItem.amount = currentAmount + addAmount
                        self:MarkDirty(existingItem.bagPos)
                        gg.log("物品堆叠成功:", itemData.name, "新数量:", existingItem.amount)
                        return true
                    else
                        -- 部分合并，剩余数量需要新建槽位
                        local canAdd = maxStack - currentAmount
                        if canAdd > 0 then
                            existingItem.amount = maxStack
                            itemData.amount = addAmount - canAdd
                            self:MarkDirty(existingItem.bagPos)
                            gg.log("物品部分堆叠:", itemData.name, "剩余数量:", itemData.amount)
                            -- 继续处理剩余数量
                        end
                    end
                end
            end
        end
    end
    
    -- 无法合并或不可堆叠，创建新槽位
    local category = itemData.itemCategory
    if not self.bag_items[category] then
        self.bag_items[category] = {}
    end
    
    -- 添加到背包
    table.insert(self.bag_items[category], itemData)
    local position = {c = category, s = #self.bag_items[category]}
    itemData.bagPos = position
    
    -- 更新索引
    if not self.bag_index[itemData.name] then
        self.bag_index[itemData.name] = {}
    end
    table.insert(self.bag_index[itemData.name], position)
    
    self:MarkDirty(position)
    gg.log("物品添加到新槽位:", itemData.name, "位置:", position.c, position.s)
    return true
end

---@param position BagPosition 背包位置
---@param newItemData ItemData 新物品数据
---@return boolean 是否设置成功
function Bag:SetItem(position, newItemData)
    gg.log("Bag:SetItem 开始 - position:", position, "newItemData:", newItemData)
    
    -- 检查位置有效性
    if not position or not position.c or not position.s then
        gg.log("背包位置无效")
        return false
    end
    
    -- 获取当前位置的物品
    local currentItem = self:GetItemByPosition(position)
    
    -- 如果新物品数据为空，则移除当前物品
    if not newItemData then
        if currentItem then
            self:RemoveItem(position)
            gg.log("移除位置物品:", position.c, position.s)
        end
        return true
    end
    
    -- 验证新物品数据
    if not newItemData.name then
        gg.log("新物品数据无效：缺少物品名称")
        return false
    end
    
    -- 获取新物品的配置
    local itemType = ItemUtils.GetItemType(newItemData)
    if not itemType then
        gg.log("找不到物品配置:", newItemData.name)
        return false
    end
    
    -- 确保新物品有正确的类型分类
    if not newItemData.itemCategory then
        newItemData.itemCategory = self:GetCategoryFromItemType(itemType)
    end
    
    -- 检查位置分类是否匹配
    if newItemData.itemCategory ~= position.c then
        gg.log("物品类型与位置分类不匹配:", newItemData.itemCategory, "vs", position.c)
        return false
    end
    
    -- 如果当前位置有物品，先从索引中移除
    if currentItem then
        local oldName = currentItem.name
        if self.bag_index[oldName] then
            for i, pos in ipairs(self.bag_index[oldName]) do
                if pos.c == position.c and pos.s == position.s then
                    table.remove(self.bag_index[oldName], i)
                    break
                end
            end
            if #self.bag_index[oldName] == 0 then
                self.bag_index[oldName] = nil
            end
        end
    end
    
    -- 设置新物品数据
    newItemData.bagPos = position
    
    -- 确保背包分类存在
    if not self.bag_items[position.c] then
        self.bag_items[position.c] = {}
    end
    
    -- 如果当前位置不存在，扩展数组
    while #self.bag_items[position.c] < position.s do
        table.insert(self.bag_items[position.c], nil)
    end
    
    -- 设置物品到指定位置
    self.bag_items[position.c][position.s] = newItemData
    
    -- 更新索引
    if not self.bag_index[newItemData.name] then
        self.bag_index[newItemData.name] = {}
    end
    table.insert(self.bag_index[newItemData.name], position)
    
    self:MarkDirty(position)
    gg.log("物品设置成功:", newItemData.name, "位置:", position.c, position.s)
    return true
end

---根据物品类型获取分类编号
---@param itemType ItemType 物品类型配置
---@return number 分类编号
function Bag:GetCategoryFromItemType(itemType)
    if not itemType then
        return 0
    end
    
    -- 根据物品类型配置确定分类
    if itemType.isMoney then
        return common_config.ItemTypeEnum["货币"] or 5
    elseif itemType.category then
        return common_config.ItemTypeEnum[itemType.category] or 0
    else
        -- 默认分类逻辑，可根据实际需求调整
        return 4 -- 材料类
    end
end

---@param position BagPosition 背包位置
---@param amount number 新数量
function Bag:SetItemAmount(position, amount)
    if amount <= 0 then
        self:RemoveItem(position)
        return
    end
    local item = self:GetItemByPosition(position)
    if not item then
        return
    end
    item.amount = amount
    self:MarkDirty()
end

---@param position BagPosition 背包位置
function Bag:RemoveItem(position)
    local item = self:GetItemByPosition(position)
    if not item then
        return
    end

    -- 从索引中移除
    local itemName = item.name
    if self.bag_index[itemName] then
        for i, pos in ipairs(self.bag_index[itemName]) do
            if pos.c == position.c and pos.s == position.s then
                table.remove(self.bag_index[itemName], i)
                break
            end
        end
        if #self.bag_index[itemName] == 0 then
            self.bag_index[itemName] = nil
        end
    end

    -- 从背包中移除
    local itemList = self.bag_items[position.c]
    if itemList then
        table.remove(itemList, position.s)
        -- 更新后续物品的位置索引
        for i = position.s, #itemList do
            local currentItem = itemList[i]
            if currentItem and currentItem.bagPos then
                currentItem.bagPos.s = i
                -- 更新索引中的位置
                if self.bag_index[currentItem.name] then
                    for _, pos in ipairs(self.bag_index[currentItem.name]) do
                        if pos.c == position.c and pos.s == i + 1 then
                            pos.s = i
                            break
                        end
                    end
                end
            end
        end
    end

    self:MarkDirty()
end

function Bag:MarkDirty(slot)
    self.dirtySave = true
    if slot then
        if type(slot) == "boolean" then
            self.dirtySyncAll = true
        else
            table.insert(self.dirtySyncSlots, slot)
        end
    end
    BagMgr.need_sync_bag[self] = true
end

function Bag:SyncToClient()

    if #self.dirtySyncSlots == 0 and not self.dirtySyncAll then
        return
    end

    local moneys = {}
    local allItemTypes = ConfigLoader.GetAllItems()
    
    -- 获取所有货币类型并按序号排序
    local currencyTypes = {}
    for itemName, itemType in pairs(allItemTypes) do
        if itemType.isMoney and itemType.moneyIndex > 0 then
            table.insert(currencyTypes, {
                name = itemType.name,
                index = itemType.moneyIndex,
                itemType = itemType
            })
        end
    end
    
    table.sort(currencyTypes, function(a, b)
        return a.index < b.index
    end)
    
    -- 构建货币数据
    for idx, currencyInfo in ipairs(currencyTypes) do
        moneys[idx] = {
            it = currencyInfo.name,
            a = self:GetItemAmount(currencyInfo.name)
        }
    end
    
    local syncItems = {}
    if self.dirtySyncAll then
        syncItems = self.bag_items
    else
        for _, position in ipairs(self.dirtySyncSlots) do
            local item = self:GetItemByPosition(position)
            if item then
                if not syncItems[position.c] then
                    syncItems[position.c] = {}
                end
                syncItems[position.c][position.s] = item
            end
        end
    end
    
    self.dirtySyncAll = false
    self.dirtySyncSlots = {}

    local ret = {
        cmd = BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS,
        items = syncItems,
        moneys = moneys
    }
    gg.log("Bag:SyncToClient 开始 - ret:", ret)
    gg.network_channel:fireClient(self.uin, ret)
end

---@param itemName string 物品名称
---@return number 物品总数量
function Bag:GetItemAmount(itemName)
    local total = 0
    local items = self:GetItemByName(itemName)
    for _, item in ipairs(items) do
        total = total + (item.amount or 1)
    end
    return total
end

---@param items table<string, number> 物品名称和数量的映射表
---@return boolean 是否拥有所有物品
function Bag:HasItems(items)
    if not items then
        return false
    end

    for itemName, requiredAmount in pairs(items) do
        if self:GetItemAmount(itemName) < requiredAmount then
            return false
        end
    end

    return true
end

---检查背包是否有足够的空间容纳物品列表
---@param attachments table 附件列表，格式: {"物品名": 数量}
---@return boolean 是否有足够空间
function Bag:HasEnoughSpace(attachments)
    if not attachments then
        return true -- 没有物品需要添加，空间足够
    end
    
    -- 计算需要的物品类型和数量
    local itemNeeds = {} -- {itemName: totalAmount}
    for itemName, amount in pairs(attachments) do
        if itemName and amount and amount > 0 then
            itemNeeds[itemName] = (itemNeeds[itemName] or 0) + amount
        end
    end
    
    -- 检查每种物品是否可以添加
    for itemName, totalNeeded in pairs(itemNeeds) do
        -- 获取物品配置
        local itemType = ConfigLoader.GetItem(itemName)
        
        if not itemType then
            gg.log("警告：未找到物品配置", itemName)
            return false -- 如果找不到物品配置，认为无法添加
        end
        
        -- 如果是可堆叠的物品（如货币），检查是否可以与现有物品合并
        if itemType.isMoney or (itemType.maxStack and itemType.maxStack > 1) then
            -- 可堆叠物品，检查现有堆叠是否可以容纳
            local existingItems = self:GetItemByName(itemName)
            local totalExistingAmount = 0
            local availableStackSpace = 0
            
            for _, existingItem in ipairs(existingItems) do
                totalExistingAmount = totalExistingAmount + (existingItem.amount or 1)
                if itemType.maxStack then
                    availableStackSpace = availableStackSpace + (itemType.maxStack - (existingItem.amount or 1))
                end
            end
            
            -- 对于货币类型，通常没有堆叠限制
            if itemType.isMoney then
                -- 货币可以无限堆叠，空间足够
                -- 跳过此物品的检查
            elseif availableStackSpace >= totalNeeded then
                -- 现有堆叠空间足够
                -- 跳过此物品的检查
            else
                -- 需要新的堆叠槽位
                local remainingNeeded = totalNeeded - availableStackSpace
                local newStacksNeeded = math.ceil(remainingNeeded / itemType.maxStack)
                
                -- 这里简化处理：假设背包有足够的空间
                -- 在实际游戏中，你可能需要检查背包的具体容量限制
                gg.log("物品", itemName, "需要新的堆叠槽位:", newStacksNeeded)
            end
        else
            -- 不可堆叠物品，每个都需要一个新槽位
            -- 这里简化处理：假设背包有足够的空间
            gg.log("不可堆叠物品", itemName, "需要槽位:", totalNeeded)
        end
    end
    
    -- 简化版本：总是返回 true
    -- 在实际游戏中，你可能需要实现更复杂的背包容量检查逻辑
    return true
end

---@param items table<string, number> 物品名称和数量的映射表
---@return boolean 是否成功移除所有物品
function Bag:RemoveItems(items)
    if not items then
        return false
    end

    -- 先检查是否拥有所有物品
    if not self:HasItems(items) then
        return false
    end

    -- 移除物品
    for itemName, count in pairs(items) do
        local remaining = count
        local positions = self.bag_index[itemName] or {}
        for _, position in ipairs(positions) do
            if remaining <= 0 then
                break
            end
            local item = self:GetItemByPosition(position)
            if item then
                local amount = item.amount or 1
                if amount > remaining then
                    self:SetItemAmount(position, amount - remaining)
                    remaining = 0
                else
                    self:RemoveItem(position)
                    remaining = remaining - amount
                end
            end
        end
    end
    return true
end

function Bag:PrintContent()
    local lines = {}
    local first = true
    for category, itemList in pairs(self.bag_items) do
        if itemList and #itemList > 0 then
            if not first then
                table.insert(lines, "==============")
            end
            first = false
            table.insert(lines, string.format("Category: %s", category))
            for i, item in ipairs(itemList) do
                table.insert(lines, string.format("[%s:%d] %s x%d", category, i, item.name, item.amount or 1))
            end
        end
    end
    print(table.concat(lines, "\n"))
end

---@param itemName string 物品名称
---@return table|nil 物品的背包数据，如果不存在返回nil
function Bag:GetItemDataByName(itemName)
    local items = self:GetItemByName(itemName)
    if #items > 0 then
        local item = items[1]
        return {
            category = item.bagPos.c,
            slot = item.bagPos.s,
            amount = item.amount or 1,
            enhanceLevel = item.enhanceLevel or 0,
            uuid = item.uuid,
            itemType = item.itemType,
            position = item.bagPos
        }
    end
    return nil
end

---@param position BagPosition 背包位置
function Bag:UseItem(position)
    local itemData = self:GetItemByPosition(position)
    local player = self:GetPlayer()
    if not player then
        return
    end
    
    if not itemData then
        player:SendHoverText("该位置没有物品")
        return
    end

    if ItemUtils.IsConsumable(itemData) then
        -- 执行消耗品命令
        local itemType = ItemUtils.GetItemType(itemData)
        if itemType and itemType.useCommands then
            player:ExecuteCommand(itemType.useCommands, nil)
            -- 减少数量
            self:SetItemAmount(position, itemData.amount - 1)
        end
    elseif ItemUtils.IsEquipment(itemData) then
        -- 装备物品（简化版本，可以扩展）
        player:SendHoverText("装备功能需要进一步实现")
    else
        player:SendHoverText("该物品无法使用")
    end
end

---@param position BagPosition 背包位置
function Bag:DecomposeItem(position)
    local itemData = self:GetItemByPosition(position)
    local player = self:GetPlayer()
    if not player then
        return
    end
    
    if not itemData then
        player:SendHoverText('该位置没有物品')
        return
    end
    
    local itemType = ItemUtils.GetItemType(itemData)
    if not itemType then
        player:SendHoverText('物品配置错误')
        return
    end
    
    -- 计算分解获得的材料类型和数量
    local materialType = itemType.sellableTo
    local matAmount = itemData.amount * (itemType.sellPrice or 1)
    if not materialType or matAmount <= 0 then
        player:SendHoverText('%s 无法被分解', itemType.name)
        return
    end
    
    -- 创建材料物品
    local materialData = ItemUtils.CreateItemData(materialType.name, matAmount)
    self:AddItem(materialData)
    self:RemoveItem(position)
    player:SendHoverText("分解成功，获得 %s x %s", materialType.name, matAmount)
end

---@param pos1 BagPosition 位置1
---@param pos2 BagPosition 位置2
function Bag:SwapItem(pos1, pos2)
    local item1 = self:GetItemByPosition(pos1)
    local item2 = self:GetItemByPosition(pos2)
    
    if item1 == nil and item2 == nil then
        return
    end

    -- 简化版本：直接交换
    -- 在实际游戏中，这里需要验证装备限制等
    if item1 and item2 then
        -- 交换两个物品
        local itemList1 = self.bag_items[pos1.c]
        local itemList2 = self.bag_items[pos2.c]
        if itemList1 and itemList2 then
            itemList1[pos1.s], itemList2[pos2.s] = item2, item1
            -- 更新背包位置
            item1.bagPos = pos2
            item2.bagPos = pos1
        end
    elseif item1 then
        -- 移动物品到空位置
        self:RemoveItem(pos1)
        item1.bagPos = pos2
        if not self.bag_items[pos2.c] then
            self.bag_items[pos2.c] = {}
        end
        self.bag_items[pos2.c][pos2.s] = item1
    elseif item2 then
        -- 移动物品到空位置
        self:RemoveItem(pos2)
        item2.bagPos = pos1
        if not self.bag_items[pos1.c] then
            self.bag_items[pos1.c] = {}
        end
        self.bag_items[pos1.c][pos1.s] = item2
    end
    
    self:MarkDirty()
end

---@return number 打开的宝箱数量
function Bag:UseAllBoxes()
    local player = self:GetPlayer()
    if not player then
        return 0
    end
    
    local count = 0
    for itemName, positions in pairs(self.bag_index) do
        for _, position in ipairs(positions) do
            local itemData = self:GetItemByPosition(position)
            if itemData then
                local itemType = ItemUtils.GetItemType(itemData)
                if itemType and itemType.useCommands and itemType.canAutoUse then
                    for i = 1, itemData.amount do
                        player:ExecuteCommand(itemType.useCommands, nil)
                        count = count + 1
                    end
                    self:RemoveItem(position)
                end
            end
        end
    end
    
    if count == 0 then
        player:SendHoverText('你的背包里没有可用物品')
    end
    return count
end

---@param rank ItemRank 目标品质等级
---@return number 分解的装备数量
function Bag:DecomposeAllLowQualityItems(rank)
    if not rank then
        return 0
    end
    
    local decomposedCount = 0
    local materialMap = {} -- {materialType: totalAmount}
    local toRemove = {}
    
    -- 统计所有可分解装备
    for category, itemList in pairs(self.bag_items) do
        for i, itemData in ipairs(itemList) do
            if itemData and ItemUtils.IsEquipment(itemData) then
                local itemType = ItemUtils.GetItemType(itemData)
                if itemType and itemType.quality and itemType.quality.priority < rank.priority and itemType.sellableTo then
                    local materialType = itemType.sellableTo
                    local matAmount = itemData.amount * (itemType.sellPrice or 1)
                    if matAmount > 0 then
                        materialMap[materialType] = (materialMap[materialType] or 0) + matAmount
                        table.insert(toRemove, {c = category, s = i})
                        decomposedCount = decomposedCount + 1
                    end
                end
            end
        end
    end
    
    -- 合并材料到背包
    for materialType, totalAmount in pairs(materialMap) do
        local materialData = ItemUtils.CreateItemData(materialType.name, totalAmount)
        self:AddItem(materialData)
    end
    
    -- 移除原装备
    for _, position in ipairs(toRemove) do
        self:RemoveItem(position)
    end
    
    local player = self:GetPlayer()
    if not player then
        return decomposedCount
    end
    
    if decomposedCount > 0 then
        -- 构造获得材料提示
        local tips = {}
        for materialType, totalAmount in pairs(materialMap) do
            table.insert(tips, string.format("%s x %d", materialType.name, totalAmount))
        end
        player:SendHoverText(string.format("分解了%d件装备，获得材料：%s", decomposedCount, table.concat(tips, ", ")))
    else
        player:SendHoverText("没有发现可被分解的物品")
    end
    return decomposedCount
end

---@param itemData ItemData 物品数据
---@return boolean 是否成功
function Bag:GiveItem(itemData)
    ---玩家从系统处获得物品走此函数
    local success = self:AddItem(itemData)
    if success then
        local player = self:GetPlayer()
        if player then
            if not ItemUtils.IsMoney(itemData) then
                player:SendEvent("GainedItem", {
                    item = itemData
                })
            end
            local itemType = ItemUtils.GetItemType(itemData)
            if itemType and itemType.gainSound then
                player:PlaySound(itemType.gainSound)
            end
        end
    end
    return success
end

return Bag

