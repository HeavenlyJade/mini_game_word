-- MClearDataCom.lua
-- 清空玩家数据指令处理器
-- 支持清空背包、成就、变量、基础数据、技能、宠物、伙伴等所有玩家数据

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local MCloudDataMgr = require(ServerStorage.CloundDataMgr.MCloudDataMgr) ---@type MCloudDataMgr

---@class ClearDataCommand
local ClearDataCommand = {}

-- 默认清空范围配置
local DEFAULT_CLEAR_RANGE = {
    ["背包"] = true,
    ["成就"] = true,
    ["核心数据"] = true, -- 将“变量”和“基础数据”合并
    ["技能"] = true,
    ["宠物"] = true,
    ["伙伴"] = true
}

--- 清空背包数据
---@param player MPlayer 目标玩家
---@return boolean 是否成功
local function clearBagData(player)
    if not MServerDataManager.BagMgr then
        gg.log("背包管理器未初始化")
        return false
    end
    if not MServerDataManager.BagMgr.ClearPlayerBag then
        gg.log("错误: BagMgr 中缺少 ClearPlayerBag 函数")
        return false
    end
    MServerDataManager.BagMgr.ClearPlayerBag(player.uin)
    gg.log("已清空玩家背包数据:", player.name)
    return true
end

--- 清空成就数据
---@param player MPlayer 目标玩家
---@return boolean 是否成功
local function clearAchievementData(player)
    if not MServerDataManager.AchievementMgr then
        gg.log("成就管理器未初始化")
        return false
    end
    local AchievementCloudDataMgr = require(ServerStorage.MSystems.Achievement.AchievementCloudDataMgr)
    if AchievementCloudDataMgr.ClearPlayerAchievements then
        AchievementCloudDataMgr.ClearPlayerAchievements(player.uin)
    else 
        gg.log("警告: AchievementCloudDataMgr 中缺少 ClearPlayerAchievements 函数")
    end
    MServerDataManager.AchievementMgr.server_player_achievement_data[player.uin] = nil
    gg.log("已清空玩家成就数据:", player.name)
    return true
end

--- 清空核心数据 (基础数据 + 变量)
---@param player MPlayer 目标玩家
---@return boolean 是否成功
local function clearCoreData(player)
    if MCloudDataMgr.ClearCorePlayerData then
        return MCloudDataMgr.ClearCorePlayerData(player.uin)
    else
        gg.log("错误: MCloudDataMgr 中缺少 ClearCorePlayerData 函数")
        return false
    end
end

--- 清空技能数据
---@param player MPlayer 目标玩家
---@return boolean 是否成功
local function clearSkillData(player)
    if player.skills then
        player.skills = {}
    end
    gg.log("已清空玩家技能数据:", player.name)
    return true
end

--- 清空宠物数据
---@param player MPlayer 目标玩家
---@return boolean 是否成功
local function clearPetData(player)
    if not MServerDataManager.PetMgr then
        gg.log("宠物管理器未初始化")
        return false
    end
    local CloudPetDataAccessor = require(ServerStorage.MSystems.Pet.CloudData.PetCloudDataMgr)
    if CloudPetDataAccessor.ClearPlayerPetData then
        CloudPetDataAccessor.ClearPlayerPetData(player.uin)
    else
        gg.log("警告: PetCloudDataMgr 中缺少 ClearPlayerPetData 函数")
    end
    MServerDataManager.PetMgr.server_player_pets[player.uin] = nil
    gg.log("已清空玩家宠物数据:", player.name)
    return true
end

--- 清空伙伴数据
---@param player MPlayer 目标玩家
---@return boolean 是否成功
local function clearPartnerData(player)
    if not MServerDataManager.PartnerMgr then
        gg.log("伙伴管理器未初始化")
        return false
    end
    local CloudPartnerDataAccessor = require(ServerStorage.MSystems.Pet.CloudData.PartnerCloudDataMgr)
    if CloudPartnerDataAccessor.ClearPlayerPartnerData then
        CloudPartnerDataAccessor.ClearPlayerPartnerData(player.uin)
    else
        gg.log("警告: PartnerCloudDataMgr 中缺少 ClearPlayerPartnerData 函数")
    end
    MServerDataManager.PartnerMgr.server_player_partners[player.uin] = nil
    gg.log("已清空玩家伙伴数据:", player.name)
    return true
