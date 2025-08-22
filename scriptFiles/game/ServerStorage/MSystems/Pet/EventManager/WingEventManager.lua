-- WingEventManager.lua
-- 翅膀事件管理器
-- 负责处理所有翅膀相关的客户端请求和服务器响应

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local WingEventConfig = require(MainStorage.Code.Event.EventWing) ---@type WingEventConfig
local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class WingEventManager
local WingEventManager = {}

-- 将配置导入到当前模块
WingEventManager.REQUEST = WingEventConfig.REQUEST
WingEventManager.RESPONSE = WingEventConfig.RESPONSE
WingEventManager.NOTIFY = WingEventConfig.NOTIFY

--- 初始化翅膀事件管理器
function WingEventManager.Init()
    WingEventManager.RegisterEventHandlers()
end

--- 注册所有事件处理器
function WingEventManager.RegisterEventHandlers()
    -- 获取翅膀列表
    ServerEventManager.Subscribe(WingEventManager.REQUEST.GET_WING_LIST, function(evt) WingEventManager.HandleGetWingList(evt) end)

    -- 装备/卸下翅膀
    ServerEventManager.Subscribe(WingEventManager.REQUEST.EQUIP_WING, function(evt) WingEventManager.HandleEquipWing(evt) end)
    ServerEventManager.Subscribe(WingEventManager.REQUEST.UNEQUIP_WING, function(evt) WingEventManager.HandleUnequipWing(evt) end)

    -- 翅膀升级
    ServerEventManager.Subscribe(WingEventManager.REQUEST.LEVEL_UP_WING, function(evt) WingEventManager.HandleLevelUpWing(evt) end)

    -- 翅膀获得经验
    ServerEventManager.Subscribe(WingEventManager.REQUEST.ADD_WING_EXP, function(evt) WingEventManager.HandleAddWingExp(evt) end)

    -- 翅膀升星
    ServerEventManager.Subscribe(WingEventManager.REQUEST.UPGRADE_WING_STAR, function(evt) WingEventManager.HandleUpgradeWingStar(evt) end)

    -- 翅膀学习技能
    ServerEventManager.Subscribe(WingEventManager.REQUEST.LEARN_WING_SKILL, function(evt) WingEventManager.HandleLearnWingSkill(evt) end)

    -- 重命名翅膀
    ServerEventManager.Subscribe(WingEventManager.REQUEST.RENAME_WING, function(evt) WingEventManager.HandleRenameWing(evt) end)

    -- 一键升星
    ServerEventManager.Subscribe(WingEventManager.REQUEST.UPGRADE_ALL_WINGS, function(evt) WingEventManager.HandleUpgradeAllWings(evt) end)
