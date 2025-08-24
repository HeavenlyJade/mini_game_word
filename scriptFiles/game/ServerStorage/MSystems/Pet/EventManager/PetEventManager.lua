-- PetEventManager.lua
-- 宠物事件管理器 - 重构版本
-- 负责处理所有宠物相关的客户端请求和服务器响应
-- 适配新的Pet管理器架构

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local PetEventConfig = require(MainStorage.Code.Event.EventPet) ---@type PetEventConfig
local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr

local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class PetEventManager
local PetEventManager = {}

-- 将配置导入到当前模块
PetEventManager.REQUEST = PetEventConfig.REQUEST
PetEventManager.RESPONSE = PetEventConfig.RESPONSE
PetEventManager.NOTIFY = PetEventConfig.NOTIFY

--- 初始化宠物事件管理器
function PetEventManager.Init()
    PetEventManager.RegisterEventHandlers()
end

--- 注册所有事件处理器
function PetEventManager.RegisterEventHandlers()
    -- 获取宠物列表
    ServerEventManager.Subscribe(PetEventManager.REQUEST.GET_PET_LIST, function(evt) PetEventManager.HandleGetPetList(evt) end)

    -- 【新增】装备/卸下宠物
    ServerEventManager.Subscribe(PetEventConfig.REQUEST.EQUIP_PET, function(evt) PetEventManager.HandleEquipPet(evt) end)
    ServerEventManager.Subscribe(PetEventConfig.REQUEST.UNEQUIP_PET, function(evt) PetEventManager.HandleUnequipPet(evt) end)

    -- 设置激活宠物 (保留旧接口的兼容性或用于特殊逻辑)
    ServerEventManager.Subscribe(PetEventManager.REQUEST.SET_ACTIVE_PET, function(evt) PetEventManager.HandleSetActivePet(evt) end)

    -- 宠物升级
    ServerEventManager.Subscribe(PetEventManager.REQUEST.LEVEL_UP_PET, function(evt) PetEventManager.HandleLevelUpPet(evt) end)

    -- 宠物获得经验
    ServerEventManager.Subscribe(PetEventManager.REQUEST.ADD_PET_EXP, function(evt) PetEventManager.HandleAddPetExp(evt) end)

    -- 宠物升星
    ServerEventManager.Subscribe(PetEventManager.REQUEST.UPGRADE_PET_STAR, function(evt) PetEventManager.HandleUpgradePetStar(evt) end)

    -- 宠物学习技能
    ServerEventManager.Subscribe(PetEventManager.REQUEST.LEARN_PET_SKILL, function(evt) PetEventManager.HandleLearnPetSkill(evt) end)

    -- 喂养宠物
    ServerEventManager.Subscribe(PetEventManager.REQUEST.FEED_PET, function(evt) PetEventManager.HandleFeedPet(evt) end)

    -- 重命名宠物
    ServerEventManager.Subscribe(PetEventManager.REQUEST.RENAME_PET, function(evt) PetEventManager.HandleRenamePet(evt) end)

    -- 【新增】删除/锁定宠物
    ServerEventManager.Subscribe(PetEventConfig.REQUEST.DELETE_PET, function(evt) PetEventManager.HandleDeletePet(evt) end)
    ServerEventManager.Subscribe(PetEventConfig.REQUEST.TOGGLE_PET_LOCK, function(evt) PetEventManager.HandleTogglePetLock(evt) end)
    -- 【新增】一键升星
    ServerEventManager.Subscribe(PetEventConfig.REQUEST.UPGRADE_ALL_PETS, function(evt) PetEventManager.HandleUpgradeAllPets(evt) end)
    
    -- 【新增】自动装备最优宠物
    ServerEventManager.Subscribe(PetEventConfig.REQUEST.AUTO_EQUIP_BEST_PET, function(evt) PetEventManager.HandleAutoEquipBestPet(evt) end)
    ServerEventManager.Subscribe(PetEventConfig.REQUEST.AUTO_EQUIP_ALL_BEST_PETS, function(evt) PetEventManager.HandleAutoEquipAllBestPets(evt) end)
    ServerEventManager.Subscribe(PetEventConfig.REQUEST.GET_PET_EFFECT_RANKING, function(evt) PetEventManager.HandleGetPetEffectRanking(evt) end)
