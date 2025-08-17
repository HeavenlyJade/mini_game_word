---@class AttributeMapping 玩家属性变量映射配置
---@field variableToStat table<string, string> 变量名到属性名的映射
local AttributeMapping = {
    -- 变量名到属性名的映射
    -- 格式: ["变量名"] = "属性名"
    variableToStat = {
        -- 基础属性
        ["加成_百分比_攻击力加成"] = "攻击",
        ["加成_固定值_攻击力加成"] = "攻击",
        ["加成_百分比_防御力加成"] = "防御", 
        ["加成_固定值_防御力加成"] = "防御",
        ["加成_百分比_生命值加成"] = "生命",
        ["加成_固定值_生命值加成"] = "生命",
        ["加成_百分比_魔法值加成"] = "魔法",
        ["加成_固定值_魔法值加成"] = "魔法",
        ["加成_百分比_速度加成"] = "速度",
        ["加成_固定值_速度加成"] = "速度",
        
        -- 战斗属性
        ["加成_百分比_暴击率加成"] = "暴击率",
        ["加成_固定值_暴击率加成"] = "暴击率",
        ["加成_百分比_暴击伤害加成"] = "暴击伤害",
        ["加成_固定值_暴击伤害加成"] = "暴击伤害",
        ["加成_百分比_闪避率加成"] = "闪避率",
        ["加成_固定值_闪避率加成"] = "闪避率",
        
        -- 特殊属性
        ["加成_百分比_经验倍率加成"] = "经验倍率",
        ["加成_固定值_经验倍率加成"] = "经验倍率",
        ["加成_百分比_金币倍率加成"] = "金币倍率",
        ["加成_固定值_金币倍率加成"] = "金币倍率",
    },
}

-- ============================= 工具方法 =============================

--- 检查变量名是否映射到属性
---@param variableName string 变量名
---@return boolean
function AttributeMapping.IsAttributeVariable(variableName)
    return AttributeMapping.variableToStat[variableName] ~= nil
end

--- 获取变量对应的属性名
---@param variableName string 变量名
---@return string|nil 属性名
function AttributeMapping.GetCorrespondingStat(variableName)
    return AttributeMapping.variableToStat[variableName]
end

--- 获取所有属性变量名列表
---@return string[]
function AttributeMapping.GetAllAttributeVariables()
    local result = {}
    for variableName in pairs(AttributeMapping.variableToStat) do
        table.insert(result, variableName)
    end
    return result
end

return AttributeMapping
