--- 宠物系统管理模块
--- V109 miniw-haima
--- 负责管理所有在线玩家的宠物数据，处理宠物相关的核心业务逻辑

local game = game
local os = os
local table = table
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local RunService = game:GetService('RunService')
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CloudPetDataAccessor = require(ServerStorage.MSystems.Pet.PetCloudDataMgr) ---@type CloudPetDataAccessor
local Pet = require(ServerStorage.MSystems.Pet.Pet) ---@type Pet

---@class PetMgr
local PetMgr = {
    -- 在线玩家宠物实例缓存 {uin = {slotIndex = Pet实例}}
    server_player_pet_instances = {},
    
    -- 定时保存间隔（秒）
    SAVE_INTERVAL = 30
}





---玩家上线处理
---@param player MPlayer 玩家对象
function PetMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        gg.log("玩家上线处理失败：玩家对象无效")
        return
    end
    
    local uin = player.uin
    gg.log("开始处理玩家宠物上线", uin)
    
    -- 从云端加载玩家宠物数据
    local playerPetData = CloudPetDataAccessor:LoadPlayerPetData(uin)
    
    -- 创建Pet实例并缓存
    PetMgr.server_player_pet_instances[uin] = {}
    for slotIndex, petData in pairs(playerPetData.petList) do
        local petInstance = PetMgr.CreatePetInstanceFromData(uin, petData, slotIndex)
        if petInstance then
            PetMgr.server_player_pet_instances[uin][slotIndex] = petInstance
        end
    end
    
    gg.log("玩家宠物实例加载完成", uin, "宠物数量", PetMgr.GetPetCount(uin))
end

---玩家离线处理
---@param uin number 玩家ID
function PetMgr.OnPlayerLeave(uin)
    local petInstances = PetMgr.server_player_pet_instances[uin]
    if petInstances then
        -- 从实例中提取数据并保存到云端
        local playerPetData = PetMgr.ExtractPlayerPetData(uin)
        if playerPetData then
            CloudPetDataAccessor:SavePlayerPetData(uin, playerPetData)
        end
        
        -- 清理内存缓存
        PetMgr.server_player_pet_instances[uin] = nil
        gg.log("玩家宠物实例已保存并清理", uin)
    end
end

---获得指定uin玩家的宠物实例列表
---@param uin number 玩家ID
---@return table|nil 玩家宠物实例列表 {slotIndex = Pet实例}
function PetMgr.GetPlayerPetInstances(uin)
    return PetMgr.server_player_pet_instances[uin]
end

---获取指定槽位的宠物实例
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return Class|nil 宠物实例
function PetMgr.GetPetInstance(uin, slotIndex)
    local instances = PetMgr.server_player_pet_instances[uin]
    return instances and instances[slotIndex] or nil
end

---从数据创建Pet实例
---@param uin number 玩家ID
---@param petData PetData 宠物数据
---@param slotIndex number 槽位索引
---@return Class|nil Pet实例
function PetMgr.CreatePetInstanceFromData(uin, petData, slotIndex)
    if not petData then
        return nil
    end
    
    -- 获取宠物配置
    local petType = ConfigLoader.GetPet(petData.petName)
    if not petType then
        gg.log("宠物配置不存在", petData.petName)
        return nil
    end
    
    -- 创建Pet实例，传入脏数据回调
    local onDirtyCallback = function(slot)
        -- 标记数据需要保存
        PetMgr.MarkPetDataDirty(uin, slot)
    end
    
    return Pet.New(petData, petType, slotIndex, onDirtyCallback)
end

---标记宠物数据为脏
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
function PetMgr.MarkPetDataDirty(uin, slotIndex)
    -- 这里可以添加保存逻辑，或者标记需要保存
    gg.log("宠物数据标记为脏", uin, "槽位", slotIndex)
end

