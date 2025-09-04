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
        --gg.log("玩家上线处理失败：玩家对象无效")
        return
    end

    local uin = player.uin
    --gg.log("开始处理玩家宠物上线", uin)

    -- 从云端加载玩家宠物数据
    local playerPetData = CloudPetDataAccessor:LoadPlayerPetData(uin)

    -- 创建Pet管理器实例并缓存
    local petManager = Pet.New(uin, playerPetData)
    PetMgr.server_player_pets[uin] = petManager

    --gg.log("玩家宠物管理器加载完成", uin, "宠物数量", petManager:GetPetCount())
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
        if playerPetData then
            gg.log("=== 玩家宠物完整数据开始 ===")
            gg.log(gg.printTable(playerPetData))
            gg.log("=== 玩家宠物完整数据结束 ===")
        end    end
end

---获取玩家宠物管理器
---@param uin number 玩家ID
---@return Pet|nil 宠物管理器实例
function PetMgr.GetPlayerPet(uin)
    local petManager = PetMgr.server_player_pets[uin]
    if not petManager then
        --gg.log("宠物系统：在缓存中未找到玩家", uin, "的宠物管理器，尝试动态加载。")
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            PetMgr.OnPlayerJoin(player)
            petManager = PetMgr.server_player_pets[uin]
        end

        if petManager then
            --gg.log("宠物系统：为玩家", uin, "动态加载宠物管理器成功。")
        else
            --gg.log("宠物系统：为玩家", uin, "动态加载宠物管理器失败。")
        end
    end
    return petManager
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

---直接设置宠物星级（不消耗材料）
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param targetStarLevel number 目标星级
---@return boolean 是否成功
---@return string|nil 错误信息
function PetMgr.SetPetStarLevel(uin, slotIndex, targetStarLevel)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家数据不存在"
    end

    return petManager:SetPetStarLevel(slotIndex, targetStarLevel)
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
        return nil
    end

    return petManager:GetPlayerPetList()
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

---【新增】装备宠物接口
---@param uin number 玩家ID
---@param companionSlotId number 要装备的宠物背包槽位ID
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function PetMgr.EquipPet(uin, companionSlotId, equipSlotId)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家宠物数据不存在"
    end

    local success, errorMsg = petManager:EquipPet(companionSlotId, equipSlotId)

    if success then
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            PetMgr.UpdateAllEquippedPetModels(player)
        end
        -- 【修复】通知客户端数据更新
        PetMgr.NotifyPetDataUpdate(uin)
    end

    return success, errorMsg
end

---【新增】卸下宠物接口
---@param uin number 玩家ID
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function PetMgr.UnequipPet(uin, equipSlotId)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家宠物数据不存在"
    end

    local success, errorMsg = petManager:UnequipPet(equipSlotId)

    if success then
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            PetMgr.UpdateAllEquippedPetModels(player)
        end
        -- 【修复】通知客户端数据更新
        PetMgr.NotifyPetDataUpdate(uin)
    end

    return success, errorMsg
end

