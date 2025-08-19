--- 依赖规则检查器
--- 用于检查和处理变量之间的依赖关系

local MainStorage = game:GetService("MainStorage")
local VariableNameConfig = require(MainStorage.Code.Common.Config.VariableNameConfig) ---@type VariableNameConfig

---@class DependencyRuleChecker
local DependencyRuleChecker = {}

--- 检查并处理变量依赖规则
---@param player table 玩家对象
---@param sourceVar string 源变量名
---@param newValue number 新值
function DependencyRuleChecker.CheckAndProcess(player, sourceVar, newValue)
    local rule = VariableNameConfig.DependencyRules[sourceVar]
    if not rule then return end
    
    local variableSystem = player.variableSystem
    if not variableSystem then return end
    
    local targetVar = rule['目标变量']
    local condition = rule['条件']
    local action = rule['动作']
    
    if not targetVar then return end
    
    local targetValue = variableSystem:GetVariable(targetVar) or 0
    local shouldUpdate = false
    
    -- 检查条件
    if condition == '大于' and newValue > targetValue then
        shouldUpdate = true
    elseif condition == '小于' and newValue < targetValue then
        shouldUpdate = true
    elseif condition == '变化时' then
        shouldUpdate = true
    elseif condition == '大于等于' and newValue >= targetValue then
        shouldUpdate = true
    elseif condition == '小于等于' and newValue <= targetValue then
        shouldUpdate = true
    end
    
    -- 执行动作
    if shouldUpdate then
        local newTargetValue = targetValue
        
        if action == '设置为源值' then
            newTargetValue = newValue
        elseif action == '设置为固定值' then
            newTargetValue = rule['固定值'] or 0
        elseif action == '设置为倍数值' then
            newTargetValue = newValue * (rule['倍率'] or 1)
        end
        
        variableSystem:SetVariable(targetVar, newTargetValue)
        
        -- 记录日志
        if player.gg and player.gg.log then
            player.gg.log(string.format("依赖规则触发: %s(%s) -> %s(%s)", 
                sourceVar, tostring(newValue), targetVar, tostring(newTargetValue)))
        end
    end
end

return DependencyRuleChecker
