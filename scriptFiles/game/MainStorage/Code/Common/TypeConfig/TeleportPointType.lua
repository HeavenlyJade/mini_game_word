-- TeleportPointType.lua
-- 传送点类型配置类，用于解析和管理传送点配置

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ActionCosteRewardCal = require(MainStorage.Code.GameReward.RewardCalc.ActionCosteRewardCal) ---@type ActionCosteRewardCal
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class TeleportPointType : Class
---@field name string 传送点名称
---@field nodePath string 传送节点路径
---@field sceneNode string 场景节点
---@field requiredCondition number 需求条件
---@field iconPath string 图片资源路径
---@field description string 传送点描述
---@field unlocked boolean 是否解锁
---@field cost number 传送消耗
---@field weight number 权重
---@field variableFormula string 变量表达公式
---@field New fun(data:table):TeleportPointType
local TeleportPointType = ClassMgr.Class('TeleportPointType')

function TeleportPointType:OnInit(data)
    self.name = data['传送点名称'] or ''
    self.nodePath = data['传送节点'] or ''
    self.sceneNode = data['场景节点'] or ''
    
    -- 处理需求条件，使用MGlobal封装的科学计数法转换函数
    self.requiredCondition = gg.convertScientificNotation(data['需求条件'])
    
    self.iconPath = data['图片资源路径'] or ''
    self.description = data['传送点描述'] or ''
    self.unlocked = data['是否解锁'] == true
    self.cost = data['传送消耗'] or 0
	self.weight = data['权重'] or 1
	self.variableFormula = data['变量表达公式'] or ''
end

--- 是否解锁
---@return boolean
function TeleportPointType:IsUnlocked()
    return self.unlocked == true
end

--- 玩家是否可传送（基于需求条件与解锁状态）
---@param playerLevel number
---@return boolean, string
function TeleportPointType:CanTeleport(playerLevel)
    if not self:IsUnlocked() then
        return false, '传送点未解锁'
    end
    if (playerLevel or 0) < (self.requiredCondition or 0) then
        return false, string.format('条件不足，需要达到%d', self.requiredCondition or 0)
    end
    return true, '可以传送'
end

--- 获取显示名称
---@return string
function TeleportPointType:GetDisplayName()
    return self.name or ''
end

--- 获取传送节点路径
---@return string
function TeleportPointType:GetNodePath()
    return self.nodePath or ''
end

--- 获取图标路径
---@return string
function TeleportPointType:GetIconPath()
    return self.iconPath or ''
end

--- 获取权重
---@return number
function TeleportPointType:GetWeight()
	return self.weight or 1
end

--- 获取需求条件
---@return number
function TeleportPointType:GetRequiredCondition()
    return self.requiredCondition or 0
end

--- 获取传送消耗
---@return number
function TeleportPointType:GetCost()
    return self.cost or 0
end

--- 获取变量表达公式
---@return string
function TeleportPointType:GetVariableFormula()
    return self.variableFormula or ''
end

--- 获取场景节点
---@return string
function TeleportPointType:GetSceneNode()
    return self.sceneNode or ''
end

--- 检查变量表达公式是否满足条件
---@param playerData table 玩家数据
---@param bagData table|nil 背包数据（可选）
---@param externalContext table|nil 外部上下文（可选）
---@return boolean, string
function TeleportPointType:CheckVariableCondition(playerData, bagData, externalContext)
    if not self.variableFormula or self.variableFormula == '' then
        return true, '无变量条件限制'
    end
    
    -- 直接复用ActionCosteRewardCal的条件检查逻辑
    local result = ActionCosteRewardCal:_CalculateValue(self.variableFormula, playerData, bagData, externalContext)
    
    if result == true then
        return true, '变量条件满足'
    else
        return false, '变量条件不满足'
    end
end

return TeleportPointType


