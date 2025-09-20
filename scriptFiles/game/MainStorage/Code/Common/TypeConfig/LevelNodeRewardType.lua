-- LevelNodeRewardType.lua
-- 负责将 LevelNodeRewardConfig.lua 中的原始关卡节点奖励数据，封装成程序中使用的LevelNodeReward对象。

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)

---@class LevelNodeRewardItem
---@field 奖励类型 string 奖励的类型（如：物品、经验等）
---@field 物品类型 string 物品的具体类型（如：金币、道具等）
---@field 物品数量 number 奖励物品的数量
---@field 奖励条件 string 获得奖励的条件描述
---@field 生成的距离配置 number 触发奖励的距离阈值
---@field 唯一ID string 奖励节点的唯一标识符

---@class BonusVariableItem
---@field 变量名称 string 加成变量的名称
---@field 变量属性 string 变量属性（如：玩家变量、全局变量等）
---@field 作用目标 string 作用目标（如：金币、经验等）
---@field 加成方式 string 加成方式（如：最终乘法、固定加成等）
---@field 加成数值 number 加成数值

---@class LevelNodeRewardConfigItem
---@field 配置名称 string 配置的名称标识
---@field 配置描述 string 配置的详细描述
---@field 克隆的场景节点路径 string 要克隆的场景节点路径
---@field 所属场景 string 配置所属的场景名称
---@field 节点列表 LevelNodeRewardItem[] 奖励节点列表

---@class LevelNodeRewardType : Class
---@field id string 配置的唯一ID (来自配置的Key)
---@field name string 配置名称
---@field description string 配置描述
---@field sceneNodePath string 克隆的场景节点路径
---@field sceneName string 所属场景名称
---@field soundNodeField string 音效节点字段
---@field rewardNodes LevelNodeRewardItem[] 奖励节点列表
---@field bonusVariables table[] 加成变量列表
---@field _distanceMap table<number, LevelNodeRewardItem[]> 按距离分组的奖励节点映射
---@field _idMap table<string, LevelNodeRewardItem> 按唯一ID分组的奖励节点映射
---@field _bonusVariableMap table<string, table> 按变量名称分组的加成变量映射
local LevelNodeRewardType = ClassMgr.Class("LevelNodeRewardType")

