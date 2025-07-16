--- 邮件服务 - 统一的邮件系统管理模块
--- V109 miniw-haima
--- 合并了数据管理和业务逻辑，避免循环依赖

local game = game
local pairs = pairs
local ipairs = ipairs
local type = type
local table = table
local os = os
local math = math

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local cloudService = game:GetService("CloudService") ---@type CloudService

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MailEventConfig = require(MainStorage.Code.Event.EventMail) ---@type MailEventConfig
local GlobalMailManager = require(ServerStorage.MSystems.Mail.GlobalMailManager) ---@type GlobalMailManager
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class MailMgr
local MailMgr = {
    -- 邮件类型
    MAIL_TYPE = MailEventConfig.MAIL_TYPE,
    -- 邮件状态
    MAIL_STATUS = MailEventConfig.STATUS,
    -- 错误码
    ERROR_CODE = MailEventConfig.ERROR_CODES,
    
    -- 在线玩家邮件数据缓存
    server_player_mail_data = {},
    
    -- 云存储键前缀
    CLOUD_KEYS = {
        PLAYER_MAIL = "mail_player_",
        GLOBAL_MAIL_STATUS = "mail_global_status_"
    }
}


---------------------------------------------------------------------------------------------------
--                                      数据管理层 (原MailMgr功能)
---------------------------------------------------------------------------------------------------

--- 从云端加载玩家邮件数据包
---@param uin number 玩家ID
---@return table|nil 邮件数据包
function MailMgr.LoadPlayerMailFromCloud(uin)
    if not uin then
        gg.log("加载玩家邮件失败：UIN为空")
        return nil
    end
    
    local bundle = {}
    
    -- 加载个人邮件数据
    local playerMailKey = MailMgr.CLOUD_KEYS.PLAYER_MAIL .. uin
    local success1, playerMailData = cloudService:GetTableOrEmpty(playerMailKey)
    
    if success1 and playerMailData and playerMailData.mails then
        bundle.playerMail = playerMailData
        gg.log("加载玩家个人邮件成功", uin, "邮件数量:", MailMgr._CountTable(playerMailData.mails))
    else
        bundle.playerMail = {
            uin = uin,
            mails = {},
            last_update = os.time()
        }
        -- gg.log("创建玩家个人邮件默认数据", uin)
    end
    
    -- 加载全服邮件状态数据
    local globalStatusKey = MailMgr.CLOUD_KEYS.GLOBAL_MAIL_STATUS .. uin
    local success2, globalStatusData = cloudService:GetTableOrEmpty(globalStatusKey)
    
    if success2 and globalStatusData and globalStatusData.statuses then
        bundle.globalMailStatus = globalStatusData
        -- gg.log("加载玩家全服邮件状态成功", uin)
    else
        bundle.globalMailStatus = {
            uin = uin,
            statuses = {},
            last_update = os.time()
        }
        -- gg.log("创建玩家全服邮件状态默认数据", uin)
    end
    
    return bundle
end

--- 保存玩家邮件数据包到云端
---@param uin number 玩家ID
---@param bundle table 邮件数据包
---@return boolean 是否成功
function MailMgr.SavePlayerMailToCloud(uin, bundle)
    if not uin or not bundle then
        gg.log("保存玩家邮件失败：参数无效")
        return false
    end
    
    local success = true
    local now = os.time()
    
    -- 保存个人邮件数据
    if bundle.playerMail then
        bundle.playerMail.last_update = now
        local playerMailKey = MailMgr.CLOUD_KEYS.PLAYER_MAIL .. uin
        
        cloudService:SetTableAsync(playerMailKey, bundle.playerMail, function(saveSuccess)
            if not saveSuccess then
                gg.log("保存玩家个人邮件失败", uin)
                success = false
            else
                gg.log("保存玩家个人邮件成功", uin)
            end
        end)
    end
    
    -- 保存全服邮件状态数据
    if bundle.globalMailStatus then
        bundle.globalMailStatus.last_update = now
        local globalStatusKey = MailMgr.CLOUD_KEYS.GLOBAL_MAIL_STATUS .. uin
        
        cloudService:SetTableAsync(globalStatusKey, bundle.globalMailStatus, function(saveSuccess)
            if not saveSuccess then
                gg.log("保存玩家全服邮件状态失败", uin)
                success = false
            else
                gg.log("保存玩家全服邮件状态成功", uin)
            end
        end)
    end
    
    return success
