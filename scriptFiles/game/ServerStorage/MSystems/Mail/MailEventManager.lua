local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local MailEventConfig = require(MainStorage.Code.Event.EventMail) ---@type MailEventConfig

---@class MailEventManager
local MailEventManager = {}

-- 使用EventMail配置中的事件定义
MailEventManager.EVENTS = MailEventConfig
MailEventManager.ERROR_CODES = MailEventConfig.ERROR_CODES

---------------------------------------------------------------------------------------------------
--                                      邮件发送功能 (从MailManager合并)
---------------------------------------------------------------------------------------------------

--- 生成邮件ID
---@param prefix string 前缀，如"mail_p_"或"mail_g_"
---@return string 生成的邮件ID
function MailEventManager.GenerateMailId(prefix)
    local timestamp = os.time()
    local random = math.random(10000, 99999)
    return prefix .. timestamp .. "_" .. random
end

--- 发送个人邮件
---@param recipientUin number 收件人UIN
---@param title string 标题
---@param content string 内容
---@param attachments table 附件列表
---@param senderInfo table 发件人信息 {name: string, id: number}
---@param expireDays number|nil 过期天数
---@return boolean, string 返回成功标志和邮件ID或错误信息
function MailEventManager.SendPersonalMail(recipientUin, title, content, attachments, senderInfo, expireDays)
    if not recipientUin or not title or not content then
        return false, "参数无效"
    end

    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    local now = os.time()
    local finalExpireDays = expireDays or MailEventConfig.DEFAULT_EXPIRE_DAYS

    local mailData = {
        type = MailEventConfig.MAIL_TYPE.PLAYER,
        title = title,
        content = content,
        attachments = attachments or {},
        sender_info = senderInfo or { name = "系统", id = 0 },
        expire_time = now + finalExpireDays * 24 * 3600,
        create_time = now
    }

    local result = MailMgr.SendNewMail(mailData, recipientUin)
    return result.success, result.mailId or result.message
end

--- 发送全服邮件
---@param title string 标题
---@param content string 内容
---@param attachments table 附件列表
---@param expireDays number|nil 过期天数
---@return boolean, string 返回成功标志和邮件ID或错误信息
function MailEventManager.SendGlobalMail(title, content, attachments, expireDays)
    if not title or not content then
        return false, "参数无效"
    end

    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr) ---@type MailMgr
    local now = os.time()
    local finalExpireDays = expireDays or MailEventConfig.DEFAULT_EXPIRE_DAYS

    local mailData = {
        type = MailEventConfig.MAIL_TYPE.SYSTEM,
        title = title,
        content = content,
        attachments = attachments or {},
        sender_info = { name = "系统", id = 0 },
        expire_time = now + finalExpireDays * 24 * 3600,
        create_time = now
    }

    local result = MailMgr.SendNewMail(mailData)
    return result.success, result.mailId or result.message
end

---------------------------------------------------------------------------------------------------
--                                      事件处理功能 (原有功能)
---------------------------------------------------------------------------------------------------

-- 初始化事件管理器
function MailEventManager.Init()
    -- 注册网络事件处理器
    MailEventManager.RegisterNetworkHandlers()
end

-- 注册网络事件处理器
function MailEventManager.RegisterNetworkHandlers()
    -- 获取邮件列表
    ServerEventManager.Subscribe(MailEventConfig.REQUEST.GET_LIST, function(event)
        MailEventManager.HandleGetMailList(event)
    end, 100)

    -- 标记邮件为已读
    ServerEventManager.Subscribe(MailEventConfig.REQUEST.MARK_READ, function(event)
        MailEventManager.HandleReadMail(event)
    end, 100)

    -- 领取邮件附件
    ServerEventManager.Subscribe(MailEventConfig.REQUEST.CLAIM_MAIL, function(event)
        MailEventManager.HandleClaimMail(event)
    end, 100)

    -- 删除邮件
    ServerEventManager.Subscribe(MailEventConfig.REQUEST.DELETE_MAIL, function(event)
        MailEventManager.HandleDeleteMail(event)
    end, 100)

    -- 批量领取
    ServerEventManager.Subscribe(MailEventConfig.REQUEST.BATCH_CLAIM, function(event)
        MailEventManager.HandleBatchClaim(event)
    end, 100)

    -- 删除已读邮件
    ServerEventManager.Subscribe(MailEventConfig.REQUEST.DELETE_READ_MAILS, function(event)
        MailEventManager.HandleDeleteReadMails(event)
    end, 100)
end

-- 处理获取邮件列表请求
function MailEventManager.HandleGetMailList(event)
    local player = event.player
    if not player then
        --gg.log("获取邮件列表失败：玩家不存在")
        return
    end

    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    local result = MailMgr.GetPlayerMailList(player.uin)

    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventConfig.RESPONSE.LIST_RESPONSE,
        personal_mails = result.personal_mails,
        global_mails = result.global_mails
    })

end

-- 处理读取邮件请求
function MailEventManager.HandleReadMail(event)
    local player = event.player
    local mailId = event.mailId

    if not player or not mailId then
        --gg.log("读取邮件失败：参数无效")
        return
    end

    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)     ---@type MailMgr
    local result = MailMgr.ReadMail(player.uin, mailId)

    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventConfig.RESPONSE.LIST_RESPONSE,
        code = result.code,
        message = result.message or MailEventConfig.GetErrorMessage(result.code),
        mailId = mailId
    })
end