end

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function WingEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        --gg.log("翅膀事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("翅膀事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

--- 处理获取翅膀列表请求
---@param evt table 事件数据
function WingEventManager.HandleGetWingList(evt)
    --gg.log("获取翅膀列表", evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local result, errorMsg = WingMgr.GetPlayerWingList(player.uin)
    if result then
        WingEventManager.NotifyWingListUpdate(player.uin, result)
    else
        --gg.log("获取翅膀列表失败", player.uin, errorMsg)
    end
end

--- 处理装备翅膀请求
---@param evt table 事件数据 {args = {companionSlotId, equipSlotId}}
function WingEventManager.HandleEquipWing(evt)
    --gg.log("处理装备翅膀请求", evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local companionSlotId = evt.args.companionSlotId
    local equipSlotId = evt.args.equipSlotId

    local success, errorMsg = WingMgr.EquipWing(player.uin, companionSlotId, equipSlotId)

    if success then
        local updatedData = WingMgr.GetPlayerWingList(player.uin)
        if updatedData then
            WingEventManager.NotifyWingListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("装备翅膀失败", player.uin, errorMsg)
        WingEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

--- 处理卸下翅膀请求
---@param evt table 事件数据 {args = {equipSlotId}}
function WingEventManager.HandleUnequipWing(evt)
    --gg.log("处理卸下翅膀请求", evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local equipSlotId = evt.args.equipSlotId

    local success, errorMsg = WingMgr.UnequipWing(player.uin, equipSlotId)

    if success then
        local updatedData = WingMgr.GetPlayerWingList(player.uin)
        if updatedData then
            WingEventManager.NotifyWingListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("卸下翅膀失败", player.uin, errorMsg)
        WingEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

--- 处理翅膀升级请求
---@param evt table 事件数据 {slotIndex, targetLevel}
function WingEventManager.HandleLevelUpWing(evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex
    local targetLevel = evt.args.targetLevel

    if not slotIndex then
        --gg.log("翅膀升级缺少槽位参数", player.uin)
        return
    end

    local success, errorMsg, leveledUp = WingMgr.LevelUpWing(player.uin, slotIndex, targetLevel)

    if success then
        -- 操作成功后，获取最新的完整翅膀列表数据并通知客户端
        local updatedData, getError = WingMgr.GetPlayerWingList(player.uin)
        if updatedData then
            WingEventManager.NotifyWingListUpdate(player.uin, updatedData)
        end
        --gg.log("翅膀升级成功", player.uin, "槽位", slotIndex, "是否升级", leveledUp)
    else
        --gg.log("翅膀升级失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理翅膀获得经验请求
---@param evt table 事件数据 {slotIndex, expAmount}
function WingEventManager.HandleAddWingExp(evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex
    local expAmount = evt.args.expAmount

    if not slotIndex or not expAmount then
        --gg.log("翅膀获得经验缺少参数", player.uin, "槽位", slotIndex, "经验", expAmount)
        return
    end

    local success, errorMsg, leveledUp = WingMgr.AddWingExp(player.uin, slotIndex, expAmount)

    if success then
        -- 操作成功后，获取最新的完整翅膀列表数据并通知客户端
        local updatedData, getError = WingMgr.GetPlayerWingList(player.uin)
        if updatedData then
            WingEventManager.NotifyWingListUpdate(player.uin, updatedData)
        end
        --gg.log("翅膀获得经验成功", player.uin, "槽位", slotIndex, "经验", expAmount, "是否升级", leveledUp)
    else
        --gg.log("翅膀获得经验失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理翅膀升星请求
---@param evt table 事件数据 {slotIndex}
function WingEventManager.HandleUpgradeWingStar(evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex

    if not slotIndex then
        --gg.log("翅膀升星缺少槽位参数", player.uin)
        return
    end

    local success, errorMsg = WingMgr.UpgradeWingStar(player.uin, slotIndex)

    if success then
        -- 操作成功后，获取最新的完整翅膀列表数据并通知客户端
        local updatedData, getError = WingMgr.GetPlayerWingList(player.uin)
        if updatedData then
            WingEventManager.NotifyWingListUpdate(player.uin, updatedData)
        end
        --gg.log("翅膀升星成功", player.uin, "槽位", slotIndex)
    else
        WingEventManager.NotifyError(player.uin, -1, errorMsg)
        --gg.log("翅膀升星失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理翅膀学习技能请求
---@param evt table 事件数据 {slotIndex, skillId}
function WingEventManager.HandleLearnWingSkill(evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex
    local skillId = evt.args.skillId

    if not slotIndex or not skillId then
        --gg.log("翅膀学习技能缺少参数", player.uin, "槽位", slotIndex, "技能", skillId)
        return
    end

    local success, errorMsg = WingMgr.LearnWingSkill(player.uin, slotIndex, skillId)

    if success then
        -- 操作成功后，获取最新的完整翅膀列表数据并通知客户端
        local updatedData, getError = WingMgr.GetPlayerWingList(player.uin)
        if updatedData then
            WingEventManager.NotifyWingListUpdate(player.uin, updatedData)
        end
        --gg.log("翅膀学习技能成功", player.uin, "槽位", slotIndex, "技能", skillId)
    else
        --gg.log("翅膀学习技能失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理重命名翅膀请求
---@param evt table 事件数据 {slotIndex, newName}
function WingEventManager.HandleRenameWing(evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex
    local newName = evt.args.newName

    if not slotIndex or not newName then
        --gg.log("重命名翅膀缺少参数", player.uin, "槽位", slotIndex, "新名称", newName)
        return
    end

    local wingInstance = WingMgr.GetWingInstance(player.uin, slotIndex)
    if wingInstance then
        wingInstance:SetCustomName(newName)
        -- 操作成功后，获取最新的完整翅膀列表数据并通知客户端
        local updatedData, getError = WingMgr.GetPlayerWingList(player.uin)
        if updatedData then
            WingEventManager.NotifyWingListUpdate(player.uin, updatedData)
        end
        --gg.log("重命名翅膀成功", player.uin, "槽位", slotIndex, "新名称", newName)
    else
        --gg.log("重命名翅膀失败：翅膀不存在", player.uin, "槽位", slotIndex)
    end
end

--- 处理一键升星请求
---@param evt table 事件数据
function WingEventManager.HandleUpgradeAllWings(evt)
    local player = WingEventManager.ValidatePlayer(evt)
    if not player then return end

    local upgradedCount = WingMgr.UpgradeAllPossibleWings(player.uin)

    if upgradedCount > 0 then
        --gg.log("一键升星成功", player.uin, "总共升级次数", upgradedCount)
        -- 发送响应事件到客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = WingEventManager.RESPONSE.WING_BATCH_UPGRADE,
            success = true,
            upgradedCount = upgradedCount
        })
    else
        --gg.log("一键升星：没有可升星的翅膀", player.uin)
        gg.network_channel:fireClient(player.uin, {
            cmd = WingEventManager.RESPONSE.WING_BATCH_UPGRADE,
            success = false,
            errorMsg = "没有可升星的翅膀"
        })
    end
end

--- 通知客户端翅膀列表更新
---@param uin number 玩家ID
---@param wingData table 完整的翅膀数据
function WingEventManager.NotifyWingListUpdate(uin, wingData)
    -- --gg.log("通知客户端翅膀列表更新", uin, wingData)
    gg.network_channel:fireClient(uin, {
        cmd = WingEventManager.NOTIFY.WING_LIST_UPDATE,
        companionList = wingData.companionList,
        activeSlots = wingData.activeSlots,
        equipSlotIds = wingData.equipSlotIds,
        companionCount = wingData.companionCount or 0, -- 【新增】翅膀数量
        bagCapacity = wingData.maxSlots or 30,        -- 【新增】背包容量
        unlockedEquipSlots = wingData.unlockedEquipSlots or 1, -- 【新增】已解锁的装备栏位数
        maxEquipSlots = wingData.maxEquipSlots or 1,           -- 【新增】系统最大装备栏位数
        companionType = wingData.companionType or "翅膀"        -- 【新增】翅膀类型标识
    })
end

--- 通知客户端单个翅膀更新
---@param uin number 玩家ID
---@param wingInfo table 翅膀信息
function WingEventManager.NotifyWingUpdate(uin, wingInfo)
    gg.network_channel:fireClient(uin, {
        cmd = WingEventManager.NOTIFY.WING_UPDATE,
        wingInfo = wingInfo
    })
end

--- 通知客户端获得翅膀
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param wingInfo table 翅膀信息
function WingEventManager.NotifyWingObtained(uin, slotIndex, wingInfo)
    gg.network_channel:fireClient(uin, {
        cmd = WingEventManager.NOTIFY.WING_OBTAINED,
        slotIndex = slotIndex,
        wingInfo = wingInfo
    })
end

--- 通知客户端翅膀移除
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
function WingEventManager.NotifyWingRemoved(uin, slotIndex)
    gg.network_channel:fireClient(uin, {
        cmd = WingEventManager.NOTIFY.WING_REMOVED,
        slotIndex = slotIndex
    })
end

--- 通知客户端翅膀升星成功
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param newStarLevel number 新星级
---@param consumedWings table 消耗的翅膀信息
function WingEventManager.NotifyWingStarUpgraded(uin, slotIndex, newStarLevel, consumedWings)
    gg.network_channel:fireClient(uin, {
        cmd = WingEventManager.RESPONSE.WING_STAR_UPGRADED,
        slotIndex = slotIndex,
        newStarLevel = newStarLevel,
        consumedWings = consumedWings or {}
    })
end

--- 通知客户端错误信息
---@param uin number 玩家ID
---@param errorCode number 错误码
---@param errorMsg string 错误信息
function WingEventManager.NotifyError(uin, errorCode, errorMsg)
    local player = MServerDataManager.getPlayerByUin(uin)
    if player then
        player:SendHoverText(errorMsg)
    end
end

return WingEventManager 