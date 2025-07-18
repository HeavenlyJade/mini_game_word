---@class CEvent
---@field __class Class 事件类型

---@class MoneyAmount
---@field it string
---@field a number

---@class SyncInventoryItems
---@field items table<Slot, SerializedItem> 背包物品
---@field deletedSlots table<number, {c:number, s:number}> 被删除的槽位列表
