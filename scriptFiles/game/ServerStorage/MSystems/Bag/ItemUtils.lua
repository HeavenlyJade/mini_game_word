local MainStorage = game:GetService('MainStorage')
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
local ItemQualityConfig = require(MainStorage.code.common.config.ItemQualityConfig) ---@type ItemQualityConfig

---@class ItemUtils 物品工具类
local ItemUtils = {}

---@param itemData ItemData 物品数据
---@return ItemType|nil 物品类型配置
function ItemUtils.GetItemType(itemData)
    if not itemData or not itemData.itemType then
        return nil
    end
    
    if type(itemData.itemType) == "string" then
        return ItemTypeConfig.Get(itemData.itemType)
    else
        return itemData.itemType
    end
end

---@param itemData ItemData 物品数据
---@return boolean 是否为装备
function ItemUtils.IsEquipment(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType.equipmentSlot and itemType.equipmentSlot > 0
end

---@param itemData ItemData 物品数据
---@return boolean 是否为消耗品
function ItemUtils.IsConsumable(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType.useCommands ~= nil
end

---@param itemData ItemData 物品数据
---@return boolean 是否为货币
function ItemUtils.IsMoney(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    return itemType and itemType.isMoney == true
end

---@param itemData ItemData 物品数据
---@return table<string, number> 物品属性
function ItemUtils.GetStat(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    if not itemType then
        return {}
    end

    local baseAttributes = itemType.attributes or {}
    local enhanceRate = itemType.enhanceRate or 0
    local stats = {}

    -- 计算基础属性
    for attrId, value in pairs(baseAttributes) do
        stats[attrId] = value
    end

    -- 计算强化加成
    local enhanceLevel = itemData.enhanceLevel or 0
    if enhanceLevel > 0 and enhanceRate > 0 then
        local enhanceMultiplier = 1 + (enhanceLevel * enhanceRate)
        for attrId, value in pairs(baseAttributes) do
            stats[attrId] = value * enhanceMultiplier
        end
    end

    -- 计算品质加成
    if itemData.quality then
        local qualityConfig = ItemQualityConfig.Get(itemData.quality)
        if qualityConfig and qualityConfig.multiplier then
            for attrId, value in pairs(baseAttributes) do
                stats[attrId] = value * qualityConfig.multiplier
            end
        end
    end

    return stats
end

---@param itemData ItemData 物品数据
---@return number 物品战力
function ItemUtils.GetPower(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    if not itemType then
        return 0
    end

    local stats = ItemUtils.GetStat(itemData)
    local power = itemType.extraPower or 0

    -- 计算属性带来的战力
    for _, value in pairs(stats) do
        power = power + value
    end

    return power
end

---@param itemData ItemData 物品数据
---@return string 物品显示内容
function ItemUtils.PrintContent(itemData)
    local itemType = ItemUtils.GetItemType(itemData)
    local content = {
        (itemType and itemType.name or "未知") .. "(" .. (itemData.amount or 1) .. ")"
    }

    if ItemUtils.IsEquipment(itemData) then
        if itemData.quality then
            table.insert(content, "品质: " .. itemData.quality)
        end
        if itemData.enhanceLevel and itemData.enhanceLevel > 0 then
            table.insert(content, "强化: " .. itemData.enhanceLevel)
        end
    end

    return table.concat(content, ", ")
end

---@param itemTypeName string 物品类型名称
---@param amount number 数量
---@param enhanceLevel number|nil 强化等级
---@param quality string|nil 品质
---@return ItemData 创建的物品数据
function ItemUtils.CreateItemData(itemTypeName, amount, enhanceLevel, quality)
    local itemType = ItemTypeConfig.Get(itemTypeName)
    if not itemType then
        error("找不到物品配置: " .. itemTypeName)
    end

    local itemData = {
        itemType = itemTypeName,
        name = itemType.name,
        amount = amount or 1,
        enhanceLevel = enhanceLevel or 0,
        uuid = tostring(math.random(100000, 999999)) .. "_" .. tostring(os.time()),
        quality = quality,
        level = 1,
        pos = 0,
        itype = itemTypeName
    }

    -- 如果是装备且没有指定品质，随机一个品质
    if ItemUtils.IsEquipment(itemData) and not quality then
        local randomQuality = ItemQualityConfig:GetRandomQuality()
        if randomQuality then
            itemData.quality = randomQuality.name
        end
    end

    return itemData
end

return ItemUtils 