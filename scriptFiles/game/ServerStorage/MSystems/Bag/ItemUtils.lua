local MainStorage = game:GetService('MainStorage')
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local ItemQualityConfig = require(MainStorage.Code.Common.Config.ItemQualityConfig) ---@type ItemQualityConfig
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class ItemUtils 物品工具类
local ItemUtils = {}

-- 缓存ItemType以提高性能
local itemTypeCache = {} ---@type table<string, ItemType>

---获取物品类型配置（带缓存）
---@param itemData ItemData|string 物品数据或物品名称
---@return ItemType|nil 物品类型配置
function ItemUtils.GetItemType(itemData)
    local itemTypeName = nil
    
    if type(itemData) == "string" then
        itemTypeName = itemData
    elseif itemData and itemData.name then
        itemTypeName = itemData.name
    elseif itemData and itemData.itemType then
        itemTypeName = itemData.itemType
    elseif itemData and itemData.itype then
        itemTypeName = itemData.itype
    end
    
    if not itemTypeName then
        return nil
    end
    
    -- 检查缓存
    if itemTypeCache[itemTypeName] then
        return itemTypeCache[itemTypeName]
    end
    
    -- 从配置获取并缓存
    local itemType = ConfigLoader.GetItem(itemTypeName)
    if itemType then
        itemTypeCache[itemTypeName] = itemType
    end
    
    return itemType
end

---清理ItemType缓存
function ItemUtils.ClearCache()
    itemTypeCache = {}
end

---检查物品数据是否有效
---@param itemData ItemData 物品数据
---@return boolean, string 是否有效，错误信息
function ItemUtils.ValidateItemData(itemData)
    if not itemData then
        return false, "物品数据为空"
    end
    
    if not itemData.name or itemData.name == "" then
        return false, "物品名称不能为空"
    end
    
    local itemType = ItemUtils.GetItemType(itemData)
    if not itemType then
        return false, "找不到物品配置: " .. tostring(itemData.name)
    end
    
    if itemData.amount and itemData.amount < 0 then
        return false, "物品数量不能为负数"
    end
    
    if itemData.enhanceLevel and itemData.enhanceLevel < 0 then
        return false, "强化等级不能为负数"
    end
    
    return true, "有效"
end

