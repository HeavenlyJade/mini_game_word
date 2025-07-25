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
    
    -- 设置激活宠物
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
end

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function PetEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        gg.log("宠物事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        gg.log("宠物事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

--- 验证宠物管理器
---@param uin number 玩家UIN
---@return Pet|nil 宠物管理器
function PetEventManager.ValidatePetManager(uin)
    local petManager = PetMgr.GetPlayerPet(uin)
    if not petManager then
        gg.log("宠物管理器不存在", uin)
        return nil
    end
    return petManager
end

--- 处理获取宠物列表请求
---@param evt table 事件数据
function PetEventManager.HandleGetPetList(evt)
    gg.log("获取宠物列表", evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end
    
    local result, errorMsg = PetMgr.GetPlayerPetList(player.uin)
    if result then
        PetEventManager.NotifyPetListUpdate(player.uin, result.petList)
    else
        gg.log("获取宠物列表失败", player.uin, errorMsg)
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
        gg.log("设置激活宠物成功", player.uin, "槽位", slotIndex)
    else
        gg.log("设置激活宠物失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
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
        gg.log("宠物升级缺少槽位参数", player.uin)
        return
    end
    
    local success, errorMsg, leveledUp = PetMgr.LevelUpPet(player.uin, slotIndex, targetLevel)
    
    if success then
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        gg.log("宠物升级成功", player.uin, "槽位", slotIndex, "是否升级", leveledUp)
    else
        gg.log("宠物升级失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
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
        gg.log("宠物获得经验缺少参数", player.uin, "槽位", slotIndex, "经验", expAmount)
        return
    end
    
    local success, errorMsg, leveledUp = PetMgr.AddPetExp(player.uin, slotIndex, expAmount)
    
    if success then
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        gg.log("宠物获得经验成功", player.uin, "槽位", slotIndex, "经验", expAmount, "是否升级", leveledUp)
    else
        gg.log("宠物获得经验失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理宠物升星请求
---@param evt table 事件数据 {slotIndex}
function PetEventManager.HandleUpgradePetStar(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.slotIndex
    
    if not slotIndex then
        gg.log("宠物升星缺少槽位参数", player.uin)
        return
    end
    
    local success, errorMsg = PetMgr.UpgradePetStar(player.uin, slotIndex)
    
    if success then
        -- 通知客户端更新（升星可能消耗了其他宠物，需要全量更新）
        PetMgr.NotifyPetDataUpdate(player.uin)
        gg.log("宠物升星成功", player.uin, "槽位", slotIndex)
    else
        gg.log("宠物升星失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
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
        gg.log("宠物学习技能缺少参数", player.uin, "槽位", slotIndex, "技能", skillId)
        return
    end
    
    local success, errorMsg = PetMgr.LearnPetSkill(player.uin, slotIndex, skillId)
    
    if success then
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        gg.log("宠物学习技能成功", player.uin, "槽位", slotIndex, "技能", skillId)
    else
        gg.log("宠物学习技能失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
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
        gg.log("喂养宠物缺少参数", player.uin, "槽位", slotIndex, "食物类型", foodType)
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
        gg.log("喂养宠物成功", player.uin, "槽位", slotIndex, "食物类型", foodType, "新心情", newMood)
    else
        gg.log("喂养宠物失败：宠物不存在", player.uin, "槽位", slotIndex)
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
        gg.log("重命名宠物缺少参数", player.uin, "槽位", slotIndex, "新名称", newName)
        return
    end
    
    local petInstance = PetMgr.GetPetInstance(player.uin, slotIndex)
    if petInstance then
        petInstance:SetCustomName(newName)
        
        -- 通知客户端更新
        PetMgr.NotifyPetDataUpdate(player.uin, slotIndex)
        gg.log("重命名宠物成功", player.uin, "槽位", slotIndex, "新名称", newName)
    else
        gg.log("重命名宠物失败：宠物不存在", player.uin, "槽位", slotIndex)
    end
end

--- 处理批量升级请求（新增功能）
---@param evt table 事件数据
function PetEventManager.HandleUpgradeAllPets(evt)
    local player = PetEventManager.ValidatePlayer(evt)
    if not player then return end
    
    local upgradedCount = PetMgr.UpgradeAllPossiblePets(player.uin)
    
    if upgradedCount > 0 then
        gg.log("批量升级宠物成功", player.uin, "升级次数", upgradedCount)
        -- 发送响应事件到客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = PetEventManager.RESPONSE.PET_BATCH_UPGRADE,
            success = true,
            upgradedCount = upgradedCount
        })
    else
        gg.log("批量升级宠物：没有可升级的宠物", player.uin)
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
        gg.log("宠物统计查询缺少参数", player.uin)
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
    
    gg.log("宠物统计查询", player.uin, petName, "最小星级", minStar, "数量", count)
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
    gg.network_channel:fireClient(uin, {
        cmd = PetEventManager.RESPONSE.ERROR,
        errorCode = errorCode,
        errorMsg = errorMsg
    })
end

return PetEventManager