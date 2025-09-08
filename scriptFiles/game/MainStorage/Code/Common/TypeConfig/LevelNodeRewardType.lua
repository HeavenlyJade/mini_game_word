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
---@field _distanceMap table<number, LevelNodeRewardItem[]> 按距离分组的奖励节点映射
---@field _idMap table<string, LevelNodeRewardItem> 按唯一ID分组的奖励节点映射
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
        minDistance = #self:GetAllDistances() > 0 and self:GetAllDistances()[1] or 0,
        maxDistance = #self:GetAllDistances() > 0 and self:GetAllDistances()[#self:GetAllDistances()] or 0
    }
end

return LevelNodeRewardType
