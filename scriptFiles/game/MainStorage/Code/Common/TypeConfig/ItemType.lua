local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
local common_config = require(MainStorage.code.common.GameConfig.MConfig) ---@type common_config
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg

-- ItemType class
---@class ItemType:Class
---@field data table<string, any> 原始配置数据
---@field name string 物品名称
---@field description string 物品描述
---@field icon string 物品图标
---@field itemCategory number 物品类型编号 (1:武器, 2:装备, 3:消耗品, 4:材料, 5:货币)
---@field itemCategoryName string 物品类型名称
---@field quality ItemRank 物品品质
---@field extraPower number 额外战力
---@field enhanceRate number 强化倍率
---@field enhanceMaterials table<string, number> 强化素材，key为素材ID，value为数量
---@field enhanceMaterialRate number 强化材料增加倍率
---@field maxEnhanceLevel number 最大强化等级
---@field attributes table<string, number> 属性，key为属性ID，value为属性值
---@field tags table<string, boolean> 标签，key为标签ID，value为是否拥有
---@field collectionReward string 图鉴完成奖励ID
---@field collectionRewardAmount number 图鉴完成奖励数量
---@field collectionAdvancedRewardAmount number 图鉴高级完成奖励数量
---@field equipmentSlot number 装备格子ID
---@field evolveTo string 可进阶为的物品ID
---@field evolveMaterials table<string, number> 进阶材料，key为材料ID，value为数量
---@field modifiers table<string, number> 获得词条，key为词条ID，value为词条值
---@field sellableTo string 可售出为的物品ID
---@field sellPrice number 售出价格
---@field New fun( data:table ):ItemType
local ItemType = ClassMgr.Class("ItemType")

function ItemType:OnInit(data)
    self.name = data["名字"] or ""
    self.description = data["描述"] or ""
    self.detail = data["详细属性"] or ""
    self.icon = data["图标"]
    
    -- 解析物品类型
    local typeString = data["物品类型"] or ""
    self.itemCategory = common_config.ItemTypeEnum[typeString] or self:_DetectItemType(data)
    self.itemCategoryName = common_config.ItemTypeNames[self.itemCategory] or "未知"
    
    self.rank = ItemRankConfig.Get(data["品级"] or "普通")
    self.extraPower = data["额外战力"] or 0
    
    -- 强化
    self.enhanceRate = data["强化倍率"] or 0
    self.enhanceMaterials = data["强化素材"] or {}
    self.enhanceMaterialRate = data["强化材料增加倍率"] or 0
    self.maxEnhanceLevel = data["最大强化等级"] or 0
    
    -- Attributes
    self.attributes = data["属性"] or {}
    
    -- 使用
    self.canAutoUse = data["可自动使用"] or true
    self.useCommands = data["使用指令"]
    self.useCooldown = data["使用冷却"] or -1
    self.useConsume = data["使用消耗"] or 1
    -- 词条ID
    self.tags = data["标签"] or {}
    
    -- Collection rewards
    self.collectionReward = data["图鉴完成奖励"]
    self.collectionRewardAmount = data["图鉴完成奖励数量"] or 0
    self.collectionAdvancedRewardAmount = data["图鉴高级完成奖励数量"] or 0
    
    -- Equipment slot
    self.equipmentSlot = data["装备格子"] or -1
    
    -- Evolution properties
    self.evolveTo = data["可进阶为"]
    self.evolveMaterials = data["进阶材料"] or {}
    
    -- 词条
    self.boundTags = data["获得词条"] or {}
    -- 售出
    self.sellableTo = data["可售出为"]
    self.sellPrice = data["售出价格"] or 0
    self.gainSound = data["获得音效"]
    -- 货币
    self.showInBag = data["在背包里显示"] or true
    self.isMoney = data["是货币"]
    self.moneyIndex = data["货币序号"] or -1
    
    -- 移除直接依赖Bag，改为注册到ItemType
    if self.isMoney then
        ItemType.RegisterMoneyType(self)
    end
end

-- 静态货币类型管理
ItemType.MoneyTypes = {} ---@type table<number, ItemType>

---注册货币类型
---@param itemType ItemType
function ItemType.RegisterMoneyType(itemType)
    ItemType.MoneyTypes[itemType.moneyIndex] = itemType
end

---获取所有货币类型
---@return table<number, ItemType>
function ItemType.GetAllMoneyTypes()
    return ItemType.MoneyTypes
end

---获取指定序号的货币类型
---@param index number
---@return ItemType|nil
function ItemType.GetMoneyType(index)
    return ItemType.MoneyTypes[index]
end

---自动检测物品类型（当配置中没有明确指定时）
---@param data table 配置数据
---@return number 物品类型编号
function ItemType:_DetectItemType(data)
    -- 检查是否为货币
    if data["是货币"] then
        return common_config.ItemTypeEnum["货币"]
    end
    
    -- 检查是否为装备/武器
    local equipSlot = data["装备格子"]
    if equipSlot and equipSlot > 0 then
        -- 可以根据装备槽位进一步区分武器和装备
        if equipSlot == 1 then -- 主卡槽位通常是武器
            return common_config.ItemTypeEnum["武器"]
        else
            return common_config.ItemTypeEnum["装备"]
        end
    end
    
    -- 检查是否为消耗品
    if data["使用指令"] and data["使用指令"] ~= "" then
        return common_config.ItemTypeEnum["消耗品"]
    end
    
    -- 默认为材料
    return common_config.ItemTypeEnum["材料"]