---【新增】删除宠物
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean, string|nil
function PetMgr.DeletePet(uin, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家宠物数据不存在"
    end

    local success, errorMsg = petManager:DeletePet(slotIndex)

    if success then
        -- 【修复】不再发送专用的移除通知，而是发送全量更新通知，以避免客户端的竞态条件问题
        PetMgr.NotifyPetDataUpdate(uin)
    end

    return success, errorMsg
end

---【新增】切换宠物锁定状态
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean, string|nil, boolean|nil
function PetMgr.TogglePetLock(uin, slotIndex)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家宠物数据不存在", nil
    end

    local success, errorMsg, isLocked = petManager:TogglePetLock(slotIndex)

    if success then
        PetMgr.NotifyPetDataUpdate(uin, slotIndex)
    end

    return success, errorMsg, isLocked
end

---【新增】更新玩家所有已装备宠物的模型和动画
---@param player MPlayer 玩家对象
function PetMgr.UpdateAllEquippedPetModels(player)
    if not player or not player.uin then
        --gg.log("PetMgr.UpdateAllEquippedPetModels: 玩家对象无效")
        return
    end

    local uin = player.uin
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        --gg.log("PetMgr.UpdateAllEquippedPetModels: 找不到玩家宠物数据", uin)
        return
    end

    local player_actor = player.actor
    if not player_actor then
        --gg.log("PetMgr.UpdateAllEquippedPetModels: 找不到玩家Actor", uin)
        return
    end

    local activeSlots = petManager.activeCompanionSlots or {}
    local allEquipSlotIds = petManager.equipSlotIds or {}
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)

    -- 1. 先隐藏所有宠物节点
    for _, equipSlotId in ipairs(allEquipSlotIds) do
        local petNode = player_actor:FindFirstChild(equipSlotId)
        if petNode then
            petNode.Visible = false
            petNode.ModelId = ""
            local animatorNode = petNode:FindFirstChild("Animator")
            if animatorNode then
                animatorNode.ControllerAsset = ""
            end
        end
    end

    -- 2. 再根据当前激活的槽位，显示并更新正确的模型和动画
    for equipSlotId, companionSlotId in pairs(activeSlots) do
        if companionSlotId and companionSlotId > 0 then
            local petNode = player_actor:FindFirstChild(equipSlotId)
            if petNode then
                local companionInstance = petManager:GetPetBySlot(companionSlotId)
                if companionInstance then
                    local petConfigName = companionInstance:GetConfigName()
                    local petConfig = ConfigLoader.GetPet(petConfigName)
                    if petConfig and petConfig.modelResource and petConfig.modelResource ~= "" then
                        petNode.ModelId = petConfig.modelResource
                        petNode.Visible = true

                        local animatorNode = petNode:FindFirstChild("Animator")
                        if animatorNode then
                            animatorNode.ControllerAsset = petConfig.animationResource or ""
                        end
                        --gg.log("更新宠物模型和动画成功:", uin, equipSlotId)
                    else
                        petNode.Visible = false
                    end
                else
                     petNode.Visible = false
                end
            end
        end
    end
    --gg.log("玩家所有宠物模型更新完毕", uin)
end


---给玩家添加宠物
---@param player MPlayer 玩家对象
---@param petName string 宠物名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function PetMgr.AddPet(player, petName, slotIndex)
    if not player or not player.uin then
        --gg.log("PetMgr.AddPet: 玩家对象无效")
        return false, nil
    end

    local success, errorMsg, actualSlot = PetMgr.AddPetToSlot(player.uin, petName, slotIndex)
    if success then
        --gg.log("PetMgr.AddPet: 成功给玩家", player.uin, "添加宠物", petName, "槽位", actualSlot)
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, actualSlot)
    else
        --gg.log("PetMgr.AddPet: 给玩家", player.uin, "添加宠物失败", petName, "错误", errorMsg)
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
        --gg.log("PetMgr.AddPetByUin: 玩家不存在", uin)
        return false, nil
    end

    return PetMgr.AddPet(player, petName, slotIndex)
end

---通知客户端宠物数据更新
---@param uin number 玩家ID
---@param slotIndex number|nil 具体槽位，nil表示全部更新
function PetMgr.NotifyPetDataUpdate(uin, slotIndex)
    local PetEventManager = require(ServerStorage.MSystems.Pet.EventManager.PetEventManager) ---@type PetEventManager

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
            PetEventManager.NotifyPetListUpdate(uin, result)
        end
    end
end

---强制同步玩家宠物数据到客户端
---@param uin number 玩家UIN
function PetMgr.ForceSyncToClient(uin)
    local result = PetMgr.GetPlayerPetList(uin)
    if result then
        local PetEventManager = require(ServerStorage.MSystems.Pet.EventManager.PetEventManager) ---@type PetEventManager
        
        PetEventManager.NotifyPetListUpdate(uin, result)
    else
        --gg.log("PetMgr.ForceSyncToClient: 同步失败", uin, errorMsg)
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
            --gg.log("PetMgr.ForceSavePlayerData: 强制保存宠物数据", uin)
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

