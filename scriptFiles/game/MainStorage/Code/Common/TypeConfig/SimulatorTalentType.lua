print("Hello world!")local MainStorage  = game:GetService('MainStorage')
local ClassMgr    = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr

---@class SimulatorTalentType : Class
---@field id string 天赋的唯一ID (即中文名)
---@field name string 天赋名称
---@field sortOrder number 排序
---@field type string 天赋类型, e.g., '属性', '栏位'
---@field maxLevel number 最大等级
---@field costs table 消耗物品列表
---@field effectFormula string 加成倍率公式
---@field New fun( data:table ):SimulatorTalentType
local SimulatorTalentType = ClassMgr.Class("SimulatorTalentType")

function SimulatorTalentType:OnInit(data)
    -- 从配置表中解析数据
    self.id = data["名字"] or "Unknown Talent"
    self.name = data["名字"] or "Unknown Talent"
    self.sortOrder = data["排序"] or 99
    self.type = data["类型"] or "属性"
    self.maxLevel = data["最大等级"] or 1

    -- 解析消耗物品
    self.costs = {}
    if data["消耗物品"] then
        for _, costInfo in ipairs(data["消耗物品"]) do
            table.insert(self.costs, {
                item = costInfo["物品"],
                formula = costInfo["数量公式"]
            })
        end
    end
    
    self.effectFormula = data["加成倍率公式"] or "0"
end

return SimulatorTalentType 