---从实例中提取玩家宠物数据
---@param uin number 玩家ID
---@return PlayerPetData|nil 玩家宠物数据
function PetMgr.ExtractPlayerPetData(uin)
    local instances = PetMgr.GetPlayerPetInstances(uin)
    if not instances then
        return nil
    end
    
    local playerPetData = {
        activePetId = "",
        petList = {},
        petSlots = 50
    }
    
    for slotIndex, petInstance in pairs(instances) do
        playerPetData.petList[slotIndex] = petInstance.petData
        if petInstance:IsActive() then
            playerPetData.activePetId = petInstance:GetConfigName()
        end
    end
    
    return playerPetData
end

---获取宠物数量
---@param uin number 玩家ID
---@return number 宠物数量
function PetMgr.GetPetCount(uin)
    local instances = PetMgr.GetPlayerPetInstances(uin)
    if not instances then return 0 end
    
    local count = 0
    for _ in pairs(instances) do
        count = count + 1
    end
    return count
end

---获取激活的宠物
---@param uin number 玩家ID
---@return Class|nil 激活的宠物实例
---@return number|nil 槽位索引
function PetMgr.GetActivePet(uin)
    local instances = PetMgr.GetPlayerPetInstances(uin)
    if not instances then
        return nil, nil
    end
    
    -- 遍历找到激活的宠物
    for slotIndex, petInstance in pairs(instances) do
        if petInstance:IsActive() then
            return petInstance, slotIndex
        end
    end
    
    return nil, nil
end

---获取指定槽位的宠物
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return Class|nil 宠物实例
function PetMgr.GetPetBySlot(uin, slotIndex)
    return PetMgr.GetPetInstance(uin, slotIndex)
end

---添加宠物到指定槽位
---@param uin number 玩家ID
---@param petName string 宠物配置名称
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.AddPetToSlot(uin, petName, slotIndex)
    local instances = PetMgr.GetPlayerPetInstances(uin)
    if not instances then
        return false, "玩家数据不存在"
    end
    
    -- 检查槽位是否有效
    if slotIndex < 1 or slotIndex > 50 then
        return false, "无效的槽位索引"
    end
    
    -- 检查槽位是否被占用
    if instances[slotIndex] then
        return false, "槽位已被占用"
    end
    
    -- 检查宠物配置是否存在
    local petType = ConfigLoader.GetPet(petName)
    if not petType then
        return false, "宠物配置不存在"
    end
    
    -- 创建新的宠物数据
    local newPetData = {
        petName = petName,
        customName = "",
        level = petType.minLevel,
        exp = 0,
        starLevel = 1,
        learnedSkills = {},
        equipments = {},
        isActive = false,
        mood = 100
    }
    
    -- 创建Pet实例并添加到缓存
    local petInstance = PetMgr.CreatePetInstanceFromData(uin, newPetData, slotIndex)
    if petInstance then
        instances[slotIndex] = petInstance
        gg.log("添加宠物成功", uin, petName, "槽位", slotIndex)
        return true, nil
    else
        return false, "创建宠物实例失败"
    end
end

---移除指定槽位的宠物
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.RemovePetFromSlot(uin, slotIndex)
    local instances = PetMgr.GetPlayerPetInstances(uin)
    if not instances then
        return false, "玩家数据不存在"
    end
    
    local petInstance = instances[slotIndex]
    if not petInstance then
        return false, "槽位为空"
    end
    
    -- 如果是激活宠物，需要取消激活
    if petInstance:IsActive() then
        -- 取消所有宠物的激活状态
        for _, instance in pairs(instances) do
            instance:SetActive(false)
        end
    end
    
    -- 移除宠物实例
    instances[slotIndex] = nil
    
    gg.log("移除宠物成功", uin, petInstance:GetConfigName(), "槽位", slotIndex)
    return true, nil
end

