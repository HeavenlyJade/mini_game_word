-- TeleportPointType.lua
-- 传送点类型配置类，用于解析和管理传送点配置

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr

---@class TeleportPointType : Class
---@field name string 传送点名称
---@field nodePath string 传送节点路径
---@field requiredLevel number 需求等级
---@field iconPath string 图片资源路径
---@field description string 传送点描述
---@field unlocked boolean 是否解锁
---@field cost number 传送消耗
---@field weight number 权重
---@field New fun(data:table):TeleportPointType
local TeleportPointType = ClassMgr.Class('TeleportPointType')

function TeleportPointType:OnInit(data)
    self.name = data['传送点名称'] or ''
    self.nodePath = data['传送节点'] or ''
    self.requiredLevel = data['需求等级'] or 0
    self.iconPath = data['图片资源路径'] or ''
    self.description = data['传送点描述'] or ''
    self.unlocked = data['是否解锁'] == true
    self.cost = data['传送消耗'] or 0
	self.weight = data['权重'] or 1
end

--- 是否解锁
---@return boolean
function TeleportPointType:IsUnlocked()
    return self.unlocked == true
end

--- 玩家是否可传送（基于等级与解锁状态）
---@param playerLevel number
---@return boolean, string
function TeleportPointType:CanTeleport(playerLevel)
    if not self:IsUnlocked() then
        return false, '传送点未解锁'
    end
    if (playerLevel or 0) < (self.requiredLevel or 0) then
        return false, string.format('等级不足，需要达到%d级', self.requiredLevel or 0)
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

--- 获取需求等级
---@return number
function TeleportPointType:GetRequiredLevel()
    return self.requiredLevel or 0
end

--- 获取传送消耗
---@return number
function TeleportPointType:GetCost()
    return self.cost or 0
end

return TeleportPointType