end

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function PetEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        --gg.log("宠物事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("宠物事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

--- 【新增】处理装备宠物请求
---@param evt table 事件数据 { companionSlotId: number, equipSlotId: string }
function PetEventManager.HandleEquipPet(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local companionSlotId = args.companionSlotId
    local equipSlotId = args.equipSlotId

    if not companionSlotId or not equipSlotId then
        --gg.log("装备宠物缺少参数", player.uin)
        PetEventManager.NotifyError(player.uin, -1, "装备宠物缺少参数")
        return
    end

    local success, errorMsg = PetMgr.EquipPet(player.uin, companionSlotId, equipSlotId)

    if success then
        --gg.log("装备宠物成功", player.uin, "宠物槽位", companionSlotId, "装备栏", equipSlotId)
        -- 成功后，管理器内部会自动通知客户端更新
    else
        --gg.log("装备宠物失败", player.uin, "错误", errorMsg)
        PetEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

--- 【新增】处理卸下宠物请求
---@param evt table 事件数据 { equipSlotId: string }
function PetEventManager.HandleUnequipPet(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local equipSlotId = args.equipSlotId

    if not equipSlotId then
        --gg.log("卸下宠物缺少参数", player.uin)
        PetEventManager.NotifyError(player.uin, -1, "卸下宠物缺少参数")
        return
    end

    local success, errorMsg = PetMgr.UnequipPet(player.uin, equipSlotId)

    if success then
        --gg.log("卸下宠物成功", player.uin, "装备栏", equipSlotId)
        -- 成功后，管理器内部会自动通知客户端更新
    else
        --gg.log("卸下宠物失败", player.uin, "错误", errorMsg)
        PetEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end


--- 【新增】处理删除宠物请求
---@param evt table 事件数据 { slotIndex: number }
function PetEventManager.HandleDeletePet(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local slotIndex = args.slotIndex

    if not slotIndex then
        --gg.log("删除宠物缺少参数", player.uin)
        return
    end

    local success, errorMsg = PetMgr.DeletePet(player.uin, slotIndex)

    if success then
        --gg.log("删除宠物成功", player.uin, "槽位", slotIndex)
        -- 成功后，管理器内部会发送通知
    else
        --gg.log("删除宠物失败", player.uin, "错误", errorMsg)
        PetEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

--- 【新增】处理切换宠物锁定状态请求
---@param evt table 事件数据 { slotIndex: number }
function PetEventManager.HandleTogglePetLock(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local slotIndex = args.slotIndex

    if not slotIndex then
        --gg.log("切换宠物锁定状态缺少参数", player.uin)
        return
    end

    local success, errorMsg, isLocked = PetMgr.TogglePetLock(player.uin, slotIndex)

    if success then
        --gg.log("切换宠物锁定状态成功", player.uin, "槽位", slotIndex, "当前状态", isLocked)
        -- 成功后，管理器内部会发送通知
    else
        --gg.log("切换宠物锁定状态失败", player.uin, "错误", errorMsg)
        PetEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end


--- 【新增】处理一键升星请求
---@param evt table 事件数据
function PetEventManager.HandleUpgradeAllPets(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local upgradedCount = PetMgr.UpgradeAllPossiblePets(player.uin)

    if upgradedCount > 0 then
        --gg.log("一键升星成功", player.uin, "总共升级次数", upgradedCount)
        -- 成功的通知由PetMgr内部的NotifyPetDataUpdate发送，这里可以发送一个额外的成功提示
        -- PetEventManager.NotifySuccess(player.uin, "一键升星完成！")
    else
        --gg.log("一键升星：没有可升星的宠物", player.uin)
        -- PetEventManager.NotifyError(player.uin, 0, "没有可升星的宠物")
    end
end


--- 验证宠物管理器
---@param uin number 玩家UIN
---@return Pet|nil 宠物管理器
function PetEventManager.ValidatePetManager(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        --gg.log("宠物管理器不存在", uin)
        return nil
    end
    return petManager
end

--- 处理获取宠物列表请求
---@param evt table 事件数据
function PetEventManager.HandleGetPetList(evt)
    --gg.log("获取宠物列表", evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local result, errorMsg = PetMgr.GetPlayerPetList(player.uin)
    if result then
        PetEventManager.NotifyPetListUpdate(player.uin, result.petList)
    else
        --gg.log("获取宠物列表失败", player.uin, errorMsg)
    end
end

--- 处理设置激活宠物请求
---@param evt table 事件数据 {slotIndex}
function PetEventManager.HandleSetActivePet(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.slotIndex or 0
    local success, errorMsg = PetMgr.SetActivePet(player.uin, slotIndex)

    if success then
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin)
        --gg.log("设置激活宠物成功", player.uin, "槽位", slotIndex)
    else
        --gg.log("设置激活宠物失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理宠物升级请求
---@param evt table 事件数据 {slotIndex, targetLevel}
function PetEventManager.HandleLevelUpPet(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.slotIndex
    local targetLevel = evt.targetLevel

    if not slotIndex then
        --gg.log("宠物升级缺少槽位参数", player.uin)
        return
    end

    local success, errorMsg, leveledUp = PetMgr.LevelUpPet(player.uin, slotIndex, targetLevel)

    if success then
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        --gg.log("宠物升级成功", player.uin, "槽位", slotIndex, "是否升级", leveledUp)
    else
        --gg.log("宠物升级失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理宠物获得经验请求
---@param evt table 事件数据 {slotIndex, expAmount}
function PetEventManager.HandleAddPetExp(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.slotIndex
    local expAmount = evt.expAmount

    if not slotIndex or not expAmount then
        --gg.log("宠物获得经验缺少参数", player.uin, "槽位", slotIndex, "经验", expAmount)
        return
    end

    local success, errorMsg, leveledUp = PetMgr.AddPetExp(player.uin, slotIndex, expAmount)

    if success then
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        --gg.log("宠物获得经验成功", player.uin, "槽位", slotIndex, "经验", expAmount, "是否升级", leveledUp)
    else
        --gg.log("宠物获得经验失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理宠物升星请求
---@param evt table 事件数据 {slotIndex}
function PetEventManager.HandleUpgradePetStar(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local slotIndex = args.slotIndex

    if not slotIndex then
        --gg.log("宠物升星缺少槽位参数", player.uin)
        return
    end

    local success, errorMsg = PetMgr.UpgradePetStar(player.uin, slotIndex)
    -- gg.log("宠物升星", player.uin, "槽位", slotIndex, "成功", success, "错误", errorMsg)
    if success then
        -- 通知客户端更新（升星可能消耗了其他宠物，需要全量更新）
        PetMgr.NotifyPetDataUpdate(player.uin)
        --gg.log("宠物升星成功", player.uin, "槽位", slotIndex)
    else
        PetEventManager.NotifyError(player.uin, -1, errorMsg)
        --gg.log("宠物升星失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理宠物学习技能请求
---@param evt table 事件数据 {slotIndex, skillId}
function PetEventManager.HandleLearnPetSkill(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.slotIndex
    local skillId = evt.skillId

    if not slotIndex or not skillId then
        --gg.log("宠物学习技能缺少参数", player.uin, "槽位", slotIndex, "技能", skillId)
        return
    end

    local success, errorMsg = PetMgr.LearnPetSkill(player.uin, slotIndex, skillId)

    if success then
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        --gg.log("宠物学习技能成功", player.uin, "槽位", slotIndex, "技能", skillId)
    else
        --gg.log("宠物学习技能失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理喂养宠物请求
---@param evt table 事件数据 {slotIndex, foodType}
function PetEventManager.HandleFeedPet(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.slotIndex
    local foodType = evt.foodType

    if not slotIndex or not foodType then
        --gg.log("喂养宠物缺少参数", player.uin, "槽位", slotIndex, "食物类型", foodType)
        return
    end

    -- 获取宠物实例
    local petInstance = PetMgr.GetPetInstance(player.uin, slotIndex)
    if petInstance then
        -- 这里可以添加喂养逻辑，比如增加心情值
        local currentMood = petInstance:GetMood()
        local newMood = math.min(100, currentMood + 10) -- 简单的心情增加逻辑
        petInstance:SetMood(newMood)

        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        --gg.log("喂养宠物成功", player.uin, "槽位", slotIndex, "食物类型", foodType, "新心情", newMood)
    else
        --gg.log("喂养宠物失败：宠物不存在", player.uin, "槽位", slotIndex)
    end
end

--- 处理重命名宠物请求
---@param evt table 事件数据 {slotIndex, newName}
function PetEventManager.HandleRenamePet(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.slotIndex
    local newName = evt.newName

    if not slotIndex or not newName then
        --gg.log("重命名宠物缺少参数", player.uin, "槽位", slotIndex, "新名称", newName)
        return
    end

    local petInstance = PetMgr.GetPetInstance(player.uin, slotIndex)
    if petInstance then
        petInstance:SetCustomName(newName)

        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        --gg.log("重命名宠物成功", player.uin, "槽位", slotIndex, "新名称", newName)
    else
        --gg.log("重命名宠物失败：宠物不存在", player.uin, "槽位", slotIndex)
    end
end

--- 处理批量升级请求（新增功能）
---@param evt table 事件数据
function PetEventManager.HandleUpgradeAllPets(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local upgradedCount = PetMgr.UpgradeAllPossiblePets(player.uin)

    if upgradedCount > 0 then
        --gg.log("批量升级宠物成功", player.uin, "升级次数", upgradedCount)
        -- 发送响应事件到客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = PetEventManager.RESPONSE.PET_BATCH_UPGRADE,
            success = true,
            upgradedCount = upgradedCount
        })
    else
        --gg.log("批量升级宠物：没有可升级的宠物", player.uin)
        gg.network_channel:fireClient(player.uin, {
            cmd = PetEventManager.RESPONSE.PET_BATCH_UPGRADE,
            success = false,
            errorMsg = "没有可升级的宠物"
        })
    end
end

--- 处理宠物统计查询请求（新增功能）
---@param evt table 事件数据 {petName, minStar}
function PetEventManager.HandleGetPetStats(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local petName = evt.petName
    local minStar = evt.minStar

    if not petName then
        --gg.log("宠物统计查询缺少参数", player.uin)
        return
    end

    local count = PetMgr.GetPetCountByType(player.uin, petName, minStar)

    -- 发送统计结果
    gg.network_channel:fireClient(player.uin, {
        cmd = PetEventManager.RESPONSE.PET_STATS,
        petName = petName,
        minStar = minStar,
        count = count
    })

    --gg.log("宠物统计查询", player.uin, petName, "最小星级", minStar, "数量", count)
end

--- 通知客户端宠物列表更新
---@param uin number 玩家ID
---@param petList table 宠物列表
function PetEventManager.NotifyPetListUpdate(uin, petList)
    gg.network_channel:fireClient(uin, {
        cmd = PetEventManager.NOTIFY.PET_LIST_UPDATE,
        petList = petList
    })
end

--- 通知客户端单个宠物更新
---@param uin number 玩家ID
---@param petInfo table 宠物信息
function PetEventManager.NotifyPetUpdate(uin, petInfo)
    gg.network_channel:fireClient(uin, {
        cmd = PetEventManager.NOTIFY.PET_UPDATE,
        petInfo = petInfo
    })
end

--- 通知客户端获得宠物
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param petInfo table 宠物信息
function PetEventManager.NotifyPetObtained(uin, slotIndex, petInfo)
    gg.network_channel:fireClient(uin, {
        cmd = PetEventManager.NOTIFY.PET_OBTAINED,
        slotIndex = slotIndex,
        petInfo = petInfo
    })
end

--- 通知客户端宠物移除
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
function PetEventManager.NotifyPetRemoved(uin, slotIndex)
    gg.network_channel:fireClient(uin, {
        cmd = PetEventManager.NOTIFY.PET_REMOVED,
        slotIndex = slotIndex
    })
end

--- 通知客户端宠物升星成功（新增）
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param newStarLevel number 新星级
---@param consumedPets table 消耗的宠物信息
function PetEventManager.NotifyPetStarUpgraded(uin, slotIndex, newStarLevel, consumedPets)
    gg.network_channel:fireClient(uin, {
        cmd = PetEventManager.RESPONSE.PET_STAR_UPGRADED,
        slotIndex = slotIndex,
        newStarLevel = newStarLevel,
        consumedPets = consumedPets or {}
    })
end

--- 通知客户端错误信息
---@param uin number 玩家ID
---@param errorCode number 错误码
---@param errorMsg string 错误信息
function PetEventManager.NotifyError(uin, errorCode, errorMsg)
    local player = MServerDataManager.getPlayerByUin(uin)
    if player then
        player:SendHoverText(errorMsg)
    end
end

-- =================================
-- 自动装备最优宠物事件处理
-- =================================

---处理自动装备最优宠物请求
---@param evt table 事件数据 { equipSlotId: string, excludeEquipped: boolean }
function PetEventManager.HandleAutoEquipBestPet(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local equipSlotId = args.equipSlotId
    local excludeEquipped = args.excludeEquipped

    if not equipSlotId then
        PetEventManager.NotifyError(player.uin, -1, "自动装备宠物缺少装备栏参数")
        return
    end

    local success, errorMsg, slotIndex = PetMgr.AutoEquipBestEffectPet(player.uin, equipSlotId, excludeEquipped)

    if success then
        --gg.log("自动装备最优宠物成功", player.uin, "装备栏", equipSlotId, "宠物槽位", slotIndex)
    else
        --gg.log("自动装备最优宠物失败", player.uin, "错误", errorMsg)
        PetEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

---处理自动装备所有最优宠物请求
---@param evt table 事件数据 { excludeEquipped: boolean }
function PetEventManager.HandleAutoEquipAllBestPets(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local excludeEquipped = args.excludeEquipped

    local results = PetMgr.AutoEquipAllBestEffectPets(player.uin, excludeEquipped)

    -- 统计成功和失败的数量
    local successCount = 0
    local failureCount = 0
    
    for equipSlotId, result in pairs(results) do
        if result.success then
            successCount = successCount + 1
        else
            failureCount = failureCount + 1
        end
    end

    if successCount > 0 then
        --gg.log("自动装备所有最优宠物完成", player.uin, "成功", successCount, "失败", failureCount)
    else
        --gg.log("自动装备所有最优宠物失败", player.uin, "没有成功装备任何宠物")
        PetEventManager.NotifyError(player.uin, -1, "没有找到可装备的宠物")
    end
end

---处理获取宠物效果排行请求
---@param evt table 事件数据 { limit: number }
function PetEventManager.HandleGetPetEffectRanking(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local limit = args.limit

    local ranking = PetMgr.GetPlayerPetEffectRanking(player.uin, limit)

    if ranking then
        -- 发送排行数据给客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = PetEventManager.RESPONSE.PET_EFFECT_RANKING,
            ranking = ranking
        })
    else
        PetEventManager.NotifyError(player.uin, -1, "获取宠物效果排行失败")
    end
end

return PetEventManager