-- 处理领取邮件附件请求
function MailEventManager.HandleClaimMail(event)
    local player = event.player
    local mailId = event.mail_id or event.mailId  -- 兼容两种参数名

    gg.log("🎁 服务端收到领取请求 - 玩家:", player and player.uin, "邮件ID:", mailId)

    if not player or not mailId then
        gg.log("❌ 领取邮件附件失败：参数无效 - 玩家:", player and player.uin, "邮件ID:", mailId)
        return
    end

    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    local result = MailMgr.ClaimMailAttachment(player.uin, mailId)

    gg.log("📤 发送领取响应 - 成功:", result.success, "代码:", result.code, "消息:", result.message)

    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventConfig.RESPONSE.CLAIM_RESPONSE,
        success = result.success,
        code = result.code,
        message = result.message or MailEventConfig.GetErrorMessage(result.code),
        mail_id = mailId,
        rewards = result.rewards
    })
end

-- 处理删除邮件请求
function MailEventManager.HandleDeleteMail(event)
    local player = event.player
    local mailId = event.mailId

    if not player or not mailId then
        --gg.log("删除邮件失败：参数无效")
        return
    end

    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr) ---@type MailMgr
    local result = MailMgr.DeleteMail(player.uin, mailId)

    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventConfig.RESPONSE.DELETE_RESPONSE,
        code = result.code,
        message = result.message or MailEventConfig.GetErrorMessage(result.code),
        mailId = mailId
    })
end

-- 处理批量领取请求
function MailEventManager.HandleBatchClaim(event)
    local player = event.player
    local mailIds = event.mailIds or {}

    if not player then
        --gg.log("批量领取失败：玩家不存在")
        return
    end

    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    local result = MailMgr.BatchClaimMails(player.uin, mailIds)

    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventConfig.RESPONSE.BATCH_CLAIM_SUCCESS,
        code = result.code,
        message = result.message or MailEventConfig.GetErrorMessage(result.code),
        rewards = result.rewards
    })
end

-- 处理删除已读邮件请求
function MailEventManager.HandleDeleteReadMails(event)
    local player = event.player
    local personalMailIds = event.personalMailIds or {}
    local globalMailIds = event.globalMailIds or {}

    gg.log("🗑️ 服务端收到删除已读邮件请求 - 玩家:", player and player.uin, "个人邮件:", #personalMailIds, "全服邮件:", #globalMailIds)

    if not player then
        gg.log("❌ 删除已读邮件失败：玩家不存在")
        return
    end

    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr) ---@type MailMgr
    local totalDeletedCount = 0
    local deletedMailIds = {}

    -- 删除个人邮件
    if #personalMailIds > 0 then
        for _, mailId in ipairs(personalMailIds) do
            local result = MailMgr.DeleteMail(player.uin, mailId)
            if result.success then
                totalDeletedCount = totalDeletedCount + 1
                table.insert(deletedMailIds, mailId)
                gg.log("✅ 删除个人邮件成功:", mailId)
            else
                gg.log("❌ 删除个人邮件失败:", mailId, "错误:", result.message)
            end
        end
    end

    -- 删除全服邮件（标记为已删除）
    if #globalMailIds > 0 then
        local GlobalMailManager = require(ServerStorage.MSystems.Mail.GlobalMailManager) ---@type GlobalMailManager
        local mailData = MailMgr.GetPlayerMailData(player.uin)
        
        if mailData and mailData.globalMailStatus then
            for _, mailId in ipairs(globalMailIds) do
                local success, message = GlobalMailManager:DeleteGlobalMailForPlayer(player.uin, mailId, mailData.globalMailStatus)
                if success then
                    totalDeletedCount = totalDeletedCount + 1
                    table.insert(deletedMailIds, mailId)
                    gg.log("✅ 删除全服邮件成功:", mailId)
                else
                    gg.log("❌ 删除全服邮件失败:", mailId, "错误:", message)
                end
            end
        end
    end

    -- 通知邮件列表更新
    MailMgr.NotifyMailListUpdate(player.uin)

    gg.log("📤 发送删除已读邮件响应 - 成功:", totalDeletedCount, "个邮件")

    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventConfig.RESPONSE.DELETE_READ_SUCCESS,
        code = MailEventConfig.ERROR_CODES.SUCCESS,
        message = string.format("成功删除 %d 封已读邮件", totalDeletedCount),
        deletedCount = totalDeletedCount,
        deletedMailIds = deletedMailIds
    })
end

-- 通知客户端新邮件
function MailEventManager.NotifyNewMail(uin, mailData)
    if not uin or not mailData then
        return
    end

    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.NOTIFY.NEW_MAIL,
        mailData = mailData
    })

    --gg.log("发送新邮件通知", uin, mailData.title)
end

-- 通知所有在线玩家新邮件（全服邮件）
function MailEventManager.BroadcastNewMail(mailData)
    if not mailData then
        return
    end

    for _, player in pairs(gg.server_players_list or {}) do
        if player and player.uin then
            MailEventManager.NotifyNewMail(player.uin, mailData)
        end
    end

    --gg.log("广播新邮件通知", mailData.title)
end

-- 通知邮件列表更新
function MailEventManager.NotifyMailListUpdate(uin, personalMails, globalMails)
    if not uin then
        return
    end

    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.RESPONSE.LIST_RESPONSE,
        code = MailEventConfig.ERROR_CODES.SUCCESS,
        personal_mails = personalMails or {},
        global_mails = globalMails or {}
    })

    gg.log("发送邮件列表更新通知", uin, "个人邮件:", #(personalMails or {}), "全服邮件:", #(globalMails or {}))
end

return MailEventManager
