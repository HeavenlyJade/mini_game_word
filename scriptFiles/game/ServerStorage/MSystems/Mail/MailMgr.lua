local game = game
local pairs = pairs
local ipairs = ipairs
local type = type
local require = require

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg
local MailCloudDataMgr = require(ServerStorage.MSystems.Mail.MailCloudDataMgr) ---@type MailCloudDataMgr
local MailManager = require(ServerStorage.MSystems.Mail.MailManager) ---@type MailManager
local GlobalMailManager = require(ServerStorage.MSystems.Mail.GlobalMailManager) ---@type GlobalMailManager
local MailEventManager = require(ServerStorage.MSystems.Mail.MailEventManager) ---@type MailEventManager

---@class MailMgr
---@description 统一管理所有在线玩家的邮件数据
local MailMgr = {
    ---@type table<number, MailManager>
    server_player_mail_data = {},
}

---------------------------------------------------------------------------------------------------
--                                      Business Logic
---------------------------------------------------------------------------------------------------

--- 获取玩家邮件列表
function MailMgr.GetPlayerMailList(uin)
    local mail_mgr = MailMgr.GetPlayerMailManager(uin)
    if mail_mgr then
        return true, mail_mgr:GetMailListForClient()
    end
    return false, nil
end

--- 阅读邮件
function MailMgr.ReadMail(uin, mailId)
    local mail_mgr = MailMgr.GetPlayerMailManager(uin)
    if mail_mgr then
        local mail = mail_mgr:GetMailById(mailId)
        if mail then
            mail_mgr:ReadMail(mailId)
            return true, MailEventManager.ERROR_CODES.SUCCESS, "邮件已读"
        else
            return false, MailEventManager.ERROR_CODES.MAIL_NOT_FOUND, "邮件不存在"
        end
    end
    return false, MailEventManager.ERROR_CODES.PLAYER_NOT_FOUND, "玩家未上线"
end

--- 领取邮件附件
function MailMgr.ClaimMailAttachment(uin, mailId)
    local mail_mgr = MailMgr.GetPlayerMailManager(uin)
    if mail_mgr then
        return mail_mgr:ClaimAttachment(mailId)
    end
    return false, MailEventManager.ERROR_CODES.PLAYER_NOT_FOUND, "玩家未上线"
end

--- 删除邮件
function MailMgr.DeleteMail(uin, mailId)
    local mail_mgr = MailMgr.GetPlayerMailManager(uin)
    if mail_mgr then
        local success = mail_mgr:DeleteMail(mailId)
        if success then
            return true, MailEventManager.ERROR_CODES.SUCCESS, "删除成功"
        else
            return false, MailEventManager.ERROR_CODES.MAIL_NOT_FOUND, "邮件不存在或无法删除"
        end
    end
    return false, MailEventManager.ERROR_CODES.PLAYER_NOT_FOUND, "玩家未上线"
end

--- 批量领取邮件附件
function MailMgr.BatchClaimMails(uin, mailIds)
    local mail_mgr = MailMgr.GetPlayerMailManager(uin)
    if mail_mgr then
        if not mailIds or #mailIds == 0 then
            return mail_mgr:ClaimAllAttachments()
        else
            -- (Optional) Implement logic to claim specific mails by ids
            return false, MailEventManager.ERROR_CODES.INVALID_PARAM, "暂不支持领取指定邮件"
        end
    end
    return false, MailEventManager.ERROR_CODES.PLAYER_NOT_FOUND, "玩家未上线"
end

--- 删除所有已读邮件
function MailMgr.DeleteReadMails(uin)
    local mail_mgr = MailMgr.GetPlayerMailManager(uin)
    if mail_mgr then
        local count = mail_mgr:DeleteAllReadMails()
        return true, MailEventManager.ERROR_CODES.SUCCESS, "删除成功", count
    end
    return false, MailEventManager.ERROR_CODES.PLAYER_NOT_FOUND, "玩家未上线", 0
end


---------------------------------------------------------------------------------------------------
--                                      Player Data Management
---------------------------------------------------------------------------------------------------

---获得指定uin玩家的邮件数据
---@param uin number 玩家ID
---@return MailManager|nil 玩家邮件数据
function MailMgr.GetPlayerMailManager(uin)
    return MailMgr.server_player_mail_data[uin]
end

---获取或创建玩家邮件（如果不存在则创建新的）
---@param uin number 玩家ID
---@param player MPlayer|nil 玩家对象
---@return MailManager 玩家邮件数据
function MailMgr.GetOrCreatePlayerMailManager(uin, player)
    local mailManager = MailMgr.server_player_mail_data[uin]
    if not mailManager and player then
        mailManager = MailManager.New(player)
        MailMgr.server_player_mail_data[uin] = mailManager
    end
    return mailManager
end

---玩家上线处理
---@param player MPlayer 玩家对象
function MailMgr.OnPlayerJoin(player)
    local ret, mailManager = MailMgr.LoadPlayerMailFromCloud(player)
    if ret == 0 and mailManager then
        player.mailManager = mailManager
    else
        -- 创建新邮箱
        local newMailManager = MailManager.New(player)
        MailMgr.setPlayerMailData(player.uin, newMailManager)
        player.mailManager = newMailManager
    end

    -- 检查并发送全局邮件
    GlobalMailManager.CheckAndSendGlobalMailsToPlayer(player)
end


---玩家离线处理
---@param uin number 玩家ID
function MailMgr.OnPlayerLeave(uin)
    local mailManager = MailMgr.server_player_mail_data[uin]
    if mailManager then
        -- 保存邮件数据
        if mailManager:IsDirty() then
            mailManager:Save()
        end
        -- 清理内存
        MailMgr.server_player_mail_data[uin] = nil
    end
end

---云读取数据后，设置给玩家
---@param uin number 玩家ID
---@param mailManager MailManager 邮件数据
function MailMgr.setPlayerMailData(uin, mailManager)
    MailMgr.server_player_mail_data[uin] = mailManager
end

---从云端读取玩家邮件数据
---@param player MPlayer 玩家对象
---@return number, MailManager 返回值: 0表示成功, 1表示失败, 邮件数据
function MailMgr.LoadPlayerMailFromCloud(player)
    local ret, mailManager = MailCloudDataMgr.ReadPlayerMail(player)
    if ret == 0 and mailManager then
        MailMgr.setPlayerMailData(player.uin, mailManager)
    end
    return ret, mailManager
end

---------------------------------------------------------------------------------------------------
--                                      API for other systems
---------------------------------------------------------------------------------------------------

---给单个或多个玩家发送邮件
---@param uids number|table<number,boolean> 玩家UIN或UIN表
---@param title string 邮件标题
---@param content string 邮件内容
---@param items table|nil 附件, 格式: {{id=itemId, num=itemNum}, ...}
---@param from string|nil 发件人, 默认为 "系统"
function MailMgr.SendMailToPlayers(uids, title, content, items, from)
    if type(uids) == "number" then
        uids = {[uids] = true}
    end

    for uin, _ in pairs(uids) do
        local mailManager = MailMgr.GetPlayerMailManager(uin)
        if mailManager then
            mailManager:AddMail(title, content, items, from)
        else
            -- 离线玩家
            MailCloudDataMgr.AddMailToOfflinePlayer(uin, title, content, items, from)
        end
    end
end

---发送全局邮件（给所有玩家）
---@param title string 邮件标题
---@param content string 邮件内容
---@param items table|nil 附件
---@param from string|nil 发件人
function MailMgr.SendGlobalMail(title, content, items, from)
    GlobalMailManager.SendGlobalMail(title, content, items, from)
end

return MailMgr 