end

---检查是否为货币类型
---@return boolean
function ItemType:IsCurrency()
    return self.itemCategory == common_config.ItemTypeEnum["货币"]
end

---检查是否为武器类型
---@return boolean
function ItemType:IsWeapon()
    return self.itemCategory == common_config.ItemTypeEnum["武器"]
end

---检查是否为装备类型
---@return boolean
function ItemType:IsEquipment()
    return self.itemCategory == common_config.ItemTypeEnum["装备"]
end

---检查是否为消耗品类型
---@return boolean
function ItemType:IsConsumable()
    return self.itemCategory == common_config.ItemTypeEnum["消耗品"]
end

---检查是否为材料类型
---@return boolean
function ItemType:IsMaterial()
    return self.itemCategory == common_config.ItemTypeEnum["材料"]
end

---检查是否为武器或装备（可装备类型）
---@return boolean
function ItemType:IsEquippable()
    return self:IsWeapon() or self:IsEquipment()
end

---获取物品的主要类型
---@return string
function ItemType:GetMainCategory()
    if self:IsCurrency() then
        return "currency"
    elseif self:IsWeapon() then
        return "weapon"
    elseif self:IsEquipment() then
        return "equipment"
    elseif self:IsConsumable() then
        return "consumable"
    else
        return "material"
    end
end

---获取物品类型名称
---@return string
function ItemType:GetTypeName()
    return self.itemCategoryName or "未知"
end

---获取物品类型编号
---@return number
function ItemType:GetTypeNumber()
    return self.itemCategory or 0
end

---验证物品配置是否合理
---@return boolean, string
function ItemType:ValidateConfig()
    if not self.name or self.name == "" then
        return false, "物品名称不能为空"
    end
    
    if self:IsCurrency() and (not self.moneyIndex or self.moneyIndex < 0) then
        return false, "货币类型必须有有效的货币序号"
    end
    
    if self:IsEquipment() and (not self.equipmentSlot or self.equipmentSlot < 0) then
        return false, "装备类型必须有有效的装备槽位"
    end
    
    return true, "配置有效"
end

-- 工厂方法：创建特定类型的物品数据
---创建货币数据
---@param amount number 数量
---@return table
function ItemType:CreateCurrencyData(amount)
    assert(self:IsCurrency(), "只有货币类型才能创建货币数据")
    return {
        name = self.name,
        itemCategory = common_config.ItemTypeEnum["货币"], -- 5
        amount = amount or 0,
        uuid = gg.create_uuid('currency'),
        enhanceLevel = 0
    }
end

---创建武器数据
---@param enhanceLevel number 强化等级
---@return table
function ItemType:CreateWeaponData(enhanceLevel)
    assert(self:IsWeapon(), "只有武器类型才能创建武器数据")
    return {
        name = self.name,
        itemCategory = common_config.ItemTypeEnum["武器"], -- 1
        amount = 1,
        enhanceLevel = enhanceLevel or 0,
        uuid = gg.create_uuid('weapon'),
        quality = self.rank and self.rank.name or "普通"
    }
end

---创建装备数据
---@param enhanceLevel number 强化等级
---@return table
function ItemType:CreateEquipmentData(enhanceLevel)
    assert(self:IsEquipment(), "只有装备类型才能创建装备数据")
    return {
        name = self.name,
        itemCategory = common_config.ItemTypeEnum["装备"], -- 2
        amount = 1,
        enhanceLevel = enhanceLevel or 0,
        uuid = gg.create_uuid('equipment'),
        quality = self.rank and self.rank.name or "普通"
    }
end

---创建消耗品数据
---@param amount number 数量
---@return table
function ItemType:CreateConsumableData(amount)
    assert(self:IsConsumable(), "只有消耗品类型才能创建消耗品数据")
    return {
        name = self.name,
        itemCategory = common_config.ItemTypeEnum["消耗品"], -- 3
        amount = amount or 1,
        uuid = gg.create_uuid('consumable'),
        enhanceLevel = 0
    }
end

---创建材料数据
---@param amount number 数量
---@return table
function ItemType:CreateMaterialData(amount)
    assert(self:IsMaterial(), "只有材料类型才能创建材料数据")
    return {
        name = self.name,
        itemCategory = common_config.ItemTypeEnum["材料"], -- 4
        amount = amount or 1,
        uuid = gg.create_uuid('material'),
        enhanceLevel = 0
    }
end

-- 通用工厂方法
---根据类型自动创建物品数据
---@param amount number 数量
---@param enhanceLevel number 强化等级（装备/武器用）
---@return table
function ItemType:CreateItemData(amount, enhanceLevel)
    if self:IsCurrency() then
        return self:CreateCurrencyData(amount)
    elseif self:IsWeapon() then
        return self:CreateWeaponData(enhanceLevel)
    elseif self:IsEquipment() then
        return self:CreateEquipmentData(enhanceLevel)
    elseif self:IsConsumable() then
        return self:CreateConsumableData(amount)
    else
        return self:CreateMaterialData(amount)
    end
end

function ItemType:GetToStringParams()
    return {
        name = self.name
    }
end

function ItemType:ToItem(count)
    local Item = require(MainStorage.code.server.bag.Item) ---@type Item
    local item = Item.New()
    item:Load({
        uuid = gg.create_uuid('item'),
        itype = self,
        amount = count,
        el = 0,
        quality = ""
    })
    return item
end

return ItemType