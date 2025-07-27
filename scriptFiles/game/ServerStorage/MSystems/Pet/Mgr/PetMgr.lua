-- PetMgr.lua
-- 宠物系统管理模块 - 重构版本
-- 负责管理所有在线玩家的宠物管理器，提供系统级接口

local game = game
local os = os
local table = table
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CloudPetDataAccessor = require(ServerStorage.MSystems.Pet.CloudData.PetCloudDataMgr) ---@type CloudPetDataAccessor
local Pet = require(ServerStorage.MSystems.Pet.Compainion.Pet) ---@type Pet

---@class PetMgr
local PetMgr = {
    -- 在线玩家宠物管理器缓存 {uin = Pet管理器实例}
    server_player_pets = {}, ---@type table<number, Pet>
    
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
    
    -- 创建Pet管理器实例并缓存
    local petManager = Pet.New(uin, playerPetData)
    PetMgr.server_player_pets[uin] = petManager
    
    gg.log("玩家宠物管理器加载完成", uin, "宠物数量", petManager:GetPetCount())
end

---玩家离线处理
---@param uin number 玩家ID
function PetMgr.OnPlayerLeave(uin)
    local petManager = PetMgr.server_player_pets[uin]
    if petManager then
        -- 提取数据并保存到云端
        local playerPetData = petManager:GetSaveData()
        if playerPetData then
            CloudPetDataAccessor:SavePlayerPetData(uin, playerPetData)
        end
        
        -- 清理内存缓存
        PetMgr.server_player_pets[uin] = nil
        gg.log("玩家宠物数据已保存并清理", uin)
    end
end

---获取玩家宠物管理器
---@param uin number 玩家ID
---@return Pet|nil 宠物管理器实例
function PetMgr.GetPlayerPet(uin)
    return PetMgr.server_player_pets[uin]
end

---设置激活宠物
---@param uin number 玩家ID
---@param slotIndex number 槽位索引（0表示取消激活）
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.SetActivePet(uin, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在"
    end
    
    return petManager:SetActivePet(slotIndex)
end

---宠物升级
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级，nil表示升1级
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否真的升级了
function PetMgr.LevelUpPet(uin, slotIndex, targetLevel)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在", false
    end
    
    return petManager:LevelUpPet(slotIndex, targetLevel)
end

---宠物获得经验
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否升级了
function PetMgr.AddPetExp(uin, slotIndex, expAmount)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在", false
    end
    
    return petManager:AddPetExp(slotIndex, expAmount)
end

---宠物升星
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.UpgradePetStar(uin, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在"
    end
    
    return petManager:UpgradePetStar(slotIndex)
end

---宠物学习技能
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.LearnPetSkill(uin, slotIndex, skillId)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在"
    end
    
    return petManager:LearnPetSkill(slotIndex, skillId)
end

---获取玩家所有宠物信息
---@param uin number 玩家ID
---@return table|nil 宠物列表，失败返回nil
---@return string|nil 错误信息
function PetMgr.GetPlayerPetList(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return nil, "玩家数据不存在"
    end
    
    return petManager:GetPlayerPetList(), nil
end

---获取宠物数量
---@param uin number 玩家ID
---@return number 宠物数量
function PetMgr.GetPetCount(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return 0
    end
    
    return petManager:GetPetCount()
end

---获取激活的宠物
---@param uin number 玩家ID
---@return CompanionInstance|nil 激活的宠物实例
---@return number|nil 槽位索引
function PetMgr.GetActivePet(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return nil, nil
    end
    
    return petManager:GetActivePet()
end

---获取指定槽位的宠物实例
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return CompanionInstance|nil 宠物实例
function PetMgr.GetPetInstance(uin, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return nil
    end
    
    return petManager:GetPetBySlot(slotIndex)
end

---添加宠物到指定槽位
---@param uin number 玩家ID
---@param petName string 宠物配置名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function PetMgr.AddPetToSlot(uin, petName, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在", nil
    end
    
    return petManager:AddPet(petName, slotIndex)
end

---移除指定槽位的宠物
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.RemovePetFromSlot(uin, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在"
    end
    
    return petManager:RemovePet(slotIndex)
end

---获取宠物的最终属性
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function PetMgr.GetPetFinalAttribute(uin, slotIndex, attrName)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return nil
    end
    
    return petManager:GetPetFinalAttribute(slotIndex, attrName)
end

---检查宠物是否可以升级
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function PetMgr.CanPetLevelUp(uin, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false
    end
    
    return petManager:CanPetLevelUp(slotIndex)
end

---检查宠物是否可以升星
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function PetMgr.CanPetUpgradeStar(uin, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在"
    end
    
    return petManager:CanPetUpgradeStar(slotIndex)
end

---给玩家添加宠物
---@param player MPlayer 玩家对象
---@param petName string 宠物名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function PetMgr.AddPet(player, petName, slotIndex)
    if not player or not player.uin then
        gg.log("PetMgr.AddPet: 玩家对象无效")
        return false, nil
    end
    
    local success, errorMsg, actualSlot = PetMgr.AddPetToSlot(player.uin, petName, slotIndex)
    if success then
        gg.log("PetMgr.AddPet: 成功给玩家", player.uin, "添加宠物", petName, "槽位", actualSlot)
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, actualSlot)
    else
        gg.log("PetMgr.AddPet: 给玩家", player.uin, "添加宠物失败", petName, "错误", errorMsg)
    end
    
    return success, actualSlot
end

---给玩家添加宠物（通过UIN）
---@param uin number 玩家UIN
---@param petName string 宠物名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function PetMgr.AddPetByUin(uin, petName, slotIndex)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    if not player then
        gg.log("PetMgr.AddPetByUin: 玩家不存在", uin)
        return false, nil
    end
    
    return PetMgr.AddPet(player, petName, slotIndex)
end

---通知客户端宠物数据更新
---@param uin number 玩家ID
---@param slotIndex number|nil 具体槽位，nil表示全部更新
function PetMgr.NotifyPetDataUpdate(uin, slotIndex)
    local PetEventManager = require(ServerStorage.MSystems.Pet.PetEventManager) ---@type PetEventManager
    
    if slotIndex then
        -- 单个宠物更新
        local petManager = PetMgr.GetPlayerPet(uin)
        if petManager then
            local petInstance = petManager:GetPetBySlot(slotIndex)
            if petInstance then
                PetEventManager.NotifyPetUpdate(uin, petInstance:GetFullInfo())
            end
        end
    else
        -- 全部宠物更新
        local result, errorMsg = PetMgr.GetPlayerPetList(uin)
        if result then
            PetEventManager.NotifyPetListUpdate(uin, result.petList)
        end
    end
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

---强制保存玩家宠物数据
---@param uin number 玩家UIN
function PetMgr.ForceSavePlayerData(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        local playerPetData = petManager:GetSaveData()
        if playerPetData then
            CloudPetDataAccessor:SavePlayerPetData(uin, playerPetData)
            gg.log("PetMgr.ForceSavePlayerData: 强制保存宠物数据", uin)
        end
    end
end

---批量升级所有可升级宠物
---@param uin number 玩家ID
---@return number 升级的宠物数量
function PetMgr.UpgradeAllPossiblePets(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return 0
    end
    
    local upgradedCount = petManager:UpgradeAllPossiblePets()
    if upgradedCount > 0 then
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(uin)
    end
    
    return upgradedCount
end

---获取指定类型的宠物数量
---@param uin number 玩家ID
---@param petName string 宠物名称
---@param minStar number|nil 最小星级要求
---@return number 宠物数量
function PetMgr.GetPetCountByType(uin, petName, minStar)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return 0
    end
    
    return petManager:GetPetCountByType(petName, minStar)
end

--- 获取当前激活宠物的物品加成
---@param uin number 玩家ID
---@return table<string, number> 激活宠物的物品加成
function PetMgr.GetActiveItemBonuses(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        gg.log("[PetMgr] GetActiveItemBonuses: 找不到玩家的宠物管理器", uin)
        return {}
    end
    
    return petManager:GetActiveItemBonuses()
end

---定时更新所有在线玩家的宠物buff
function PetMgr.UpdateAllPlayerPetBuffs()
    for uin, petManager in pairs(PetMgr.server_player_pets) do
        petManager:UpdateAllPetBuffs()
    end
end

---定时保存所有在线玩家的宠物数据
function PetMgr.SaveAllPlayerData()
    for uin, petManager in pairs(PetMgr.server_player_pets) do
        local playerPetData = petManager:GetSaveData()
        if playerPetData then
            CloudPetDataAccessor:SavePlayerPetData(uin, playerPetData)
        end
    end
    gg.log("PetMgr.SaveAllPlayerData: 批量保存所有玩家宠物数据")
end



return PetMgr