local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

---@class MailEventManager
local MailEventManager = {}

-- 邮件相关事件命令
MailEventManager.EVENTS = {
    -- 客户端请求
    GET_MAIL_LIST = "mail_get_list",           -- 获取邮件列表
    READ_MAIL = "mail_read",                   -- 读取邮件
    CLAIM_MAIL = "mail_claim",                 -- 领取邮件附件
    DELETE_MAIL = "mail_delete",               -- 删除邮件
    BATCH_CLAIM = "mail_batch_claim",          -- 批量领取
    DELETE_READ_MAILS = "mail_delete_read",    -- 删除已读邮件
    
    -- 服务器通知
    MAIL_LIST_UPDATE = "mail_list_update",     -- 邮件列表更新
    NEW_MAIL_NOTIFY = "mail_new_notify",       -- 新邮件通知
    MAIL_CLAIMED = "mail_claimed",             -- 邮件已领取
    MAIL_DELETED = "mail_deleted"              -- 邮件已删除
}

-- 错误码
MailEventManager.ERROR_CODES = {
    SUCCESS = 0,
    MAIL_NOT_FOUND = 1001,        -- 邮件不存在
    MAIL_EXPIRED = 1002,          -- 邮件已过期
    MAIL_NO_ATTACHMENT = 1003,    -- 邮件没有附件
    MAIL_ALREADY_CLAIMED = 1004,  -- 邮件已领取
    BAG_FULL = 1005,              -- 背包已满
    PLAYER_NOT_FOUND = 1006,      -- 玩家不存在
    INVALID_PARAM = 1007          -- 参数无效
}

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
    local finalExpireDays = expireDays or 7 -- 默认7天过期
    
    local mailData = {
        type = MailMgr.MAIL_TYPE.PLAYER,
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
    local finalExpireDays = expireDays or 7 -- 默认7天过期
    
    local mailData = {
        type = MailMgr.MAIL_TYPE.GLOBAL,
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
    ServerEventManager.Subscribe(MailEventManager.EVENTS.GET_MAIL_LIST, function(event)
        MailEventManager.HandleGetMailList(event)
    end, 100)
    
    -- 读取邮件
    ServerEventManager.Subscribe(MailEventManager.EVENTS.READ_MAIL, function(event)
        MailEventManager.HandleReadMail(event)
    end, 100)
    
    -- 领取邮件附件
    ServerEventManager.Subscribe(MailEventManager.EVENTS.CLAIM_MAIL, function(event)
        MailEventManager.HandleClaimMail(event)
    end, 100)
    
    -- 删除邮件
    ServerEventManager.Subscribe(MailEventManager.EVENTS.DELETE_MAIL, function(event)
        MailEventManager.HandleDeleteMail(event)
    end, 100)
    
    -- 批量领取
    ServerEventManager.Subscribe(MailEventManager.EVENTS.BATCH_CLAIM, function(event)
        MailEventManager.HandleBatchClaim(event)
    end, 100)
    
    -- 删除已读邮件
    ServerEventManager.Subscribe(MailEventManager.EVENTS.DELETE_READ_MAILS, function(event)
        MailEventManager.HandleDeleteReadMails(event)
    end, 100)
    
    gg.log("邮件网络事件处理器注册完成")
end

-- 处理获取邮件列表请求
function MailEventManager.HandleGetMailList(event)
    local player = event.player
    if not player then
        gg.log("获取邮件列表失败：玩家不存在")
        return
    end
    
    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    local result = MailMgr.GetPlayerMailList(player.uin)
    
    if result.success then
        gg.network_channel:fireClient(player.uin, {
            cmd = MailEventManager.EVENTS.MAIL_LIST_UPDATE,
            code = MailEventManager.ERROR_CODES.SUCCESS,
            mailList = result.mailList
        })
    else
        gg.network_channel:fireClient(player.uin, {
            cmd = MailEventManager.EVENTS.MAIL_LIST_UPDATE,
            code = MailEventManager.ERROR_CODES.PLAYER_NOT_FOUND,
            message = result.message or "获取邮件列表失败"
        })
    end
end

-- 处理读取邮件请求
function MailEventManager.HandleReadMail(event)
    local player = event.player
    local mailId = event.mailId
    
    if not player or not mailId then
        gg.log("读取邮件失败：参数无效")
        return
    end
    
    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)     ---@type MailMgr
    local result = MailMgr.ReadMail(player.uin, mailId)
    
    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventManager.EVENTS.READ_MAIL,
        code = result.code,
        message = result.message,
        mailId = mailId
    })
end

-- 处理领取邮件附件请求
function MailEventManager.HandleClaimMail(event)
    local player = event.player
    local mailId = event.mailId
    
    if not player or not mailId then
        gg.log("领取邮件附件失败：参数无效")
        return
    end
    
    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    local result = MailMgr.ClaimMailAttachment(player.uin, mailId)
    
    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventManager.EVENTS.MAIL_CLAIMED,
        code = result.code,
        message = result.message,
        mailId = mailId,
        rewards = result.rewards
    })
end

-- 处理删除邮件请求
function MailEventManager.HandleDeleteMail(event)
    local player = event.player
    local mailId = event.mailId
    
    if not player or not mailId then
        gg.log("删除邮件失败：参数无效")
        return
    end
    
    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr) ---@type MailMgr
    local result = MailMgr.DeleteMail(player.uin, mailId)
    
    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventManager.EVENTS.MAIL_DELETED,
        code = result.code,
        message = result.message,
        mailId = mailId
    })
end

-- 处理批量领取请求
function MailEventManager.HandleBatchClaim(event)
    local player = event.player
    local mailIds = event.mailIds or {}
    
    if not player then
        gg.log("批量领取失败：玩家不存在")
        return
    end
    
    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr)
    local result = MailMgr.BatchClaimMails(player.uin, mailIds)
    
    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventManager.EVENTS.MAIL_CLAIMED,
        code = result.code,
        message = result.message,
        rewards = result.rewards
    })
end

-- 处理删除已读邮件请求
function MailEventManager.HandleDeleteReadMails(event)
    local player = event.player
    
    if not player then
        gg.log("删除已读邮件失败：玩家不存在")
        return
    end
    
    local MailMgr = require(ServerStorage.MSystems.Mail.MailMgr) ---@type MailMgr
    local result = MailMgr.DeleteReadMails(player.uin)
    
    gg.network_channel:fireClient(player.uin, {
        cmd = MailEventManager.EVENTS.MAIL_DELETED,
        code = result.code,
        message = result.message,
        deletedCount = result.deletedCount
    })
end

-- 通知客户端新邮件
function MailEventManager.NotifyNewMail(uin, mailData)
    if not uin or not mailData then
        return
    end
    
    gg.network_channel:fireClient(uin, {
        cmd = MailEventManager.EVENTS.NEW_MAIL_NOTIFY,
        mailData = mailData
    })
    
    gg.log("发送新邮件通知", uin, mailData.title)
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
    
    gg.log("广播新邮件通知", mailData.title)
end

-- 通知邮件列表更新
function MailEventManager.NotifyMailListUpdate(uin, mailList)
    if not uin then
        return
    end
    
    gg.network_channel:fireClient(uin, {
        cmd = MailEventManager.EVENTS.MAIL_LIST_UPDATE,
        code = MailEventManager.ERROR_CODES.SUCCESS,
        mailList = mailList or {}
    })
    
    gg.log("发送邮件列表更新通知", uin)
end

return MailEventManager 