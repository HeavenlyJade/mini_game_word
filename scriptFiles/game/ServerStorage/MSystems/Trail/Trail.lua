-- Trail.lua
-- 尾迹实体管理器
-- 管理单个玩家的所有尾迹数据和业务逻辑

local game = game
local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class Trail:Class
---@field uin number 玩家ID
---@field trailInstances table<number, table> 尾迹实例列表 {slotIndex = trailData}
---@field activeTrailSlots table<string, number> 激活的尾迹槽位映射 {[装备栏ID] = 背包槽位ID}
---@field equipSlotIds table<string> 所有可用的装备栏ID
---@field unlockedEquipSlots number 玩家当前已解锁的装备栏数量
---@field maxSlots number 最大槽位数
---@field New fun(uin:number, equipSlotIds:table):Trail
local Trail = ClassMgr.Class("Trail")

function Trail:OnInit(uin, equipSlotIds)
    self.uin = uin or 0
    self.trailInstances = {}
    self.activeTrailSlots = {}
    self.equipSlotIds = equipSlotIds or {"Trail1"} -- 默认只有一个装备栏
    self.unlockedEquipSlots = 1 -- 默认解锁1个装备栏
    self.maxSlots = 30 -- 尾迹背包容量
    
    --gg.log("Trail尾迹管理器初始化完成", uin)
end

-- =================================
-- 基础功能实现
-- =================================

---加载尾迹配置
---@param trailName string 尾迹名称
---@return table|nil 尾迹配置
function Trail:LoadConfigByName(trailName)
    return ConfigLoader.GetTrail(trailName)
end

---创建尾迹数据
---@param trailName string 尾迹名称
---@param trailTypeConfig table 尾迹配置
---@return table 尾迹数据
function Trail:CreateCompanionData(trailName, trailTypeConfig)
    return {
        trailName = trailName,
        customName = "",
        level = 1,
        exp = 0,
        starLevel = 1,
        learnedSkills = {},
        equipments = {},
        isActive = false,
        mood = 100,
        isLocked = false
    }
end

---获取保存数据
---@return table 尾迹保存数据
function Trail:GetSaveData()
    local playerTrailData = {
        activeSlots = self.activeTrailSlots,
        trailList = {},
        trailSlots = self.maxSlots,
        unlockedEquipSlots = self.unlockedEquipSlots
    }

    -- 提取所有尾迹的数据
    for slotIndex, trailData in pairs(self.trailInstances) do
        playerTrailData.trailList[slotIndex] = trailData
    end

    return playerTrailData
end