end

--- 保存非核心数据
---@param player MPlayer 目标玩家
local function saveOtherData(player)
    -- 注意：核心数据（等级、经验、变量）已在 clearCoreData 中处理，此处无需重复保存
    if MCloudDataMgr.SaveSkillConfig then
        MCloudDataMgr.SaveSkillConfig(player) -- 保存技能数据
    end
    gg.log("已强制保存玩家清空后的非核心数据:", player.name)
end

--- 同步数据到客户端
---@param player MPlayer 目标玩家
local function syncDataToClient(player)
    if MServerDataManager.BagMgr and MServerDataManager.BagMgr.ForceSyncToClient then
        MServerDataManager.BagMgr.ForceSyncToClient(player.uin)
    end
    if MServerDataManager.PetMgr and MServerDataManager.PetMgr.ForceSyncToClient then
        MServerDataManager.PetMgr.ForceSyncToClient(player.uin)
    end
    if MServerDataManager.PartnerMgr and MServerDataManager.PartnerMgr.ForceSyncToClient then
        MServerDataManager.PartnerMgr.ForceSyncToClient(player.uin)
    end
    if player.syncSkillData then
        player:syncSkillData()
    end
    gg.log("已尝试同步玩家数据到客户端:", player.name)
end

--- 获取目标玩家
---@param params table 指令参数
---@param executor MPlayer 执行者
---@return MPlayer|nil 目标玩家
local function getTargetPlayer(params, executor)
    if params["玩家UID"] then
        local targetUin = tonumber(params["玩家UID"])
        if targetUin then return MServerDataManager.getPlayerByUin(targetUin) end
    end
    if params["玩家"] then
        return MServerDataManager.getLivingByName(params["玩家"])
    end
    return executor
end

--- 获取清空范围配置
---@param params table 指令参数
---@return table 清空范围配置
local function getClearRange(params)
    if params["清空范围"] and type(params["清空范围"]) == "table" then
        return params["清空范围"]
    end
    return DEFAULT_CLEAR_RANGE
end

--- 清空玩家数据主处理函数
---@param params table 指令参数
---@param executor MPlayer 执行者
---@return boolean, string 是否成功, 结果消息
function ClearDataCommand.main(params, executor)
    if not gg.opUin[executor.uin] then
        return false, "你没有执行此指令的权限"
    end
    if not params["确认"] or params["确认"] ~= true then
        return false, "危险操作！必须设置'确认'参数为true才能执行清空数据操作"
    end
    
    local targetPlayer = getTargetPlayer(params, executor)
    if not targetPlayer then
        return false, "找不到目标玩家"
    end
    
    local clearRange = getClearRange(params)
    gg.log("开始清空玩家数据:", targetPlayer.name, "执行者:", executor.name)
    
    local results = {}
    local hasError = false
    
    local clearActions = {
        ["背包"] = clearBagData,
        ["成就"] = clearAchievementData,
        ["核心数据"] = clearCoreData,
        ["技能"] = clearSkillData,
        ["宠物"] = clearPetData,
        ["伙伴"] = clearPartnerData,
    }
    
    -- 因为“基础数据”和“变量”现在由“核心数据”统一处理，所以需要对用户的输入进行适配
    if clearRange["基础数据"] or clearRange["变量"] then
        clearRange["核心数据"] = true
    end

    for key, action in pairs(clearActions) do
        if clearRange[key] then
            local success = action(targetPlayer)
            table.insert(results, success and ("✓ " .. key) or ("✗ " .. key))
            if not success then hasError = true end
        end
    end
    
    saveOtherData(targetPlayer)
    syncDataToClient(targetPlayer)
    
    local resultMsg = string.format("玩家 [%s] 数据清空%s\n清空结果: %s", targetPlayer.name, hasError and "部分完成" or "完成", table.concat(results, ", "))
    

    gg.log("玩家数据清空操作完成:", targetPlayer.name, "结果:", hasError and "部分成功" or "完全成功")
    
    return true, resultMsg
end

return ClearDataCommand