---设置激活宠物
---@param uin number 玩家ID
---@param slotIndex number 槽位索引（0表示取消激活）
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.SetActivePet(uin, slotIndex)
    local instances = PetMgr.GetPlayerPetInstances(uin)
    if not instances then
        return false, "玩家数据不存在"
    end
    
    -- 取消激活
    if slotIndex == 0 then
        -- 将之前的激活宠物设为非激活状态
        for _, petInstance in pairs(instances) do
            if petInstance:IsActive() then
                petInstance:SetActive(false)
            end
        end
        
        gg.log("取消激活宠物", uin)
        return true, nil
    end
    
    -- 检查槽位是否存在宠物
    local targetPetInstance = instances[slotIndex]
    if not targetPetInstance then
        return false, "槽位为空"
    end
    
    -- 如果已经是激活状态
    if targetPetInstance:IsActive() then
        return false, "宠物已经是激活状态"
    end
    
    -- 将之前的激活宠物设为非激活状态
    for _, petInstance in pairs(instances) do
        if petInstance:IsActive() then
            petInstance:SetActive(false)
        end
    end
    
    -- 设置新的激活宠物
    targetPetInstance:SetActive(true)
    
    gg.log("设置激活宠物", uin, targetPetInstance:GetConfigName(), "槽位", slotIndex)
    return true, nil
end

---宠物升级
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级（nil表示升1级）
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean 是否升级了
function PetMgr.LevelUpPet(uin, slotIndex, targetLevel)
    local petInstance = PetMgr.GetPetInstance(uin, slotIndex)
    if not petInstance then
        return false, "宠物不存在", false
    end
    
    local currentLevel = petInstance:GetLevel()
    local newLevel = targetLevel or (currentLevel + 1)
    
    -- 检查等级是否有效
    if newLevel <= currentLevel then
        return false, "目标等级无效", false
    end
    
    if petInstance:IsMaxLevel() then
        return false, "已达到最大等级", false
    end
    
    -- 设置等级
    local success = petInstance:SetLevel(newLevel)
    if not success then
        return false, "等级设置失败", false
    end
    
    gg.log("宠物升级成功", uin, petInstance:GetConfigName(), "新等级", newLevel)
    return true, nil, true
end

---宠物获得经验
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean 是否升级了
function PetMgr.AddPetExp(uin, slotIndex, expAmount)
    local petInstance = PetMgr.GetPetInstance(uin, slotIndex)
    if not petInstance then
        return false, "宠物不存在", false
    end
    
    local leveledUp = petInstance:AddExp(expAmount)
    
    gg.log("宠物获得经验", uin, petInstance:GetConfigName(), "经验", expAmount, "是否升级", leveledUp)
    return true, nil, leveledUp
end

---宠物升星
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.UpgradePetStar(uin, slotIndex)
    local petInstance = PetMgr.GetPetInstance(uin, slotIndex)
    if not petInstance then
        return false, "宠物不存在"
    end
    
    local success, errorMsg = petInstance:UpgradeStar()
    if not success then
        return false, errorMsg or "升星失败"
    end
    
    gg.log("宠物升星成功", uin, petInstance:GetConfigName(), "新星级", petInstance:GetStarLevel())
    return true, nil
end

---宠物学习技能
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.LearnPetSkill(uin, slotIndex, skillId)
    local petInstance = PetMgr.GetPetInstance(uin, slotIndex)
    if not petInstance then
        return false, "宠物不存在"
    end
    
    local success, errorMsg = petInstance:LearnSkill(skillId)
    if not success then
        return false, errorMsg or "学习技能失败"
    end
    
    gg.log("宠物学习技能成功", uin, petInstance:GetConfigName(), "技能", skillId)
    return true, nil
end

