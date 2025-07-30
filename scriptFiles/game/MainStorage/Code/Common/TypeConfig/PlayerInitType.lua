-- PlayerInitType.lua

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr

---@class PlayerInitType:Class
---@field name string 配置名称
---@field description string 描述
---@field currencyInits table 货币初始化列表
---@field variableInits table 变量初始化列表
---@field otherSettings table 其他设置
---@field New fun(data:table):PlayerInitType
local PlayerInitType = ClassMgr.Class("PlayerInitType")

function PlayerInitType:OnInit(data)
    self.name = data["配置名称"] or "未知配置"
    self.description = data["描述"] or ""
    self.currencyInits = data["货币初始化"] or {}
    self.variableInits = data["变量初始化"] or {}
    self.otherSettings = data["其他设置"] or {}
end

--- 获取货币初始化配置
---@return table<string, number> 货币名称到数量的映射
function PlayerInitType:GetCurrencyInitMap()
    local result = {}
    for _, currencyConfig in ipairs(self.currencyInits) do
        local name = currencyConfig["货币名称"]
        local amount = currencyConfig["初始数量"] or 0
        if name then
            result[name] = amount
        end
    end
    return result
end

--- 获取变量初始化配置  
---@return table<string, number> 变量名称到值的映射
function PlayerInitType:GetVariableInitMap()
    local result = {}
    for _, variableConfig in ipairs(self.variableInits) do
        local name = variableConfig["变量名称"]
        local value = variableConfig["初始值"] or 0
        if name then
            result[name] = value
        end
    end
    return result
end

--- 检查是否为新手玩家配置
---@return boolean
function PlayerInitType:IsNewPlayerConfig()
    return self.otherSettings["是否新手"] == true
end

--- 获取初始等级
---@return number
function PlayerInitType:GetInitialLevel()
    return self.otherSettings["初始等级"] or 1
end

return PlayerInitType 