end

---获得指定uin玩家的邮件数据
---@param uin number 玩家ID
---@return table|nil 玩家邮件数据
function MailMgr.GetPlayerMailData(uin)
    return MailMgr.server_player_mail_data[uin]
end

---设置玩家邮件数据到缓存
---@param uin number 玩家ID
---@param mailData table 邮件数据
function MailMgr.SetPlayerMailData(uin, mailData)
    MailMgr.server_player_mail_data[uin] = mailData
    gg.log("玩家邮件数据已缓存", uin)
end

---玩家上线处理
---@param player MPlayer 玩家对象
function MailMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        gg.log("玩家上线处理失败：玩家对象无效")
        return
    end
    
    local uin = player.uin
    gg.log("开始处理玩家邮件上线", uin)
    
    -- 从云端加载邮件数据
    local mailBundle = MailMgr.LoadPlayerMailFromCloud(uin)
    if mailBundle then
        -- 缓存到内存
        MailMgr.SetPlayerMailData(uin, mailBundle)
        
        gg.log("玩家邮件数据加载完成", uin)
        
        -- 同步全服邮件状态
        MailMgr.SyncGlobalMailsForPlayer(uin)
        
        -- 检查并发送全局邮件通知
        -- 延迟一点确保数据完全同步
        GlobalMailManager:CheckAndSendGlobalMailsToPlayer(player)
    else
        gg.log("玩家邮件数据加载失败", uin)
    end
end

---玩家离线处理
---@param uin number 玩家ID
function MailMgr.OnPlayerLeave(uin)
    local mailData = MailMgr.server_player_mail_data[uin]
    if mailData then
        -- 保存邮件数据到云端
        MailMgr.SavePlayerMailToCloud(uin, mailData)
        
        -- 清理内存缓存
        MailMgr.server_player_mail_data[uin] = nil
        gg.log("玩家邮件数据已保存并清理", uin)
    end
end

---------------------------------------------------------------------------------------------------
--                                      业务逻辑层 (原MailManager功能)
---------------------------------------------------------------------------------------------------

--- 生成邮件ID
---@param prefix string 前缀，如"mail_p_"或"mail_g_"
---@return string 生成的邮件ID
function MailMgr.GenerateMailId(prefix)
    local timestamp = os.time()
    local random = math.random(10000, 99999)
    return prefix .. timestamp .. "_" .. random
end

--- 同步玩家的全服邮件状态
---@param uin number 玩家ID
---@return boolean 是否有数据更新
function MailMgr.SyncGlobalMailsForPlayer(uin)
    local mailData = MailMgr.GetPlayerMailData(uin)
    if not mailData or not mailData.globalMailStatus then
        gg.log("同步全服邮件失败：找不到玩家邮件数据", uin)
        return false
    end

    local allGlobalMails = GlobalMailManager:GetAllGlobalMails()
    local playerGlobalStatus = mailData.globalMailStatus
    local updated = false

    for mailId, globalMail in pairs(allGlobalMails) do
        -- 检查玩家是否已有该邮件的状态
        if not playerGlobalStatus.statuses[mailId] then
            -- 如果没有，创建新的状态记录，默认为未读
            playerGlobalStatus.statuses[mailId] = {
                status = MailMgr.MAIL_STATUS.UNREAD,
                is_claimed = false
            }
            updated = true
            gg.log("为玩家", uin, "同步新的全服邮件:", mailId)
        end
    end

    if updated then
        -- 如果有更新，通知客户端
        MailMgr.NotifyMailListUpdate(uin)
    end

    return updated
end