---获取玩家所有宠物信息
---@param uin number 玩家ID
---@return table|nil 宠物列表，失败返回nil
---@return string|nil 错误信息
function PetMgr.GetPlayerPetList(uin)
    local instances = PetMgr.GetPlayerPetInstances(uin)
    if not instances then
        return nil, "玩家数据不存在"
    end
    
    local petList = {}
    local activePetId = ""
    for slotIndex, petInstance in pairs(instances) do
        petList[slotIndex] = petInstance:GetFullInfo()
        if petInstance:IsActive() then
            activePetId = petInstance:GetConfigName()
        end
    end
    
    return {
        petList = petList,
        activePetId = activePetId,
        petSlots = 50
    }, nil
end



---通知客户端宠物数据更新
---@param uin number 玩家ID
---@param slotIndex number|nil 具体槽位，nil表示全部更新
function PetMgr.NotifyPetDataUpdate(uin, slotIndex)
    local PetEventManager = require(ServerStorage.MSystems.Pet.PetEventManager) ---@type PetEventManager
    
    if slotIndex then
        -- 单个宠物更新
        local petInstance = PetMgr.GetPetInstance(uin, slotIndex)
        if petInstance then
            PetEventManager.NotifyPetUpdate(uin, petInstance:GetFullInfo())
        end
    else
        -- 全部宠物更新
        local result, errorMsg = PetMgr.GetPlayerPetList(uin)
        if result then
            PetEventManager.NotifyPetListUpdate(uin, result.petList)
        end
    end
end

---获取宠物的最终属性
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function PetMgr.GetPetFinalAttribute(uin, slotIndex, attrName)
    local petInstance = PetMgr.GetPetInstance(uin, slotIndex)
    if not petInstance then
        return nil
    end
    
    return petInstance:GetFinalAttribute(attrName)
end

---检查宠物是否可以升级
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function PetMgr.CanPetLevelUp(uin, slotIndex)
    local petInstance = PetMgr.GetPetInstance(uin, slotIndex)
    if not petInstance then
        return false
    end
    
    return petInstance:CanLevelUp()
end

---检查宠物是否可以升星
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function PetMgr.CanPetUpgradeStar(uin, slotIndex)
    local petInstance = PetMgr.GetPetInstance(uin, slotIndex)
    if not petInstance then
        return false, "宠物不存在"
    end
    
    return petInstance:CanUpgradeStar()
end

---给玩家添加宠物
---@param player MPlayer 玩家对象
---@param petName string 宠物名称
---@param slotIndex number 槽位索引
---@return boolean 是否添加成功
function PetMgr.AddPet(player, petName, slotIndex)
    if not player or not player.uin then
        gg.log("PetMgr.AddPet: 玩家对象无效")
        return false
    end
    
    local success, errorMsg = PetMgr.AddPetToSlot(player.uin, petName, slotIndex)
    if success then
        gg.log("PetMgr.AddPet: 成功给玩家", player.uin, "添加宠物", petName, "槽位", slotIndex)
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
    else
        gg.log("PetMgr.AddPet: 给玩家", player.uin, "添加宠物失败", petName, "错误", errorMsg)
    end
    
    return success
end

---给玩家添加宠物（通过UIN）
---@param uin number 玩家UIN
---@param petName string 宠物名称
---@param slotIndex number 槽位索引
---@return boolean 是否添加成功
function PetMgr.AddPetByUin(uin, petName, slotIndex)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    if not player then
        gg.log("PetMgr.AddPetByUin: 玩家不存在", uin)
        return false
    end
    
    return PetMgr.AddPet(player, petName, slotIndex)
end

---强制同步玩家宠物数据到客户端
---@param uin number 玩家UIN
function PetMgr.ForceSyncToClient(uin)
    local result, errorMsg = PetMgr.GetPlayerPetList(uin)
    if result then
        local PetEventManager = require(ServerStorage.MSystems.Pet.PetEventManager) ---@type PetEventManager
        PetEventManager.NotifyPetListUpdate(uin, result.petList)
        gg.log("PetMgr.ForceSyncToClient: 强制同步宠物数据", uin)
    else
        gg.log("PetMgr.ForceSyncToClient: 同步失败", uin, errorMsg)
    end
end

return PetMgr