function LevelNodeRewardType:OnInit(data)
    -- 基础信息
    self.id = data["配置名称"] or ""
    self.name = data["配置名称"] or ""
    self.description = data["配置描述"] or ""
    self.sceneNodePath = data["克隆的场景节点路径"] or ""
    self.sceneName = data["所属场景"] or ""
    self.soundNodeField = data["音效节点字段"] or ""
    
    -- 奖励节点列表
    self.rewardNodes = data["节点列表"] or {}
    
    -- 加成变量列表
    self.bonusVariables = data["加成变量列表"] or {}
    
    -- 构建距离映射表，用于快速查找特定距离的奖励
    self._distanceMap = {}
    for _, node in ipairs(self.rewardNodes) do
        local distance = node["生成的距离配置"] or 0
        if distance > 0 then
            if not self._distanceMap[distance] then
                self._distanceMap[distance] = {}
            end
            table.insert(self._distanceMap[distance], node)
        end
    end
    
    -- 【新增】构建唯一ID映射表，用于快速查找特定ID的节点
    self._idMap = {}
    for _, node in ipairs(self.rewardNodes) do
        local uniqueId = node["唯一ID"]
        if uniqueId and uniqueId ~= "" then
            self._idMap[uniqueId] = node
        end
    end
    
    -- 【新增】构建加成变量映射表，用于快速查找特定变量名称的加成配置
    self._bonusVariableMap = {}
    for _, bonusVar in ipairs(self.bonusVariables) do
        local varName = bonusVar["变量名称"]
        if varName and varName ~= "" then
            self._bonusVariableMap[varName] = bonusVar
        end
    end
    
    -- 调试信息
    local gg = require(game:GetService("MainStorage").Code.Untils.MGlobal)
    --gg.log(string.format("LevelNodeRewardType 初始化完成 - 配置: %s, 奖励节点数: %d, 唯一ID映射数: %d", self.name, #self.rewardNodes, self:GetUniqueIdCount()))
end

--- 获取配置名称
---@return string
function LevelNodeRewardType:GetName()
    return self.name
end

--- 获取配置描述
---@return string
function LevelNodeRewardType:GetDescription()
    return self.description
end

--- 获取场景节点路径
---@return string
function LevelNodeRewardType:GetSceneNodePath()
    return self.sceneNodePath
end

--- 获取所属场景名称
---@return string
function LevelNodeRewardType:GetSceneName()
    return self.sceneName
end

--- 获取所有奖励节点
---@return LevelNodeRewardItem[]
function LevelNodeRewardType:GetAllRewardNodes()
    return self.rewardNodes
end

--- 获取奖励节点数量
---@return number
function LevelNodeRewardType:GetRewardNodeCount()
    return #self.rewardNodes
end

--- 根据距离获取奖励节点
---@param distance number 距离值
---@return LevelNodeRewardItem[]|nil 该距离的奖励节点列表
function LevelNodeRewardType:GetRewardNodesByDistance(distance)
    return self._distanceMap[distance]
end

--- 检查指定距离是否有奖励节点
---@param distance number 距离值
---@return boolean
function LevelNodeRewardType:HasRewardAtDistance(distance)
    return self._distanceMap[distance] ~= nil
end

--- 获取所有距离值（已排序）
---@return number[]
function LevelNodeRewardType:GetAllDistances()
    local distances = {}
    for distance, _ in pairs(self._distanceMap) do
        table.insert(distances, distance)
    end
    table.sort(distances)
    return distances
end

--- 获取下一个奖励距离
---@param currentDistance number 当前距离
---@return number|nil 下一个奖励距离，如果没有则返回nil
function LevelNodeRewardType:GetNextRewardDistance(currentDistance)
    local distances = self:GetAllDistances()
    
    for _, distance in ipairs(distances) do
        if distance > currentDistance then
            return distance
        end
    end
    
    return nil
end

--- 获取上一个奖励距离
---@param currentDistance number 当前距离
---@return number|nil 上一个奖励距离，如果没有则返回nil
function LevelNodeRewardType:GetPreviousRewardDistance(currentDistance)
    local distances = self:GetAllDistances()
    
    for i = #distances, 1, -1 do
        local distance = distances[i]
        if distance < currentDistance then
            return distance
        end
    end
    
    return nil
end

--- 根据唯一ID获取奖励节点
---@param uniqueId string 唯一ID
---@return LevelNodeRewardItem|nil 奖励节点，如果不存在则返回nil
function LevelNodeRewardType:GetRewardNodeById(uniqueId)
    if not uniqueId or uniqueId == "" then
        return nil
    end
    
    return self._idMap[uniqueId]
end

--- 检查指定唯一ID是否存在
---@param uniqueId string 唯一ID
---@return boolean 是否存在
function LevelNodeRewardType:HasRewardNode(uniqueId)
    return self:GetRewardNodeById(uniqueId) ~= nil
end

--- 根据奖励类型筛选节点
---@param rewardType string 奖励类型
---@return LevelNodeRewardItem[] 匹配的奖励节点列表
function LevelNodeRewardType:GetRewardNodesByType(rewardType)
    local result = {}
    
    if not rewardType or rewardType == "" then
        return result
    end
    
    for _, node in ipairs(self.rewardNodes) do
        if node["奖励类型"] == rewardType then
            table.insert(result, node)
        end
    end
    
    return result
end

--- 根据物品类型筛选节点
---@param itemType string 物品类型
---@return LevelNodeRewardItem[] 匹配的奖励节点列表
function LevelNodeRewardType:GetRewardNodesByItemType(itemType)
    local result = {}
    
    if not itemType or itemType == "" then
        return result
    end
    
    for _, node in ipairs(self.rewardNodes) do
        if node["物品类型"] == itemType then
            table.insert(result, node)
        end
    end
    
    return result
end

--- 获取指定距离范围内的所有奖励节点
---@param minDistance number 最小距离
---@param maxDistance number 最大距离
---@return LevelNodeRewardItem[] 范围内的奖励节点列表
function LevelNodeRewardType:GetRewardNodesInRange(minDistance, maxDistance)
    local result = {}
    
    if not minDistance or not maxDistance or minDistance > maxDistance then
        return result
    end
    
    for _, node in ipairs(self.rewardNodes) do
        local distance = node["生成的距离配置"] or 0
        if distance >= minDistance and distance <= maxDistance then
            table.insert(result, node)
        end
    end
    
    return result
end

--- 检查是否有奖励节点
---@return boolean
function LevelNodeRewardType:HasRewardNodes()
    return #self.rewardNodes > 0
end

--- 【新增】获取唯一ID映射表中的节点数量
---@return number 唯一ID映射数量
function LevelNodeRewardType:GetUniqueIdCount()
    local count = 0
    for _ in pairs(self._idMap) do
        count = count + 1
    end
    return count
end

--- 【新增】获取所有唯一ID列表
---@return string[] 所有唯一ID的数组
function LevelNodeRewardType:GetAllUniqueIds()
    local ids = {}
    for uniqueId, _ in pairs(self._idMap) do
        table.insert(ids, uniqueId)
    end
    table.sort(ids) -- 排序以便于调试和显示
    return ids
end

--- 【新增】批量检查多个唯一ID是否存在
---@param uniqueIds string[] 要检查的唯一ID数组
---@return table<string, boolean> 每个ID的存在状态 {ID = true/false}
function LevelNodeRewardType:CheckMultipleUniqueIds(uniqueIds)
    local result = {}
    
    if not uniqueIds or type(uniqueIds) ~= "table" then
        return result
    end
    
    for _, uniqueId in ipairs(uniqueIds) do
        if uniqueId and uniqueId ~= "" then
            result[uniqueId] = self._idMap[uniqueId] ~= nil
        end
    end
    
    return result
end

--- 【新增】获取指定唯一ID列表对应的所有节点
---@param uniqueIds string[] 唯一ID数组
---@return LevelNodeRewardItem[] 对应的节点列表
function LevelNodeRewardType:GetRewardNodesByIds(uniqueIds)
    local result = {}
    
    if not uniqueIds or type(uniqueIds) ~= "table" then
        return result
    end
    
    for _, uniqueId in ipairs(uniqueIds) do
        if uniqueId and uniqueId ~= "" then
            local node = self._idMap[uniqueId]
            if node then
                table.insert(result, node)
            end
        end
    end
    
    return result
end

--- 【新增】获取唯一ID映射表的完整副本
---@return table<string, LevelNodeRewardItem> 唯一ID映射表的副本
function LevelNodeRewardType:GetIdMapCopy()
    local copy = {}
    for uniqueId, node in pairs(self._idMap) do
        copy[uniqueId] = node
    end
    return copy
end

--- 【新增】验证唯一ID映射表的完整性
---@return boolean isValid, string message 验证是否通过与提示信息
function LevelNodeRewardType:ValidateIdMap()
    local idCount = self:GetUniqueIdCount()
    local nodeCount = #self.rewardNodes
    
    if idCount ~= nodeCount then
        return false, string.format("唯一ID映射表不完整: 节点总数=%d, 映射数量=%d", nodeCount, idCount)
    end
    
    -- 检查是否有重复的唯一ID
    local seenIds = {}
    for uniqueId, _ in pairs(self._idMap) do
        if seenIds[uniqueId] then
            return false, string.format("发现重复的唯一ID: %s", uniqueId)
        end
        seenIds[uniqueId] = true
    end
    
    return true, "唯一ID映射表验证通过"
end

--- 获取配置信息摘要
---@return table 配置信息摘要
function LevelNodeRewardType:GetSummary()
    return {
        name = self.name,
        description = self.description,
        sceneName = self.sceneName,
        nodeCount = #self.rewardNodes,
        distanceCount = #self:GetAllDistances(),
        uniqueIdCount = self:GetUniqueIdCount(),
        bonusVariableCount = self:GetBonusVariableCount(),
        minDistance = #self:GetAllDistances() > 0 and self:GetAllDistances()[1] or 0,
        maxDistance = #self:GetAllDistances() > 0 and self:GetAllDistances()[#self:GetAllDistances()] or 0
    }
end

--- 【新增】获取所有加成变量
---@return table[] 加成变量列表
function LevelNodeRewardType:GetAllBonusVariables()
    return self.bonusVariables
end

--- 【新增】获取加成变量数量
---@return number 加成变量数量
function LevelNodeRewardType:GetBonusVariableCount()
    return #self.bonusVariables
end

--- 【新增】根据变量名称获取加成变量
---@param varName string 变量名称
---@return table|nil 加成变量配置，如果不存在则返回nil
function LevelNodeRewardType:GetBonusVariableByName(varName)
    if not varName or varName == "" then
        return nil
    end
    
    return self._bonusVariableMap[varName]
end

--- 【新增】检查指定变量名称是否存在
---@param varName string 变量名称
---@return boolean 是否存在
function LevelNodeRewardType:HasBonusVariable(varName)
    return self:GetBonusVariableByName(varName) ~= nil
end

--- 【新增】根据作用目标筛选加成变量
---@param target string 作用目标（如：金币、经验等）
---@return table[] 匹配的加成变量列表
function LevelNodeRewardType:GetBonusVariablesByTarget(target)
    local result = {}
    
    if not target or target == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        if bonusVar["作用目标"] == target then
            table.insert(result, bonusVar)
        end
    end
    
    return result
end

--- 【新增】根据加成方式筛选加成变量
---@param bonusType string 加成方式（如：最终乘法、固定加成等）
---@return table[] 匹配的加成变量列表
function LevelNodeRewardType:GetBonusVariablesByType(bonusType)
    local result = {}
    
    if not bonusType or bonusType == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        if bonusVar["加成方式"] == bonusType then
            table.insert(result, bonusVar)
        end
    end
    
    return result
end

--- 【新增】根据变量属性筛选加成变量
---@param varProperty string 变量属性（如：玩家变量、全局变量等）
---@return table[] 匹配的加成变量列表
function LevelNodeRewardType:GetBonusVariablesByProperty(varProperty)
    local result = {}
    
    if not varProperty or varProperty == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        if bonusVar["变量属性"] == varProperty then
            table.insert(result, bonusVar)
        end
    end
    
    return result
end

--- 【新增】获取所有作用目标列表
---@return string[] 所有作用目标的数组
function LevelNodeRewardType:GetAllTargets()
    local targets = {}
    local seen = {}
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local target = bonusVar["作用目标"]
        if target and target ~= "" and not seen[target] then
            table.insert(targets, target)
            seen[target] = true
        end
    end
    
    table.sort(targets)
    return targets
end

--- 【新增】获取所有加成方式列表
---@return string[] 所有加成方式的数组
function LevelNodeRewardType:GetAllBonusTypes()
    local types = {}
    local seen = {}
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local bonusType = bonusVar["加成方式"]
        if bonusType and bonusType ~= "" and not seen[bonusType] then
            table.insert(types, bonusType)
            seen[bonusType] = true
        end
    end
    
    table.sort(types)
    return types
end

--- 【新增】获取所有变量属性列表
---@return string[] 所有变量属性的数组
function LevelNodeRewardType:GetAllVariableProperties()
    local properties = {}
    local seen = {}
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local property = bonusVar["变量属性"]
        if property and property ~= "" and not seen[property] then
            table.insert(properties, property)
            seen[property] = true
        end
    end
    
    table.sort(properties)
    return properties
end

--- 【新增】验证加成变量配置的完整性
---@return boolean isValid, string message 验证是否通过与提示信息
function LevelNodeRewardType:ValidateBonusVariables()
    local varCount = self:GetBonusVariableCount()
    local mapCount = 0
    
    -- 统计映射表中的数量
    for _ in pairs(self._bonusVariableMap) do
        mapCount = mapCount + 1
    end
    
    if varCount ~= mapCount then
        return false, string.format("加成变量映射表不完整: 变量总数=%d, 映射数量=%d", varCount, mapCount)
    end
    
    -- 检查是否有重复的变量名称
    local seenNames = {}
    for _, bonusVar in ipairs(self.bonusVariables) do
        local varName = bonusVar["变量名称"]
        if varName and varName ~= "" then
            if seenNames[varName] then
                return false, string.format("发现重复的变量名称: %s", varName)
            end
            seenNames[varName] = true
        end
    end
    
    return true, "加成变量配置验证通过"
end

--- 【新增】获取加成变量映射表的完整副本
---@return table<string, table> 加成变量映射表的副本
function LevelNodeRewardType:GetBonusVariableMapCopy()
    local copy = {}
    for varName, bonusVar in pairs(self._bonusVariableMap) do
        copy[varName] = bonusVar
    end
    return copy
end

--- 【新增】根据目标物品获取对应的加成变量名称列表
---@param targetItem string 目标物品名称（如：金币、经验等）
---@return string[] 匹配的加成变量名称列表
function LevelNodeRewardType:GetBonusVariableNamesByTarget(targetItem)
    local result = {}
    
    if not targetItem or targetItem == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local target = bonusVar["作用目标"]
        local varName = bonusVar["变量名称"]
        
        if target == targetItem and varName and varName ~= "" then
            table.insert(result, varName)
        end
    end
    
    return result
end

--- 【新增】根据目标物品获取对应的加成变量配置列表
---@param targetItem string 目标物品名称（如：金币、经验等）
---@return table[] 匹配的加成变量配置列表
function LevelNodeRewardType:GetBonusVariablesByTargetItem(targetItem)
    local result = {}
    
    if not targetItem or targetItem == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local target = bonusVar["作用目标"]
        
        if target == targetItem then
            table.insert(result, bonusVar)
        end
    end
    
    return result
end

--- 【新增】检查指定目标物品是否有对应的加成变量
---@param targetItem string 目标物品名称
---@return boolean 是否存在对应的加成变量
function LevelNodeRewardType:HasBonusVariableForTarget(targetItem)
    if not targetItem or targetItem == "" then
        return false
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        if bonusVar["作用目标"] == targetItem then
            return true
        end
    end
    
    return false
end

--- 【新增】获取所有目标物品及其对应的加成变量数量
---@return table<string, number> 目标物品到加成变量数量的映射
function LevelNodeRewardType:GetTargetItemBonusCounts()
    local counts = {}
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local target = bonusVar["作用目标"]
        if target and target ~= "" then
            counts[target] = (counts[target] or 0) + 1
        end
    end
    
    return counts
end

return LevelNodeRewardType
