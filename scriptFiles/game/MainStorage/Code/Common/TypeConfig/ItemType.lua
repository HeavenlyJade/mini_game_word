local MainStorage  = game:GetService('MainStorage')
local ClassMgr    = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
-- local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
local gg                = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

-- ItemType class
---@class ItemType:Class
---@field name string 物品名称
---@field description string 物品描述
---@field detail string 详细描述
---@field icon string 物品图标
---@field quality string 物品品质
---@field power number 战力
---@field enhanceRate number 强化倍率
---@field enhanceMaterials table<string, number> 强化素材
---@field enhanceMaterialRate number 强化材料增加倍率
---@field maxEnhanceLevel number 最大强化等级
---@field attributes table<string, number> 属性
---@field tags table<string, boolean> 标签
---@field collectionReward string 图鉴完成奖励ID
---@field collectionRewardAmount number 图鉴完成奖励数量
---@field collectionAdvancedRewardAmount number 图鉴高级完成奖励数量
---@field equipmentSlot number 装备格子ID
---@field evolveTo string 可进阶为的物品ID
---@field evolveMaterials table<string, number> 进阶材料
---@field boundTags table 获得词条
---@field sellPrice number 售出价格
---@field showInBag boolean 是否在背包里显示
---@field isStackable boolean 是否可堆叠
---@field maxStack number 最大堆叠数量
---@field gainSound string 获得音效
---@field cancelGain boolean 是否取消获得
---@field gainCommands table 获得时执行的指令
---@field useCommands table 使用时执行的指令
---@field decomposeResult table 分解产物
---@field New fun( data:table ):ItemType
local ItemType = ClassMgr.Class("ItemType")

function ItemType:OnInit(data)
    -- 基本信息
    self.name = data["名字"] or "Unknown Item"
    self.description = data["描述"] or ""
    self.detail = data["详细属性"] or ""
    self.icon = data["图标"] or ""
    self.quality = data["品级"] or "普通"
    self.power = data["战力"] or 0

    -- 强化
    self.enhanceRate = data["强化倍率"] or 0
    self.enhanceMaterials = data["强化素材"] or {}
    self.enhanceMaterialRate = data["强化材料增加倍率"] or 0
    self.maxEnhanceLevel = data["最大强化等级"] or 0
    
    -- 属性
    self.attributes = data["属性"] or {}
    self.tags = data["标签"] or {}
    
    -- 使用与获得
    self.canAutoUse = data["可自动使用"] or true
    self.useCommands = data["使用执行指令"] or {}
    self.useCooldown = data["使用冷却"] or -1
    self.useConsume = data["使用消耗"] or 1
    self.gainCommands = data["获得执行指令"] or {}
    self.gainSound = data["获得音效"] or ""
    self.cancelGain = data["取消获得物品"] or false

    -- 收集
    self.collectionReward = data["图鉴完成奖励"]
    self.collectionRewardAmount = data["图鉴完成奖励数量"] or 0
    self.collectionAdvancedRewardAmount = data["图鉴高级完成奖励数量"] or 0
    
    -- 装备
    self.equipmentSlot = data["装备格子"] or -1
    
    -- 进阶
    self.evolveTo = data["可进阶为"]
    self.evolveMaterials = data["进阶材料"] or {}
    
    -- 其他
    self.boundTags = data["获得词条"] or {}
    self.decomposeResult = data["分解可得"] or {}
    self.sellableTo = data["可售出为"]
    self.sellPrice = data["售出价格"] or 0
    
    -- 显示与货币
    self.showInBag = data["在背包里显示"] or true
    self.itemTypeStr = data["物品类型"]
    self.isMoney = (self.itemTypeStr == "货币")
    self.isStackable = data["是否可堆叠"] or false
    self.maxStack = data["最大数量"] or 1
end

function ItemType:GetToStringParams()
    return {
        name = self.name
    }
end

---创建完整的物品数据
---@param amount number 数量
---@param enhanceLevel number|nil 强化等级
---@param quality string|nil 品质
---@return ItemData 物品数据
function ItemType:CreateCompleteItemData(amount, enhanceLevel, quality)
    return {
        name = self.name,
        amount = amount or 1,
        enhanceLevel = enhanceLevel or 0,
        quality = quality,
        itemType = self.name,
        itype = self.name,
        isStackable = self.isStackable, -- 是否可堆叠
    }
end

-- function ItemType:ToItem(count)
--     local Item = require(MainStorage.code.server.bag.Item) ---@type Item
--     local item = Item.New()
--     item:Load({
--         uuid = gg.create_uuid('item'),
--         itype = self,
--         amount = count,
--         el = 0,
--         quality = ""
--     })
--     return item
-- end

return ItemType