--- 查找特定邮件 (包括个人和全服)
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return table {mail: table|nil, mailType: string|nil, mailStatus: table|nil}
function MailMgr.FindMail(uin, mailId)
    local mailData = MailMgr.GetPlayerMailData(uin)
    if not mailData then
        gg.log("查找邮件失败：找不到玩家邮件数据", uin)
        return {mail = nil, mailType = nil, mailStatus = nil}
    end

    -- 在个人邮件中查找
    if mailData.playerMail and mailData.playerMail.mails[mailId] then
        local mail = mailData.playerMail.mails[mailId]
        return {mail = mail, mailType = MailMgr.MAIL_TYPE.PLAYER, mailStatus = nil}
    end

    -- 在全服邮件中查找
    local allGlobalMails = GlobalMailManager:GetAllGlobalMails()
    if allGlobalMails[mailId] then
        local mail = allGlobalMails[mailId]
        local status = mailData.globalMailStatus.statuses[mailId]
        return {mail = mail, mailType = MailMgr.MAIL_TYPE.GLOBAL, mailStatus = status}
    end

    gg.log("查找邮件失败：邮件不存在", uin, mailId)
    return {mail = nil, mailType = nil, mailStatus = nil}
end

--- 获取玩家的邮件列表 (合并个人和全服)
---@param uin number 玩家ID
---@return table {success: boolean, mailList: table|nil, message: string|nil}
function MailMgr.GetPlayerMailList(uin)
    local mailData = MailMgr.GetPlayerMailData(uin)
    if not mailData then
        return {success = false, mailList = nil, message = "玩家数据未找到"}
    end
    
    local mailList = {}
    local now = os.time()
    
    -- 合并个人邮件
    if mailData.playerMail and mailData.playerMail.mails then
        for id, mail in pairs(mailData.playerMail.mails) do
            if not mail.expire_time or now < mail.expire_time then
                table.insert(mailList, mail)
            end
        end
    end
    
    -- 合并全服邮件
    local allGlobalMails = GlobalMailManager:GetAllGlobalMails()
    if mailData.globalMailStatus and mailData.globalMailStatus.statuses then
        for id, status in pairs(mailData.globalMailStatus.statuses) do
            local mail = allGlobalMails[id]
            if mail and (not mail.expire_time or now < mail.expire_time) then
                -- 创建一个合并了状态的副本，不修改原始全服邮件
                local mailCopy = MailMgr._CopyTable(mail)
                mailCopy.status = status.status
                mailCopy.is_claimed = status.is_claimed
                table.insert(mailList, mailCopy)
            end
        end
    end
    
    -- 按创建时间降序排序
    table.sort(mailList, function(a, b)
        return a.create_time > b.create_time
    end)
    
    return {success = true, mailList = mailList, message = nil}
end

--- 发送新邮件 (个人或全服)
---@param mailData table 邮件数据
---@param targetUin number|nil 目标玩家ID (个人邮件需要)
---@return table {success: boolean, mailId: string|nil, message: string|nil}
function MailMgr.SendNewMail(mailData, targetUin)
    -- 验证邮件数据
    if not mailData or not mailData.title or not mailData.content then
        return {success = false, mailId = nil, message = "邮件数据无效"}
    end
    
    -- 填充默认值
    mailData.create_time = mailData.create_time or os.time()
    mailData.status = MailMgr.MAIL_STATUS.UNREAD
    mailData.is_claimed = false
    
    if mailData.type == MailMgr.MAIL_TYPE.PLAYER then
        -- 发送个人邮件
        if not targetUin then return {success = false, mailId = nil, message = "个人邮件需要目标玩家ID"} end
        
        mailData.uin = targetUin
        mailData.id = MailMgr.GenerateMailId("mail_p_")
        
        local playerData = MailMgr.GetPlayerMailData(targetUin)
        if playerData then
            -- 玩家在线，直接添加到缓存
            playerData.playerMail.mails[mailData.id] = mailData
            gg.log("发送个人邮件到在线玩家", targetUin, mailData.id)
            -- 通知客户端
            MailMgr.NotifyNewMail(targetUin, mailData)
        else
            -- 玩家离线，直接写到云存储
            -- 注意：这里需要先读取再写入，可能会有性能问题，最好是在线操作
            -- 简化处理：离线邮件发送可能需要一个更鲁棒的队列系统
            gg.log("警告：尝试向离线玩家发送邮件，此功能简化实现", targetUin)
            local playerMailKey = MailMgr.CLOUD_KEYS.PLAYER_MAIL .. targetUin
            local success, data = cloudService:GetTableOrEmpty(playerMailKey)
            if success then
                data.mails = data.mails or {}
                data.mails[mailData.id] = mailData
                cloudService:SetTableAsync(playerMailKey, data)
            end
        end
        
        return {success = true, mailId = mailData.id, message = nil}
        
    elseif mailData.type == MailMgr.MAIL_TYPE.GLOBAL then
        -- 发送全服邮件
        local success, mailId = GlobalMailManager:AddGlobalMail(mailData)
        if success then 
            gg.log("新的全服邮件已发布", mailId)
            -- 向所有在线玩家广播
            local MailEventManager = require(ServerStorage.MSystems.Mail.MailEventManager) ---@type MailEventManager        
            MailEventManager.BroadcastNewMail(mailData)
            return {success = true, mailId = mailId, message = nil}
        else
            return {success = false, mailId = nil, message = "添加全服邮件失败"}
        end
    else
        return {success = false, mailId = nil, message = "未知的邮件类型"}
    end