--- 检查玩家是否有可用的宠物槽位
---@param uin number 玩家ID
---@return boolean 是否有可用槽位
function PetMgr.HasAvailableSlot(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false
    end
    
    -- 检查是否有空槽位
    local petCount = petManager:GetPetCount()
    local maxSlots = petManager.maxSlots -- 默认最大槽位数
    
    return petCount < maxSlots
end

--- 获取当前激活宠物的物品加成
---@param uin number 玩家ID
---@return table<string, number> 激活宠物的物品加成
function PetMgr.GetActiveItemBonuses(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return {}
    end

    local bonuses = petManager:GetActiveItemBonuses()
    return bonuses
end

---【新增】设置玩家可携带栏位数量
---@param uin number 玩家ID
---@param count number 数量
---@return boolean
function PetMgr.SetUnlockedEquipSlots(uin, count)
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        petManager:SetUnlockedEquipSlots(count)
        --gg.log("通过 PetMgr 更新玩家", uin, "的可携带栏位数量为", count)
        return true
    else
        --gg.log("更新可携带栏位失败，找不到玩家", uin, "的宠物管理器")
        return false
    end
end

---【新增】设置玩家宠物背包容量
---@param uin number 玩家ID
---@param capacity number 容量
---@return boolean
function PetMgr.SetPetBagCapacity(uin, capacity)
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        petManager:SetPetBagCapacity(capacity)
        --gg.log("通过 PetMgr 更新玩家", uin, "的背包容量为", capacity)
        return true
    else
        --gg.log("更新背包容量失败，找不到玩家", uin, "的宠物管理器")
        return false
    end
end

---【新增】增加玩家可携带栏位数量
---@param uin number 玩家ID
---@param count number 增加的数量
---@return boolean
function PetMgr.AddUnlockedEquipSlots(uin, count)
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        petManager:AddUnlockedEquipSlots(count)
        --gg.log("通过 PetMgr 为玩家", uin, "增加可携带栏位数量", count)
        return true
    else
        --gg.log("增加可携带栏位失败，找不到玩家", uin, "的宠物管理器")
        return false
    end
end

---【新增】减少玩家可携带栏位数量
---@param uin number 玩家ID
---@param count number 减少的数量
---@return boolean
function PetMgr.ReduceUnlockedEquipSlots(uin, count)
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        petManager:ReduceUnlockedEquipSlots(count)
        --gg.log("通过 PetMgr 为玩家", uin, "减少可携带栏位数量", count)
        return true
    else
        --gg.log("减少可携带栏位失败，找不到玩家", uin, "的宠物管理器")
        return false
    end
end

---【新增】增加玩家宠物背包容量
---@param uin number 玩家ID
---@param capacity number 增加的容量
---@return boolean
function PetMgr.AddPetBagCapacity(uin, capacity)
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        petManager:AddPetBagCapacity(capacity)
        --gg.log("通过 PetMgr 为玩家", uin, "增加背包容量", capacity)
        return true
    else
        --gg.log("增加背包容量失败，找不到玩家", uin, "的宠物管理器")
        return false
    end
end

---【新增】减少玩家宠物背包容量
---@param uin number 玩家ID
---@param capacity number 减少的容量
---@return boolean
function PetMgr.ReducePetBagCapacity(uin, capacity)
    local petManager = PetMgr.GetPlayerPet(uin)
    if petManager then
        petManager:ReducePetBagCapacity(capacity)
        --gg.log("通过 PetMgr 为玩家", uin, "减少背包容量", capacity)
        return true
    else
        --gg.log("减少背包容量失败，找不到玩家", uin, "的宠物管理器")
        return false
    end
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
    -- --gg.log("PetMgr.SaveAllPlayerData: 批量保存所有玩家宠物数据") -- 日志已移至定时器启动时
end

-- =================================
-- 自动装备最优宠物相关方法
-- =================================

---自动装备效果数值最高的宠物
---@param uin number 玩家ID
---@param equipSlotId string 装备栏ID
---@param excludeEquipped boolean|nil 是否排除已装备的宠物
---@return boolean, string|nil, number|nil
function PetMgr.AutoEquipBestEffectPet(uin, equipSlotId, excludeEquipped)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return false, "玩家宠物数据不存在", nil
    end
    
    local success, errorMsg, slotIndex = petManager:AutoEquipBestPet(equipSlotId, excludeEquipped)
    
    if success then
        -- 更新模型显示和通知客户端
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            PetMgr.UpdateAllEquippedPetModels(player)
        end
        PetMgr.NotifyPetDataUpdate(uin)
    end
    
    return success, errorMsg, slotIndex
end

---自动装备所有装备栏的最优宠物
---@param uin number 玩家ID
---@param excludeEquipped boolean|nil 是否排除已装备的宠物
---@return table 装备结果
function PetMgr.AutoEquipAllBestEffectPets(uin, excludeEquipped)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return { error = "玩家宠物数据不存在" }
    end
    
    local results = petManager:AutoEquipAllBestPets(excludeEquipped)
    
    -- 检查是否有成功的装备
    local hasSuccess = false
    for _, result in pairs(results) do
        if result.success then
            hasSuccess = true
            break
        end
    end
    
    if hasSuccess then
        -- 更新模型显示和通知客户端
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            PetMgr.UpdateAllEquippedPetModels(player)
        end
        PetMgr.NotifyPetDataUpdate(uin)
    end
    
    return results
end

---获取玩家宠物效果数值排行
---@param uin number 玩家ID
---@param limit number|nil 返回数量限制
---@return table|nil 排行列表
function PetMgr.GetPlayerPetEffectRanking(uin, limit)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        return nil
    end
    
    return petManager:GetPetEffectRanking(limit)
end

---【新增】清空玩家所有宠物数据
---@param uin number 玩家ID
---@return boolean 是否成功
function PetMgr.ClearPlayerPetData(uin)
    gg.log("开始清空玩家宠物数据:", uin)
    
    -- 清理内存中的宠物管理器
    local petManager = PetMgr.server_player_pets[uin]
    if petManager then
        -- 先清理玩家身上的宠物模型
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player and player.actor then
            local allEquipSlotIds = petManager.equipSlotIds or {}
            for _, equipSlotId in ipairs(allEquipSlotIds) do
                local petNode = player.actor:FindFirstChild(equipSlotId)
                if petNode then
                    petNode.Visible = false
                    petNode.ModelId = ""
                    local animatorNode = petNode:FindFirstChild("Animator")
                    if animatorNode then
                        animatorNode.ControllerAsset = ""
                    end
                end
            end
        end
        
        -- 清理内存缓存
        PetMgr.server_player_pets[uin] = nil
    end
    
    -- 清空云端数据
    local success = CloudPetDataAccessor:ClearPlayerPetData(uin)
    
    if success then
        gg.log("成功清空玩家宠物数据:", uin)
    else
        gg.log("清空玩家宠物数据失败:", uin)
    end
    
    return success
end

-- 定时器回调函数
local function SaveAllPlayerPets_()
    PetMgr.SaveAllPlayerData()
end

-- 创建并启动定时器
local saveTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
saveTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
saveTimer.Name = 'PET_SAVE_ALL'
saveTimer.Delay = PetMgr.SAVE_INTERVAL
saveTimer.Loop = true
saveTimer.Interval = PetMgr.SAVE_INTERVAL
saveTimer.Callback = SaveAllPlayerPets_
saveTimer:Start()
--gg.log("宠物数据定时保存任务已启动，间隔:", PetMgr.SAVE_INTERVAL, "秒")


return PetMgr
