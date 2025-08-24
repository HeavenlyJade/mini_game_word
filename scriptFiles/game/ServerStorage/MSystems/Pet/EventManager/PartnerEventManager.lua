-- PartnerEventManager.lua
-- 伙伴事件管理器
-- 负责处理所有伙伴相关的客户端请求和服务器响应

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local PartnerEventConfig = require(MainStorage.Code.Event.EventPartner) ---@type PartnerEventConfig
local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class PartnerEventManager
local PartnerEventManager = {}

-- 将配置导入到当前模块
PartnerEventManager.REQUEST = PartnerEventConfig.REQUEST
PartnerEventManager.RESPONSE = PartnerEventConfig.RESPONSE
PartnerEventManager.NOTIFY = PartnerEventConfig.NOTIFY

--- 初始化伙伴事件管理器
function PartnerEventManager.Init()
    PartnerEventManager.RegisterEventHandlers()
end

--- 注册所有事件处理器
function PartnerEventManager.RegisterEventHandlers()
    -- 获取伙伴列表
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.GET_PARTNER_LIST, function(evt) PartnerEventManager.HandleGetPartnerList(evt) end)

    -- 【重构】装备/卸下伙伴
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.EQUIP_PARTNER, function(evt) PartnerEventManager.HandleEquipPartner(evt) end)
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.UNEQUIP_PARTNER, function(evt) PartnerEventManager.HandleUnequipPartner(evt) end)


    -- 伙伴升级
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.LEVEL_UP_PARTNER, function(evt) PartnerEventManager.HandleLevelUpPartner(evt) end)

    -- 伙伴获得经验
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.ADD_PARTNER_EXP, function(evt) PartnerEventManager.HandleAddPartnerExp(evt) end)

    -- 伙伴升星
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.UPGRADE_PARTNER_STAR, function(evt) PartnerEventManager.HandleUpgradePartnerStar(evt) end)

    -- 伙伴学习技能
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.LEARN_PARTNER_SKILL, function(evt) PartnerEventManager.HandleLearnPartnerSkill(evt) end)

    -- 重命名伙伴
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.RENAME_PARTNER, function(evt) PartnerEventManager.HandleRenamePartner(evt) end)
    
    -- 【新增】一键升星
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.UPGRADE_ALL_PARTNERS, function(evt) PartnerEventManager.HandleUpgradeAllPartners(evt) end)
    
    -- 【新增】删除/锁定伙伴
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.DELETE_PARTNER, function(evt) PartnerEventManager.HandleDeletePartner(evt) end)
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.TOGGLE_PARTNER_LOCK, function(evt) PartnerEventManager.HandleTogglePartnerLock(evt) end)
    
    -- 【新增】自动装备最优伙伴
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.AUTO_EQUIP_BEST_PARTNER, function(evt) PartnerEventManager.HandleAutoEquipBestPartner(evt) end)
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.AUTO_EQUIP_ALL_BEST_PARTNERS, function(evt) PartnerEventManager.HandleAutoEquipAllBestPartners(evt) end)
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.GET_PARTNER_EFFECT_RANKING, function(evt) PartnerEventManager.HandleGetPartnerEffectRanking(evt) end)
end

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function PartnerEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        --gg.log("伙伴事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("伙伴事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

--- 处理获取伙伴列表请求
---@param evt table 事件数据
function PartnerEventManager.HandleGetPartnerList(evt)
    --gg.log("获取伙伴列表", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local result = PartnerMgr.GetPlayerPartnerList(player.uin)
    if result then
        PartnerEventManager.NotifyPartnerListUpdate(player.uin, result)
    else
        --gg.log("获取伙伴列表失败", player.uin, errorMsg)
    end
end

--- 【重构】处理装备伙伴请求
---@param evt table 事件数据 {args = {companionSlotId, equipSlotId}}
function PartnerEventManager.HandleEquipPartner(evt)
    --gg.log("处理装备伙伴请求", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local companionSlotId = evt.args.companionSlotId
    local equipSlotId = evt.args.equipSlotId

    local success, errorMsg = PartnerMgr.EquipPartner(player.uin, companionSlotId, equipSlotId)

    if success then
        local updatedData = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("装备伙伴失败", player.uin, errorMsg)
        PartnerEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

--- 【新增】处理卸下伙伴请求
---@param evt table 事件数据 {args = {equipSlotId}}
function PartnerEventManager.HandleUnequipPartner(evt)
    --gg.log("处理卸下伙伴请求", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local equipSlotId = evt.args.equipSlotId

    local success, errorMsg = PartnerMgr.UnequipPartner(player.uin, equipSlotId)

    if success then
        local updatedData = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("卸下伙伴失败", player.uin, errorMsg)
        PartnerEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end


--- 【废弃】处理设置激活伙伴请求
function PartnerEventManager.HandleSetActivePartner(evt)
    --gg.log("警告: 收到已废弃的SetActivePartner请求", evt)
end

--- 处理伙伴升级请求
---@param evt table 事件数据 {slotIndex, targetLevel}
function PartnerEventManager.HandleLevelUpPartner(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex      -- 修改：从args中获取
    local targetLevel = evt.args.targetLevel  -- 修改：从args中获取

    if not slotIndex then
        --gg.log("伙伴升级缺少槽位参数", player.uin)
        return
    end

    local success, errorMsg, leveledUp = PartnerMgr.LevelUpPartner(player.uin, slotIndex, targetLevel)

    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        --gg.log("伙伴升级成功", player.uin, "槽位", slotIndex, "是否升级", leveledUp)
    else
        --gg.log("伙伴升级失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理伙伴获得经验请求
---@param evt table 事件数据 {slotIndex, expAmount}
function PartnerEventManager.HandleAddPartnerExp(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex
    local expAmount = evt.args.expAmount

    if not slotIndex or not expAmount then
        --gg.log("伙伴获得经验缺少参数", player.uin, "槽位", slotIndex, "经验", expAmount)
        return
    end

    local success, errorMsg, leveledUp = PartnerMgr.AddPartnerExp(player.uin, slotIndex, expAmount)

    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        --gg.log("伙伴获得经验成功", player.uin, "槽位", slotIndex, "经验", expAmount, "是否升级", leveledUp)
    else
        --gg.log("伙伴获得经验失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理伙伴升星请求
---@param evt table 事件数据 {slotIndex}
function PartnerEventManager.HandleUpgradePartnerStar(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex  -- 确认：使用 slotIndex

    if not slotIndex then
        --gg.log("伙伴升星缺少槽位参数", player.uin)
        return
    end

    local success, errorMsg = PartnerMgr.UpgradePartnerStar(player.uin, slotIndex)

    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        --gg.log("伙伴升星成功", player.uin, "槽位", slotIndex)
    else
        PartnerEventManager.NotifyError(player.uin, -1, errorMsg)   
        --gg.log("伙伴升星失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理伙伴学习技能请求
---@param evt table 事件数据 {slotIndex, skillId}
function PartnerEventManager.HandleLearnPartnerSkill(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex
    local skillId = evt.args.skillId

    if not slotIndex or not skillId then
        --gg.log("伙伴学习技能缺少参数", player.uin, "槽位", slotIndex, "技能", skillId)
        return
    end

    local success, errorMsg = PartnerMgr.LearnPartnerSkill(player.uin, slotIndex, skillId)

    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        --gg.log("伙伴学习技能成功", player.uin, "槽位", slotIndex, "技能", skillId)
    else
        --gg.log("伙伴学习技能失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理重命名伙伴请求
---@param evt table 事件数据 {slotIndex, newName}
function PartnerEventManager.HandleRenamePartner(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex
    local newName = evt.args.newName

    if not slotIndex or not newName then
        --gg.log("重命名伙伴缺少参数", player.uin, "槽位", slotIndex, "新名称", newName)
        return
    end

    local partnerInstance = PartnerMgr.GetPartnerInstance(player.uin, slotIndex)
    if partnerInstance then
        partnerInstance:SetCustomName(newName)
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        --gg.log("重命名伙伴成功", player.uin, "槽位", slotIndex, "新名称", newName)
    else
        --gg.log("重命名伙伴失败：伙伴不存在", player.uin, "槽位", slotIndex)
    end
end

--- 通知客户端伙伴列表更新
---@param uin number 玩家ID
---@param partnerData table 完整的伙伴数据
function PartnerEventManager.NotifyPartnerListUpdate(uin, partnerData)
    -- --gg.log("通知客户端伙伴列表更新", uin, partnerData)
    gg.network_channel:fireClient(uin, {
        cmd = PartnerEventManager.NOTIFY.PARTNER_LIST_UPDATE,
        companionList = partnerData.companionList, -- 伙伴列表
        activeSlots = partnerData.activeSlots,       -- 已装备的伙伴槽位映射
        equipSlotIds = partnerData.equipSlotIds,     -- 可用的装备栏ID列表
        companionCount = partnerData.companionCount or 0, -- 【新增】伙伴数量
        bagCapacity = partnerData.maxSlots or 30,        -- 【新增】背包容量
        unlockedEquipSlots = partnerData.unlockedEquipSlots or 1, -- 【新增】已解锁的装备栏位数
        maxEquipSlots = partnerData.maxEquipSlots or 1,           -- 【新增】系统最大装备栏位数
        companionType = partnerData.companionType or "伙伴"        -- 【新增】伙伴类型标识
    })
end

--- 通知客户端单个伙伴更新
---@param uin number 玩家ID
---@param partnerInfo table 伙伴信息
function PartnerEventManager.NotifyPartnerUpdate(uin, partnerInfo)
    gg.network_channel:fireClient(uin, {
        cmd = PartnerEventManager.NOTIFY.PARTNER_UPDATE,
        partnerInfo = partnerInfo
    })
end

--- 通知客户端错误信息
---@param uin number 玩家ID
---@param errorCode number 错误码
---@param errorMsg string 错误信息
function PartnerEventManager.NotifyError(uin, errorCode, errorMsg)
    local player = MServerDataManager.getPlayerByUin(uin)
    if player then
        player:SendHoverText(errorMsg)
    end
end

-- =================================
-- 新增功能事件处理
-- =================================

---处理一键升星请求
---@param evt table 事件数据
function PartnerEventManager.HandleUpgradeAllPartners(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local upgradedCount = PartnerMgr.UpgradeAllPossiblePartners(player.uin)
    
    if upgradedCount > 0 then
        --gg.log("一键升星完成", player.uin, "升星数量", upgradedCount)
        local updatedData = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("一键升星：没有可升星的伙伴", player.uin)
    end
end

---处理删除伙伴请求
---@param evt table 事件数据 { slotIndex: number }
function PartnerEventManager.HandleDeletePartner(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local slotIndex = args.slotIndex

    if not slotIndex then
        PartnerEventManager.NotifyError(player.uin, -1, "删除伙伴缺少槽位参数")
        return
    end

    local success, errorMsg = PartnerMgr.DeletePartner(player.uin, slotIndex)

    if success then
        --gg.log("删除伙伴成功", player.uin, "槽位", slotIndex)
        local updatedData = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("删除伙伴失败", player.uin, errorMsg)
        PartnerEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

---处理切换伙伴锁定状态请求
---@param evt table 事件数据 { slotIndex: number }
function PartnerEventManager.HandleTogglePartnerLock(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local slotIndex = args.slotIndex

    if not slotIndex then
        PartnerEventManager.NotifyError(player.uin, -1, "切换锁定状态缺少槽位参数")
        return
    end

    local success, errorMsg, newLockState = PartnerMgr.TogglePartnerLock(player.uin, slotIndex)

    if success then
        --gg.log("切换伙伴锁定状态成功", player.uin, "槽位", slotIndex, "新状态", newLockState)
        local updatedData = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("切换伙伴锁定状态失败", player.uin, errorMsg)
        PartnerEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

---处理自动装备最优伙伴请求
---@param evt table 事件数据 { equipSlotId: string, excludeEquipped: boolean }
function PartnerEventManager.HandleAutoEquipBestPartner(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local equipSlotId = args.equipSlotId
    local excludeEquipped = args.excludeEquipped

    if not equipSlotId then
        PartnerEventManager.NotifyError(player.uin, -1, "自动装备伙伴缺少装备栏参数")
        return
    end

    local success, errorMsg, slotIndex = PartnerMgr.AutoEquipBestEffectPartner(player.uin, equipSlotId, excludeEquipped)

    if success then
        --gg.log("自动装备最优伙伴成功", player.uin, "装备栏", equipSlotId, "伙伴槽位", slotIndex)
        local updatedData = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("自动装备最优伙伴失败", player.uin, errorMsg)
        PartnerEventManager.NotifyError(player.uin, -1, errorMsg)
    end
end

---处理自动装备所有最优伙伴请求
---@param evt table 事件数据 { excludeEquipped: boolean }
function PartnerEventManager.HandleAutoEquipAllBestPartners(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local excludeEquipped = args.excludeEquipped

    local results = PartnerMgr.AutoEquipAllBestEffectPartners(player.uin, excludeEquipped)
    
    -- 获取伙伴效果排行以便返回给客户端
    local ranking, rankingError = PartnerMgr.GetPartnerEffectRanking(player.uin, 10)
    
    if ranking then
        --gg.log("自动装备所有最优伙伴完成", player.uin, "结果", results)
        
        -- 发送排行数据给客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = PartnerEventManager.RESPONSE.PARTNER_EFFECT_RANKING,
            ranking = ranking,
            results = results
        })
        
        -- 更新伙伴列表数据
        local updatedData = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
    else
        --gg.log("自动装备所有最优伙伴失败", player.uin, rankingError)
        PartnerEventManager.NotifyError(player.uin, -1, rankingError or "自动装备失败")
    end
end

---处理获取伙伴效果排行请求
---@param evt table 事件数据 { limit: number }
function PartnerEventManager.HandleGetPartnerEffectRanking(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local limit = args.limit or 10

    local ranking, errorMsg = PartnerMgr.GetPartnerEffectRanking(player.uin, limit)

    if ranking then
        gg.network_channel:fireClient(player.uin, {
            cmd = PartnerEventManager.RESPONSE.PARTNER_EFFECT_RANKING,
            ranking = ranking
        })
    else
        PartnerEventManager.NotifyError(player.uin, -1, errorMsg or "获取排行失败")
    end
end

return PartnerEventManager