end

--- 读取邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return table {success: boolean, code: number, message: string}
function MailMgr.ReadMail(uin, mailId)
    local findResult = MailMgr.FindMail(uin, mailId)
    local mail, mailType, mailStatus = findResult.mail, findResult.mailType, findResult.mailStatus
    
    if not mail then
        return {success = false, code = MailMgr.ERROR_CODE.MAIL_NOT_FOUND, message = "邮件不存在"}
    end
    
    if mailType == MailMgr.MAIL_TYPE.PLAYER then
        if mail.status == MailMgr.MAIL_STATUS.UNREAD then
            mail.status = MailMgr.MAIL_STATUS.READ
            -- 标记为脏，以便保存
            -- MailMgr.GetPlayerMailData(uin).dirty = true
            MailMgr.NotifyMailListUpdate(uin)
            gg.log("玩家", uin, "读取个人邮件", mailId)
        end
    elseif mailType == MailMgr.MAIL_TYPE.GLOBAL then
        if mailStatus.status == MailMgr.MAIL_STATUS.UNREAD then
            mailStatus.status = MailMgr.MAIL_STATUS.READ
            -- MailMgr.GetPlayerMailData(uin).dirty = true
            MailMgr.NotifyMailListUpdate(uin)
            gg.log("玩家", uin, "读取全服邮件", mailId)
        end
    end
    
    return {success = true, code = MailMgr.ERROR_CODE.SUCCESS, message = "操作成功"}
end

--- 领取邮件附件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return table {success: boolean, code: number, message: string, rewards: table}
function MailMgr.ClaimMailAttachment(uin, mailId)
    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        return {success = false, code = MailMgr.ERROR_CODE.PLAYER_NOT_FOUND, message = "玩家不存在", rewards = {}}
    end

    local findResult = MailMgr.FindMail(uin, mailId)
    local mail, mailType, mailStatus = findResult.mail, findResult.mailType, findResult.mailStatus
    
    if not mail then
        return {success = false, code = MailMgr.ERROR_CODE.MAIL_NOT_FOUND, message = "邮件不存在", rewards = {}}
    end
    
    if not mail.attachments or not next(mail.attachments) then
        return {success = false, code = MailMgr.ERROR_CODE.MAIL_NO_ATTACHMENT, message = "没有附件可以领取", rewards = {}}
    end
    
    local isClaimed = false
    if mailType == MailMgr.MAIL_TYPE.PLAYER then
        isClaimed = mail.is_claimed
    elseif mailType == MailMgr.MAIL_TYPE.GLOBAL then
        isClaimed = mailStatus.is_claimed
    end
    
    if isClaimed then
        return {success = false, code = MailMgr.ERROR_CODE.MAIL_ALREADY_CLAIMED, message = "附件已被领取", rewards = {}}
    end
    
    -- 检查背包空间 (调用背包系统接口)
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    if not BagMgr.GetPlayerBag(uin):HasEnoughSpace(mail.attachments) then
        return {success = false, code = MailMgr.ERROR_CODE.BAG_FULL, message = "背包空间不足", rewards = {}}
    end
    
    -- 发放奖励
    local rewards = MailMgr._AddAttachmentsToPlayer(player, mail.attachments)
    
    -- 更新邮件状态
    if mailType == MailMgr.MAIL_TYPE.PLAYER then
        mail.is_claimed = true
    elseif mailType == MailMgr.MAIL_TYPE.GLOBAL then
        mailStatus.is_claimed = true
    end
    -- MailMgr.GetPlayerMailData(uin).dirty = true
    
    gg.log("玩家", uin, "领取附件成功", mailId)
    MailMgr.NotifyMailListUpdate(uin)
    
    return {success = true, code = MailMgr.ERROR_CODE.SUCCESS, message = "领取成功", rewards = rewards}