---检查是否为装备
---@param itemData ItemData 物品数据
---@return boolean
function ItemUtils.IsEquipment(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType:IsEquipment()
end

---检查是否为武器
---@param itemData ItemData 物品数据
---@return boolean
function ItemUtils.IsWeapon(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType:IsWeapon()
end

---检查是否为消耗品
---@param itemData ItemData 物品数据
---@return boolean
function ItemUtils.IsConsumable(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType:IsConsumable()
end

---检查是否为货币
---@param itemData ItemData 物品数据
---@return boolean
function ItemUtils.IsMoney(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType:IsCurrency()
end

---检查是否为材料
---@param itemData ItemData 物品数据
---@return boolean
function ItemUtils.IsMaterial(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType:IsMaterial()
end

---检查是否可堆叠
---@param itemData ItemData 物品数据
---@return boolean
function ItemUtils.IsStackable(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType:IsStackable()
end

---检查是否可使用
---@param itemData ItemData 物品数据
---@return boolean
function ItemUtils.IsUsable(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType:IsUsable()
end

---检查是否可强化
---@param itemData ItemData 物品数据
---@return boolean
function ItemUtils.IsEnhanceable(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType:IsEnhanceable()
end

---检查两个物品是否可以合并
---@param itemData1 ItemData 物品1
---@param itemData2 ItemData 物品2
---@return boolean
function ItemUtils.CanMerge(itemData1, itemData2)
    if not itemData1 or not itemData2 then
        return false
    end
    
    -- 名称必须相同
    if itemData1.name ~= itemData2.name then
        return false
    end
    
    -- 必须都是可堆叠物品
    if not ItemUtils.IsStackable(itemData1) or not ItemUtils.IsStackable(itemData2) then
        return false
    end
    
    -- 强化等级必须相同（对于可强化物品）
    if ItemUtils.IsEnhanceable(itemData1) then
        if (itemData1.enhanceLevel or 0) ~= (itemData2.enhanceLevel or 0) then
            return false
        end
    end
    
    -- 品质必须相同（对于有品质的物品）
    if itemData1.quality ~= itemData2.quality then
        return false
    end
    
    return true
end

---获取物品的计算属性
---@param itemData ItemData 物品数据
---@return table<string, number> 物品属性
function ItemUtils.GetStat(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    if not itemType then
        return {}
    end

    return itemType:CalculateEnhancedAttributes(itemData.enhanceLevel or 0)
end

---获取物品战力
---@param itemData ItemData 物品数据
---@return number 物品战力
function ItemUtils.GetPower(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    if not itemType then
        return 0
    end

    local quality = nil
    if itemData.quality then
        quality = ItemQualityConfig[itemData.quality]
    end
    
    return itemType:CalculatePower(itemData.enhanceLevel or 0, quality)
end

---获取物品显示内容
---@param itemData ItemData 物品数据
---@return string 物品显示内容
function ItemUtils.PrintContent(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    local content = {
        (itemType and itemType.name or "未知") .. "(" .. (itemData.amount or 1) .. ")"
    }

    if ItemUtils.IsEquipment(itemData) or ItemUtils.IsWeapon(itemData) then
        if itemData.quality then
            table.insert(content, "品质: " .. itemData.quality)
        end
        if itemData.enhanceLevel and itemData.enhanceLevel > 0 then
            table.insert(content, "强化: +" .. itemData.enhanceLevel)
        end
        
        -- 显示战力
        local power = ItemUtils.GetPower(itemData)
        if power > 0 then
            table.insert(content, "战力: " .. power)
        end
    end

    return table.concat(content, ", ")
end

---使用物品
---@param player MPlayer 玩家
---@param itemData ItemData 物品数据
---@return boolean, string 是否成功，消息
function ItemUtils.UseItem(player, itemData)
    local isValid, errorMsg = ItemUtils.ValidateItemData(itemData)
    if not isValid then
        return false, errorMsg
    end
    
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType:ExecuteUse(player, itemData)
end

---强化物品
---@param itemData ItemData 物品数据
---@param targetLevel number 目标等级
---@return boolean, string, table|nil 是否成功，消息，所需材料
function ItemUtils.EnhanceItem(itemData, targetLevel)
    local isValid, errorMsg = ItemUtils.ValidateItemData(itemData)
    if not isValid then
        return false, errorMsg, nil
    end
    
    local itemType = ItemUtils.GetItemType(itemData)
    local currentLevel = itemData.enhanceLevel or 0
    
    local canEnhance, message = itemType:CanEnhanceTo(currentLevel, targetLevel)
    if not canEnhance then
        return false, message, nil
    end
    
    local materials = itemType:GetEnhanceMaterials(currentLevel, targetLevel)
    return true, "可以强化", materials
end

---创建标准化的物品数据
---@param itemTypeName string 物品类型名称
---@param amount number 数量
---@param enhanceLevel number|nil 强化等级
---@param quality string|nil 品质
---@return ItemData|nil, string 创建的物品数据，错误信息
function ItemUtils.CreateItemData(itemTypeName, amount, enhanceLevel, quality)
    local itemType = ItemUtils.GetItemType(itemTypeName) ---@type ItemType|nil
    if not itemType then
        return nil, "找不到物品配置: " .. tostring(itemTypeName)
    end

    local itemData = itemType:CreateCompleteItemData(amount, enhanceLevel, quality)
    
    -- 验证创建的数据
    local isValid, errorMsg = ItemUtils.ValidateItemData(itemData)
    if not isValid then
        return nil, errorMsg
    end
    
    return itemData, "创建成功"
end

---批量创建物品数据
---@param itemList table<string, number> 物品列表 {物品名称 = 数量}
---@return table<string, ItemData>, table<string, string> 成功创建的物品数据，失败的物品及错误信息
function ItemUtils.CreateItemDataBatch(itemList)
    local successItems = {}
    local failedItems = {}
    
    for itemName, amount in pairs(itemList) do
        local itemData, errorMsg = ItemUtils.CreateItemData(itemName, amount)
        if itemData then
            successItems[itemName] = itemData
        else
            failedItems[itemName] = errorMsg
        end
    end
    
    return successItems, failedItems
end

---复制物品数据
---@param itemData ItemData 源物品数据
---@param newAmount number|nil 新数量（如果不指定则使用原数量）
---@return ItemData 复制的物品数据
function ItemUtils.CloneItemData(itemData, newAmount)
    local clonedData = {}
    for k, v in pairs(itemData) do
        clonedData[k] = v
    end
    
    -- 生成新的UUID
    clonedData.uuid = gg.create_uuid(ItemUtils.GetItemType(itemData):GetMainCategory())
    
    -- 设置新数量
    if newAmount then
        clonedData.amount = newAmount
    end
    
    return clonedData
end

---比较两个物品的价值（用于排序）
---@param itemData1 ItemData 物品1
---@param itemData2 ItemData 物品2
---@return number -1, 0, 1 表示物品1小于、等于、大于物品2
function ItemUtils.CompareItemValue(itemData1, itemData2)
    local power1 = ItemUtils.GetPower(itemData1)
    local power2 = ItemUtils.GetPower(itemData2)
    
    if power1 < power2 then
        return -1
    elseif power1 > power2 then
        return 1
    else
        return 0
    end
end

---获取物品的排序权重（用于背包排序）
---@param itemData ItemData 物品数据
---@return number 排序权重
function ItemUtils.GetSortWeight(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    if not itemType then
        return 999999
    end
    
    local weight = 0
    
    -- 按类型排序：货币 < 装备/武器 < 消耗品 < 材料
    if itemType:IsCurrency() then
        weight = 1000
    elseif itemType:IsWeapon() then
        weight = 2000
    elseif itemType:IsEquipment() then
        weight = 3000
    elseif itemType:IsConsumable() then
        weight = 4000
    else -- 材料
        weight = 5000
    end
    
    -- 按品质排序
    if itemData.quality then
        local qualityConfig = ItemQualityConfig[itemData.quality]
        if qualityConfig then
            weight = weight - (qualityConfig.level or 0) * 100
        end
    end
    
    -- 按强化等级排序
    weight = weight - (itemData.enhanceLevel or 0) * 10
    
    -- 按战力排序
    weight = weight - ItemUtils.GetPower(itemData)
    
    return weight
end

return ItemUtils 