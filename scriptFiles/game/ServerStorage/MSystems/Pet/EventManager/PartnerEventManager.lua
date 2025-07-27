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
    
    -- 设置激活伙伴
    ServerEventManager.Subscribe(PartnerEventManager.REQUEST.SET_ACTIVE_PARTNER, function(evt) PartnerEventManager.HandleSetActivePartner(evt) end)
    
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
end

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function PartnerEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        gg.log("伙伴事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        gg.log("伙伴事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

--- 处理获取伙伴列表请求
---@param evt table 事件数据
function PartnerEventManager.HandleGetPartnerList(evt)
    gg.log("获取伙伴列表", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end
    
    local result, errorMsg = PartnerMgr.GetPlayerPartnerList(player.uin)
    if result then
        PartnerEventManager.NotifyPartnerListUpdate(player.uin, result)
    else
        gg.log("获取伙伴列表失败", player.uin, errorMsg)
    end
end

--- 处理设置激活伙伴请求
---@param evt table 事件数据 {slotIndex}
function PartnerEventManager.HandleSetActivePartner(evt)
    gg.log("设置激活伙伴", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex  -- 修改：统一使用 slotIndex
    local success, errorMsg = PartnerMgr.SetActivePartner(player.uin, slotIndex)
    
    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据
        local updatedData, errorMsg = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            -- 使用事件管理器自己的通知函数来发送完整的列表更新
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
            gg.log("设置激活伙伴成功，并已通知客户端更新列表", player.uin, "槽位", slotIndex)
        else
            gg.log("设置激活伙伴成功，但获取最新列表失败", player.uin, errorMsg)
        end
    else
        gg.log("设置激活伙伴失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理伙伴升级请求
---@param evt table 事件数据 {slotIndex, targetLevel}
function PartnerEventManager.HandleLevelUpPartner(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex      -- 修改：从args中获取
    local targetLevel = evt.args.targetLevel  -- 修改：从args中获取
    
    if not slotIndex then
        gg.log("伙伴升级缺少槽位参数", player.uin)
        return
    end
    
    local success, errorMsg, leveledUp = PartnerMgr.LevelUpPartner(player.uin, slotIndex, targetLevel)
    
    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        gg.log("伙伴升级成功", player.uin, "槽位", slotIndex, "是否升级", leveledUp)
    else
        gg.log("伙伴升级失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
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
        gg.log("伙伴获得经验缺少参数", player.uin, "槽位", slotIndex, "经验", expAmount)
        return
    end
    
    local success, errorMsg, leveledUp = PartnerMgr.AddPartnerExp(player.uin, slotIndex, expAmount)
    
    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        gg.log("伙伴获得经验成功", player.uin, "槽位", slotIndex, "经验", expAmount, "是否升级", leveledUp)
    else
        gg.log("伙伴获得经验失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
    end
end

--- 处理伙伴升星请求
---@param evt table 事件数据 {slotIndex}
function PartnerEventManager.HandleUpgradePartnerStar(evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    if not player then return end

    local slotIndex = evt.args.slotIndex  -- 确认：使用 slotIndex
    
    if not slotIndex then
        gg.log("伙伴升星缺少槽位参数", player.uin)
        return
    end
    
    local success, errorMsg = PartnerMgr.UpgradePartnerStar(player.uin, slotIndex)
    
    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        gg.log("伙伴升星成功", player.uin, "槽位", slotIndex)
    else
        gg.log("伙伴升星失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
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
        gg.log("伙伴学习技能缺少参数", player.uin, "槽位", slotIndex, "技能", skillId)
        return
    end
    
    local success, errorMsg = PartnerMgr.LearnPartnerSkill(player.uin, slotIndex, skillId)
    
    if success then
        -- 操作成功后，获取最新的完整伙伴列表数据并通知客户端
        local updatedData, getError = PartnerMgr.GetPlayerPartnerList(player.uin)
        if updatedData then
            PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        end
        gg.log("伙伴学习技能成功", player.uin, "槽位", slotIndex, "技能", skillId)
    else
        gg.log("伙伴学习技能失败", player.uin, "槽位", slotIndex, "错误", errorMsg)
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
        gg.log("重命名伙伴缺少参数", player.uin, "槽位", slotIndex, "新名称", newName)
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
        gg.log("重命名伙伴成功", player.uin, "槽位", slotIndex, "新名称", newName)
    else
        gg.log("重命名伙伴失败：伙伴不存在", player.uin, "槽位", slotIndex)
    end
end

--- 通知客户端伙伴列表更新
---@param uin number 玩家ID
---@param partnerData table 完整的伙伴数据，包含 partnerList 和 activePartnerId
function PartnerEventManager.NotifyPartnerListUpdate(uin, partnerData)
    gg.network_channel:fireClient(uin, {
        cmd = PartnerEventManager.NOTIFY.PARTNER_LIST_UPDATE,
        partnerList = partnerData.partnerList,
        activePartnerId = partnerData.activePartnerId
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

return PartnerEventManager