end

--- 批量领取邮件附件
---@param uin number 玩家ID
---@param mailIds table|nil 邮件ID列表 (如果为nil或空，则领取所有)
---@return table {success: boolean, code: number, message: string, rewards: table}
function MailMgr.BatchClaimMails(uin, mailIds)
    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        return {success = false, code = MailMgr.ERROR_CODE.PLAYER_NOT_FOUND, message = "玩家不存在", rewards = {}}
    end

    local listResult = MailMgr.GetPlayerMailList(uin)
    if not listResult.success then
        return {success = false, code = MailMgr.ERROR_CODE.PLAYER_NOT_FOUND, message = "获取邮件列表失败", rewards = {}}
    end
    local mailList = listResult.mailList
    
    local mailsToClaim = {}
    local totalAttachments = {}
    
    -- 筛选要领取的邮件
    if mailIds and #mailIds > 0 then
        local idSet = {}
        for _, id in ipairs(mailIds) do idSet[id] = true end
        for _, mail in ipairs(mailList) do
            if idSet[mail.id] then
                table.insert(mailsToClaim, mail)
            end
        end
    else
        mailsToClaim = mailList
    end
    
    local claimableMails = {}
    for _, mail in ipairs(mailsToClaim) do
        if mail.attachments and next(mail.attachments) and not mail.is_claimed then
            table.insert(claimableMails, mail)
            -- 合并附件到总附件列表
            for itemName, amount in pairs(mail.attachments) do
                totalAttachments[itemName] = (totalAttachments[itemName] or 0) + amount
            end
        end
    end

    if #claimableMails == 0 then
        return {success = false, code = MailMgr.ERROR_CODE.MAIL_NO_ATTACHMENT, message = "没有可领取的附件", rewards = {}}
    end

    -- 检查背包空间
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    if not BagMgr.GetPlayerBag(uin):HasEnoughSpace(totalAttachments) then
        return {success = false, code = MailMgr.ERROR_CODE.BAG_FULL, message = "背包空间不足", rewards = {}}
    end

    -- 发放奖励并更新状态
    local totalRewards = MailMgr._AddAttachmentsToPlayer(player, totalAttachments)
    local mailData = MailMgr.GetPlayerMailData(uin)
    
    for _, mail in ipairs(claimableMails) do
        local findResult = MailMgr.FindMail(uin, mail.id)
        local mailType, mailStatus = findResult.mailType, findResult.mailStatus
        if mailType == MailMgr.MAIL_TYPE.PLAYER then
            local m = mailData.playerMail.mails[mail.id]
            if m then
                m.is_claimed = true
            end
        elseif mailType == MailMgr.MAIL_TYPE.GLOBAL then
            if mailStatus then mailStatus.is_claimed = true end
        end
    end
    -- mailData.dirty = true

    gg.log("玩家", uin, "批量领取", #totalRewards, "个附件")
    MailMgr.NotifyMailListUpdate(uin)
    
    return {success = true, code = MailMgr.ERROR_CODE.SUCCESS, message = "批量领取成功", rewards = totalRewards}
end

--- 删除邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return table {success: boolean, code: number, message: string}
function MailMgr.DeleteMail(uin, mailId)
    local findResult = MailMgr.FindMail(uin, mailId)
    local mail, mailType = findResult.mail, findResult.mailType
    
    if not mail then
        return {success = false, code = MailMgr.ERROR_CODE.MAIL_NOT_FOUND, message = "邮件不存在"}
    end
    
    -- 全服邮件不能由玩家删除，只能忽略
    if mailType == MailMgr.MAIL_TYPE.GLOBAL then
        return {success = false, code = MailMgr.ERROR_CODE.INVALID_PARAM, message = "不能删除全服邮件"}
    end
    
    -- 个人邮件
    local mailData = MailMgr.GetPlayerMailData(uin)
    if mailData and mailData.playerMail.mails[mailId] then
        -- 未领取附件的邮件不能删除
        if mail.attachments and next(mail.attachments) and not mail.is_claimed then
            return {success = false, code = MailMgr.ERROR_CODE.INVALID_PARAM, message = "请先领取附件再删除"}
        end 
        mailData.playerMail.mails[mailId] = nil
        -- mailData.dirty = true
        gg.log("玩家", uin, "删除邮件", mailId)
        MailMgr.NotifyMailListUpdate(uin)
        return {success = true, code = MailMgr.ERROR_CODE.SUCCESS, message = "删除成功"}
    end
    
    return {success = false, code = MailMgr.ERROR_CODE.MAIL_NOT_FOUND, message = "删除失败"}
end

--- 删除所有已读邮件
---@param uin number 玩家ID
---@return table {success: boolean, code: number, message: string, deletedCount: number}
function MailMgr.DeleteReadMails(uin)
    local mailData = MailMgr.GetPlayerMailData(uin)
    if not mailData then
        return {success = false, code = MailMgr.ERROR_CODE.PLAYER_NOT_FOUND, message = "玩家数据不存在", deletedCount = 0}
    end
    
    local deletedCount = 0
    local mails = mailData.playerMail.mails
    
    -- 使用迭代器安全删除
    local idsToDelete = {}
    for id, mail in pairs(mails) do
        -- 只删除已读且没有可领取附件的个人邮件
        if mail.status == MailMgr.MAIL_STATUS.READ and (not mail.attachments or not next(mail.attachments) or mail.is_claimed) then
            table.insert(idsToDelete, id)
        end
    end
    
    for _, id in ipairs(idsToDelete) do
        mails[id] = nil
        deletedCount = deletedCount + 1
    end
    
    if deletedCount > 0 then
        -- mailData.dirty = true
        gg.log("玩家", uin, "删除", deletedCount, "封已读邮件")
        MailMgr.NotifyMailListUpdate(uin)
    end
    
    return {success = true, code = MailMgr.ERROR_CODE.SUCCESS, message = "操作完成", deletedCount = deletedCount}
end

---------------------------------------------------------------------------------------------------
--                                      通知和辅助函数
---------------------------------------------------------------------------------------------------

--- 通知客户端邮件列表更新
---@param uin number 玩家ID
function MailMgr.NotifyMailListUpdate(uin)
    local result = MailMgr.GetPlayerMailList(uin)
    if result.success then
        local MailEventManager = require(ServerStorage.MSystems.Mail.MailEventManager) ---@type MailEventManager
        MailEventManager.NotifyMailListUpdate(uin, result.mailList)
    end
end

--- 通知客户端新邮件
---@param uin number 玩家ID
---@param mailData table 邮件数据
function MailMgr.NotifyNewMail(uin, mailData)
    local MailEventManager = require(ServerStorage.MSystems.Mail.MailEventManager) ---@type MailEventManager
    MailEventManager.NotifyNewMail(uin, mailData)
end

--- 内部函数：添加附件到玩家背包
---@param player MPlayer 玩家对象
---@param attachments table 附件列表，格式: {"物品名": 数量}
---@return table 成功添加的物品列表
function MailMgr._AddAttachmentsToPlayer(player, attachments)
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    local ItemUtils = require(ServerStorage.MSystems.Bag.ItemUtils) ---@type ItemUtils
    if not player or not attachments then return {} end
    
    local addedItems = {}
    for itemName, amount in pairs(attachments) do
        if itemName and amount and amount > 0 then
            -- 创建物品数据
            local itemData = ItemUtils.CreateItemData(itemName, amount)
            if itemData then
                local success = BagMgr.GetPlayerBag(player.uin):AddItem(itemData)
                if success then
                    addedItems[itemName] = amount
                end
            end
        end
    end
    return addedItems
end

--- 内部函数：浅拷贝一个表
---@param orig table 原始表
---@return table 新表
function MailMgr._CopyTable(orig)
    if type(orig) ~= 'table' then return orig end
    local newTable = {}
    for k, v in pairs(orig) do
        newTable[k] = v
    end
    return newTable
end

--- 内部函数：计算表的元素数量
---@param tbl table
---@return number
function MailMgr._CountTable(tbl)
    if type(tbl) ~= 'table' then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

return MailMgr