---从尾迹数据加载
---@param playerTrailData table 尾迹数据
function Trail:LoadFromTrailData(playerTrailData)
    if not playerTrailData then return end

    self.activeTrailSlots = playerTrailData.activeSlots or {}
    self.maxSlots = playerTrailData.trailSlots or 30

    -- 加载已解锁的装备栏数量，确保不超过系统配置的最大值
    local maxEquipped = #self.equipSlotIds
    self.unlockedEquipSlots = math.min(playerTrailData.unlockedEquipSlots or 1, maxEquipped)

    -- 加载尾迹数据
    for slotIndex, trailData in pairs(playerTrailData.trailList or {}) do
        self.trailInstances[slotIndex] = trailData
    end

    --gg.log("从尾迹数据加载", self.uin, "激活槽位数量", #(self.activeTrailSlots or {}), "尾迹数", self:GetTrailCount())
end

---获取尾迹数量
---@return number 尾迹数量
function Trail:GetTrailCount()
    local count = 0
    for _ in pairs(self.trailInstances) do
        count = count + 1
    end
    return count
end

---获取指定槽位的尾迹数据
---@param slotIndex number 槽位索引
---@return table|nil 尾迹数据
function Trail:GetTrailBySlot(slotIndex)
    return self.trailInstances[slotIndex]
end

---查找空闲槽位
---@return number|nil 空闲槽位索引
function Trail:FindEmptySlot()
    for i = 1, self.maxSlots do
        if not self.trailInstances[i] then
            return i
        end
    end
    return nil
end

---获取尾迹列表信息
---@return table 尾迹列表信息
function Trail:GetPlayerTrailList()
    local trailList = {}

    for slotIndex, trailData in pairs(self.trailInstances) do
        trailList[slotIndex] = {
            trailName = trailData.trailName,
            customName = trailData.customName,
            level = trailData.level,
            exp = trailData.exp,
            starLevel = trailData.starLevel,
            learnedSkills = trailData.learnedSkills,
            equipments = trailData.equipments,
            isActive = trailData.isActive,
            mood = trailData.mood,
            isLocked = trailData.isLocked,
            slotIndex = slotIndex,
            companionType = "尾迹"
        }
    end

    -- 计算当前玩家实际可用的装备栏
    local availableEquipSlots = {}
    for i = 1, self.unlockedEquipSlots do
        if self.equipSlotIds[i] then
            table.insert(availableEquipSlots, self.equipSlotIds[i])
        end
    end

    return {
        companionList = trailList,
        activeSlots = self.activeTrailSlots,
        equipSlotIds = availableEquipSlots,
        unlockedEquipSlots = self.unlockedEquipSlots,
        maxEquipSlots = #self.equipSlotIds,
        companionType = "尾迹"
    }
end

-- =================================
-- 尾迹操作接口
-- =================================

---添加尾迹
---@param trailName string 尾迹名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function Trail:AddTrail(trailName, slotIndex)
    -- 检查尾迹配置是否存在
    local trailTypeConfig = self:LoadConfigByName(trailName)
    if not trailTypeConfig then
        return false, "尾迹配置不存在", nil
    end

    -- 自动分配槽位
    if not slotIndex then
        slotIndex = self:FindEmptySlot()
        if not slotIndex then
            return false, "背包已满", nil
        end
    end

    -- 检查槽位是否有效
    if slotIndex < 1 or slotIndex > self.maxSlots then
        return false, "无效的槽位索引", nil
    end

    -- 检查槽位是否被占用
    if self.trailInstances[slotIndex] then
        return false, "槽位已被占用", nil
    end

    -- 创建新的尾迹数据
    local newTrailData = self:CreateCompanionData(trailName, trailTypeConfig)
    self.trailInstances[slotIndex] = newTrailData

    --gg.log("添加尾迹成功", self.uin, trailName, "槽位", slotIndex)
    return true, nil, slotIndex
end

---移除尾迹
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function Trail:RemoveTrail(slotIndex)
    local trailData = self.trailInstances[slotIndex]
    if not trailData then
        return false, "槽位为空"
    end

    -- 如果被移除的尾迹正在装备中，则将其从所有装备栏卸下
    for equipSlotId, equippedTrailSlotId in pairs(self.activeTrailSlots) do
        if equippedTrailSlotId == slotIndex then
            self:UnequipTrail(equipSlotId)
        end
    end

    -- 移除尾迹实例
    self.trailInstances[slotIndex] = nil

    --gg.log("移除尾迹成功", self.uin, trailData.trailName, "槽位", slotIndex)
    return true, nil
end

---删除尾迹（兼容接口）
---@param slotIndex number
---@return boolean, string|nil
function Trail:DeleteTrail(slotIndex)
    return self:RemoveTrail(slotIndex)
end

---切换尾迹锁定状态
---@param slotIndex number 槽位索引
---@return boolean, string|nil, boolean|nil
function Trail:ToggleTrailLock(slotIndex)
    local trailData = self.trailInstances[slotIndex]
    if not trailData then
        return false, "该槽位上没有尾迹", nil
    end

    local currentStatus = trailData.isLocked
    trailData.isLocked = not currentStatus

    return true, nil, not currentStatus
end

---装备尾迹到指定装备栏
---@param trailSlotId number 要装备的尾迹背包槽位ID
---@param equipSlotId string 目标装备栏ID (如 "Trail1")
---@return boolean 是否成功
---@return string|nil 错误信息
function Trail:EquipTrail(trailSlotId, equipSlotId)
    -- 1. 验证装备栏ID是否在玩家当前可用的栏位中
    local isUnlockEquipSlot = false
    for i = 1, self.unlockedEquipSlots do
        if self.equipSlotIds[i] == equipSlotId then
            isUnlockEquipSlot = true
            break
        end
    end
    if not isUnlockEquipSlot then
        return false, "该装备栏尚未解锁: " .. tostring(equipSlotId)
    end

    -- 2. 验证要装备的尾迹是否存在
    local trailToEquip = self:GetTrailBySlot(trailSlotId)
    if not trailToEquip then
        return false, "背包槽位 " .. tostring(trailSlotId) .. " 上没有尾迹"
    end

    -- 3. 如果该尾迹已装备在其他栏位，先从旧栏位卸下
    for oldEquipSlot, equippedTid in pairs(self.activeTrailSlots) do
        if equippedTid == trailSlotId then
            self:UnequipTrail(oldEquipSlot)
            break
        end
    end

    -- 4. 如果目标装备栏已有其他尾迹，先卸下旧的
    local oldTrailSlotId = self.activeTrailSlots[equipSlotId]
    if oldTrailSlotId and oldTrailSlotId > 0 then
        local oldTrailData = self:GetTrailBySlot(oldTrailSlotId)
        if oldTrailData then
            oldTrailData.isActive = false
        end
    end

    -- 5. 执行装备
    self.activeTrailSlots[equipSlotId] = trailSlotId
    trailToEquip.isActive = true

    -- 装备特效
    local player = MServerDataManager.server_players_list[self.uin]
    if player then
        self:UpdateAllEquippedTrailModels(player)
    else
        -- 如果玩家对象不存在，可以考虑记录日志或进行其他处理
        -- gg.log("警告：在EquipTrail中无法获取玩家对象，无法更新尾迹特效", self.uin)
    end

    --gg.log(string.format("装备尾迹成功: 玩家 %d, 背包槽位 %d -> 装备栏 %s", self.uin, trailSlotId, equipSlotId))
    return true, nil
end

---从指定装备栏卸下尾迹
---@param equipSlotId string 目标装备栏ID
---@return boolean
function Trail:UnequipTrail(equipSlotId)
    local trailSlotId = self.activeTrailSlots[equipSlotId]

    if trailSlotId and trailSlotId > 0 then
        local trailData = self:GetTrailBySlot(trailSlotId)
        if trailData then
            trailData.isActive = false
        end
        self.activeTrailSlots[equipSlotId] = nil
        
        -- 删除对应的玩家尾迹特效节点
        local player = MServerDataManager.server_players_list[self.uin]
        if player then
            self:UnequipTrailEffectForPlayer(player)
        else
            -- 如果玩家对象不存在，可以考虑记录日志或进行其他处理
            -- gg.log("警告：在UnequipTrail中无法获取玩家对象，无法卸载尾迹特效", self.uin)
        end
        
        --gg.log(string.format("卸下尾迹成功: 玩家 %d, 从装备栏 %s (原背包槽位 %d)", self.uin, equipSlotId, trailSlotId))
        return true
    end
    return false
end

---卸载指定玩家的尾迹特效
---@param player table 玩家对象
function Trail:UnequipTrailEffectForPlayer(player)
    -- 如果没有传入player参数，从MServerDataManager获取
    if not player then
        player = MServerDataManager.server_players_list[self.uin]
        if not player then
            --gg.log("错误：无法找到玩家对象", self.uin)
            return
        end
    end
    
    -- 卸载该玩家的所有尾迹特效
    self:UnequipTrailEffect(player)
end

---清理玩家离开时的尾迹特效
---@param playerId number 玩家ID
function Trail:CleanupPlayerTrailEffects(playerId)
    if not self.equippedEffectNodes then
        return
    end
    
    local effectNode = self.equippedEffectNodes[self.uin]
    if effectNode then
        effectNode:Destroy()
        self.equippedEffectNodes[self.uin] = nil
        --gg.log("清理玩家尾迹特效", self.uin)
    end
end

---查找指定名称的尾迹槽位
---@param trailName string 尾迹名称
---@return table<number> 槽位列表
function Trail:FindTrailSlotsByName(trailName)
    local slots = {}
    for slotIndex, trailData in pairs(self.trailInstances) do
        if trailData.trailName == trailName then
            table.insert(slots, slotIndex)
        end
    end
    return slots
end

---获取尾迹类型统计
---@return table<string, number> 尾迹类型统计
function Trail:GetTrailTypeStatistics()
    local statistics = {}
    for _, trailData in pairs(self.trailInstances) do
        local trailName = trailData.trailName
        statistics[trailName] = (statistics[trailName] or 0) + 1
    end
    return statistics
end

---设置尾迹背包容量
---@param capacity number 新容量
function Trail:SetTrailBagCapacity(capacity)
    self.maxSlots = capacity
end

---设置已解锁装备栏数量
---@param count number 装备栏数量
function Trail:SetUnlockedEquipSlots(count)
    self.unlockedEquipSlots = math.min(count, #self.equipSlotIds)
end

---更新所有装备的尾迹模型
---@param player table 玩家对象
function Trail:UpdateAllEquippedTrailModels(player)
    -- 如果没有传入player参数，从MServerDataManager获取
    if not player then
        player = MServerDataManager.server_players_list[self.uin]
        if not player then
            --gg.log("错误：无法找到玩家对象", self.uin)
            return
        end
    end

    for equipSlotId, trailSlotId in pairs(self.activeTrailSlots) do
        if trailSlotId and trailSlotId > 0 then
            local trailData = self:GetTrailBySlot(trailSlotId)
            if trailData then
                local trailName = trailData.trailName
                local trailConfig = ConfigLoader.GetTrail(trailName)
                
                if trailConfig and trailConfig.effectNode then
                    self:EquipTrailEffect(player, trailConfig.effectNode)
                end
            end
        end
    end
end

---装备尾迹特效
---@param player table 玩家对象
---@param effectNodePath string 特效节点路径
function Trail:EquipTrailEffect(player, effectNodePath)
    if not player or not effectNodePath then
        return
    end

    -- 1. 依据特效节点配置在MainStorage下面的对应节点的尾迹特效访问路径使用/分割，然后获取到后克隆对应的特效节点
    local effectNode = self:GetEffectNodeFromPath(effectNodePath)
    if not effectNode then
        --gg.log("错误：无法找到特效节点", effectNodePath)
        return
    end

    -- 克隆特效节点
    local clonedEffectNode = effectNode:Clone()
    if not clonedEffectNode then
        --gg.log("错误：克隆特效节点失败", effectNodePath)
        return
    end

    -- 2. 获取玩家对象的Actor下面的尾迹节点，然后获取它的LocalScale，Scale，LocalEuler，LocalPosition，Position，Euler
    local playerActor = player.Actor
    if not playerActor then
        --gg.log("错误：玩家Actor不存在")
        return
    end

    local trailNode = playerActor["尾迹"]
    if not trailNode then
       return 
    end

    -- 获取尾迹节点的变换属性
    local localScale = trailNode.LocalScale
    local scale = trailNode.Scale
    local localEuler = trailNode.LocalEuler
    local localPosition = trailNode.LocalPosition
    local position = trailNode.Position
    local euler = trailNode.Euler

    -- 3. 将这些属性替换到克隆的节点上面
    clonedEffectNode.LocalScale = localScale
    clonedEffectNode.Scale = scale
    clonedEffectNode.LocalEuler = localEuler
    clonedEffectNode.LocalPosition = localPosition
    clonedEffectNode.Position = position
    clonedEffectNode.Euler = euler

    -- 4. 将克隆的节点挂载到玩家的Actor节点上面
    clonedEffectNode.Parent = playerActor

    -- 保存克隆的节点引用，用于后续卸载
    if not self.equippedEffectNodes then
        self.equippedEffectNodes = {}
    end
    self.equippedEffectNodes[self.uin] = clonedEffectNode

    gg.log("装备尾迹特效成功", player.Name, effectNodePath)
end

---从路径获取特效节点
---@param effectNodePath string 特效节点路径
---@return SandboxNode|nil 特效节点
function Trail:GetEffectNodeFromPath(effectNodePath)
    if not effectNodePath then
        return nil
    end

    -- 使用/分割路径
    local pathParts = {}
    for part in effectNodePath:gmatch("[^/]+") do
        table.insert(pathParts, part)
    end

    -- 从MainStorage开始查找
    local currentNode = game:GetService("MainStorage")
    for _, part in ipairs(pathParts) do
        if currentNode and currentNode[part] then
            currentNode = currentNode[part]
        else
            --gg.log("错误：无法找到路径节点", part, "在", currentNode and currentNode.Name or "nil")
            return nil
        end
    end

    return currentNode
end

---卸载尾迹特效
---@param player table 玩家对象
function Trail:UnequipTrailEffect(player)
    if not player or not self.equippedEffectNodes then
        return
    end

    local effectNode = self.equippedEffectNodes[self.uin]
    
    if effectNode then
        -- 4. 卸载就是销毁这个节点
        effectNode:Destroy()
        self.equippedEffectNodes[self.uin] = nil
        --gg.log("卸载尾迹特效成功", player.Name)
    end
end

return Trail 