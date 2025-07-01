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
local Mail = require(ServerStorage.MSystems.Mail.Mail) ---@type Mail
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
--                                      初始化
---------------------------------------------------------------------------------------------------

--- 初始化邮件服务
function MailMgr:Init()
    -- 初始化全局邮件管理器
    GlobalMailManager:OnInit()
    
    -- 挂载到全局gg对象，方便其他系统访问
    MServerDataManager.MailMgr = self
    
    gg.log("邮件服务初始化完成")
    return self
end

---------------------------------------------------------------------------------------------------
--                                      数据管理层 (原MailMgr功能)
---------------------------------------------------------------------------------------------------

--- 从云端加载玩家邮件数据包
---@param uin number 玩家ID
---@return table|nil 邮件数据包
function MailMgr:LoadPlayerMailFromCloud(uin)
    if not uin then
        gg.log("加载玩家邮件失败：UIN为空")
        return nil
    end
    
    local bundle = {}
    
    -- 加载个人邮件数据
    local playerMailKey = self.CLOUD_KEYS.PLAYER_MAIL .. uin
    local success1, playerMailData = cloudService:GetTableOrEmpty(playerMailKey)
    
    if success1 and playerMailData and playerMailData.mails then
        bundle.playerMail = playerMailData
        gg.log("加载玩家个人邮件成功", uin, "邮件数量:", self:_CountTable(playerMailData.mails))
    else
        bundle.playerMail = {
            uin = uin,
            mails = {},
            last_update = os.time()
        }
        gg.log("创建玩家个人邮件默认数据", uin)
    end
    
    -- 加载全服邮件状态数据
    local globalStatusKey = self.CLOUD_KEYS.GLOBAL_MAIL_STATUS .. uin
    local success2, globalStatusData = cloudService:GetTableOrEmpty(globalStatusKey)
    
    if success2 and globalStatusData and globalStatusData.statuses then
        bundle.globalMailStatus = globalStatusData
        gg.log("加载玩家全服邮件状态成功", uin)
    else
        bundle.globalMailStatus = {
            uin = uin,
            statuses = {},
            last_update = os.time()
        }
        gg.log("创建玩家全服邮件状态默认数据", uin)
    end
    
    return bundle
end

--- 保存玩家邮件数据包到云端
---@param uin number 玩家ID
---@param bundle table 邮件数据包
---@return boolean 是否成功
function MailMgr:SavePlayerMailToCloud(uin, bundle)
    if not uin or not bundle then
        gg.log("保存玩家邮件失败：参数无效")
        return false
    end
    
    local success = true
    local now = os.time()
    
    -- 保存个人邮件数据
    if bundle.playerMail then
        bundle.playerMail.last_update = now
        local playerMailKey = self.CLOUD_KEYS.PLAYER_MAIL .. uin
        
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
        local globalStatusKey = self.CLOUD_KEYS.GLOBAL_MAIL_STATUS .. uin
        
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
function MailMgr:GetPlayerMailData(uin)
    return self.server_player_mail_data[uin]
end

---设置玩家邮件数据到缓存
---@param uin number 玩家ID
---@param mailData table 邮件数据
function MailMgr:SetPlayerMailData(uin, mailData)
    self.server_player_mail_data[uin] = mailData
    gg.log("玩家邮件数据已缓存", uin)
end

---玩家上线处理
---@param player MPlayer 玩家对象
function MailMgr:OnPlayerJoin(player)
    if not player or not player.uin then
        gg.log("玩家上线处理失败：玩家对象无效")
        return
    end
    
    local uin = player.uin
    gg.log("开始处理玩家邮件上线", uin)
    
    -- 从云端加载邮件数据
    local mailBundle = self:LoadPlayerMailFromCloud(uin)
    if mailBundle then
        -- 缓存到内存
        self:SetPlayerMailData(uin, mailBundle)
        
        gg.log("玩家邮件数据加载完成", uin)
        
        -- 同步全服邮件状态
        self:SyncGlobalMailsForPlayer(uin)
        
        -- 检查并发送全局邮件通知
        -- 延迟一点确保数据完全同步
        GlobalMailManager:CheckAndSendGlobalMailsToPlayer(player)
    else
        gg.log("玩家邮件数据加载失败", uin)
    end
end

---玩家离线处理
---@param uin number 玩家ID
function MailMgr:OnPlayerLeave(uin)
    local mailData = self.server_player_mail_data[uin]
    if mailData then
        -- 保存邮件数据到云端
        self:SavePlayerMailToCloud(uin, mailData)
        
        -- 清理内存缓存
        self.server_player_mail_data[uin] = nil
        gg.log("玩家邮件数据已保存并清理", uin)
    end
end

---------------------------------------------------------------------------------------------------
--                                      业务逻辑层 (原MailManager功能)
---------------------------------------------------------------------------------------------------

--- 生成邮件ID
---@param prefix string 前缀，如"mail_p_"或"mail_g_"
---@return string 生成的邮件ID
function MailMgr:GenerateMailId(prefix)
    local timestamp = os.time()
    local random = math.random(10000, 99999)
    return prefix .. timestamp .. "_" .. random
end

--- 同步玩家的全服邮件状态
---@param uin number 玩家ID
---@return boolean 是否有数据更新
function MailMgr:SyncGlobalMailsForPlayer(uin)
    local mailData = self:GetPlayerMailData(uin)
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
                status = self.MAIL_STATUS.UNREAD,
                is_claimed = false
            }
            updated = true
            gg.log("为玩家", uin, "同步新的全服邮件:", mailId)
        end
    end

    if updated then
        -- 如果有更新，更新时间戳以便保存
        playerGlobalStatus.last_update = os.time()
    end

    return updated
end

--- 获取个人邮件列表
---@param uin number 玩家ID
---@return table 邮件列表
function MailMgr:GetPersonalMailList(uin)
    local mailData = self:GetPlayerMailData(uin)
    if not mailData or not mailData.playerMail or not mailData.playerMail.mails then
        return {}
    end

    local playerMails = mailData.playerMail.mails
    local result = {}

    for mailId, mail in pairs(playerMails) do
        local mailCopy = {
            id = mail.id,
            title = mail.title,
            content = mail.content,
            send_time = mail.send_time,
            expire_time = mail.expire_time,
            status = mail.status,
            mail_type = mail.mail_type,
            has_attachment = mail.attachments and #mail.attachments > 0,
            sender = mail.sender,
            attachments = mail.attachments,
            is_claimed = (mail.status == self.MAIL_STATUS.CLAIMED),
            is_global_mail = false
        }
        result[mailId] = mailCopy
    end

    return result
end

--- 领取个人邮件附件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean, string, table, number
function MailMgr:ClaimPersonalMail(uin, mailId)
    local mailData = self:GetPlayerMailData(uin)
    if not mailData or not mailData.playerMail then
        return false, "玩家邮件数据不存在", nil, self.ERROR_CODE.PLAYER_NOT_FOUND
    end

    local playerMailData = mailData.playerMail.mails[mailId]
    if not playerMailData then
        return false, "邮件不存在", nil, self.ERROR_CODE.MAIL_NOT_FOUND
    end

    local mailObject = Mail.New(playerMailData)

    if not mailObject:CanClaimAttachment() then
        if mailObject:IsExpired() then
            return false, "邮件已过期", nil, self.ERROR_CODE.MAIL_EXPIRED
        end
        if not mailObject.has_attachment then
            return false, "邮件没有附件", nil, self.ERROR_CODE.MAIL_NO_ATTACHMENT
        end
        if mailObject:IsClaimed() then
            return false, "附件已领取", nil, self.ERROR_CODE.MAIL_ALREADY_CLAIMED
        end
        return false, "无法领取附件", nil, self.ERROR_CODE.SYSTEM_ERROR
    end

    -- 更新邮件状态
    mailObject:MarkAsClaimed()
    mailData.playerMail.mails[mailId] = mailObject:ToStorageData()
    mailData.playerMail.last_update = os.time()

    gg.log("个人邮件状态已更新为已领取", mailId)
    return true, "领取成功", mailObject:GetAttachments()
end

--- 删除个人邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean, string
function MailMgr:DeletePersonalMail(uin, mailId)
    local mailData = self:GetPlayerMailData(uin)
    if not mailData or not mailData.playerMail then
        return false, "玩家邮件数据不存在"
    end

    local playerMailData = mailData.playerMail.mails[mailId]
    if not playerMailData then
        return true, "邮件已删除"
    end

    local mailObject = Mail.New(playerMailData)

    if mailObject:CanClaimAttachment() then
        return false, "请先领取附件"
    end

    gg.log("删除个人邮件", uin, mailId, playerMailData.title)
    
    mailData.playerMail.mails[mailId] = nil
    mailData.playerMail.last_update = os.time()

    return true, "邮件已删除"
end

---------------------------------------------------------------------------------------------------
--                                      外部API接口
---------------------------------------------------------------------------------------------------

--- 获取玩家邮件列表
function MailMgr:GetPlayerMailList(uin)
    local mailData = self:GetPlayerMailData(uin)
    if mailData then
        return true, self:GetPersonalMailList(uin)
    end
    return false, nil
end

--- 领取邮件附件
function MailMgr:ClaimMailAttachment(uin, mailId)
    local mailData = self:GetPlayerMailData(uin)
    if mailData then
        local success, message, attachments, errorCode = self:ClaimPersonalMail(uin, mailId)
        if success then
            self:SavePlayerMailToCloud(uin, mailData)
        end
        return success, errorCode, message, attachments
    end
    return false, self.ERROR_CODE.PLAYER_NOT_FOUND, "玩家未上线"
end

--- 删除邮件
function MailMgr:DeleteMail(uin, mailId)
    local mailData = self:GetPlayerMailData(uin)
    if mailData then
        local success, message = self:DeletePersonalMail(uin, mailId)
        if success then
            self:SavePlayerMailToCloud(uin, mailData)
            return true, self.ERROR_CODE.SUCCESS, "删除成功"
        else
            return false, self.ERROR_CODE.MAIL_NOT_FOUND, message
        end
    end
    return false, self.ERROR_CODE.PLAYER_NOT_FOUND, "玩家未上线"
end

--- 发送全服邮件
---@param title string 邮件标题
---@param content string 邮件内容
---@param items table|nil 附件
---@param from string|nil 发件人
function MailMgr:SendGlobalMail(title, content, items, from)
    local expireDays = 7
    return GlobalMailManager:AddGlobalMail({
        title = title,
        content = content,
        sender = from or "系统",
        send_time = os.time(),
        expire_time = os.time() + expireDays * 86400,
        expire_days = expireDays,
        status = self.MAIL_STATUS.UNREAD,
        attachments = items or {},
        has_attachment = items and #items > 0,
        mail_type = self.MAIL_TYPE.SYSTEM
    })
end

--- 读取邮件（标记为已读）
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean, number, string
function MailMgr:ReadMail(uin, mailId)
    local mailData = self:GetPlayerMailData(uin)
    if not mailData then
        return false, self.ERROR_CODE.PLAYER_NOT_FOUND, "玩家未上线"
    end

    -- 检查个人邮件
    if mailData.playerMail and mailData.playerMail.mails[mailId] then
        local mail = mailData.playerMail.mails[mailId]
        -- 这里可以添加标记已读的逻辑，如果需要的话
        return true, self.ERROR_CODE.SUCCESS, "邮件已读"
    end

    -- 检查全服邮件
    if mailData.globalMailStatus and mailData.globalMailStatus.statuses[mailId] then
        local status = mailData.globalMailStatus.statuses[mailId]
        if status.status == self.MAIL_STATUS.UNREAD then
            -- 这里可以更新全服邮件状态为已读，如果需要的话
        end
        return true, self.ERROR_CODE.SUCCESS, "邮件已读"
    end

    return false, self.ERROR_CODE.MAIL_NOT_FOUND, "邮件不存在"
end

--- 批量领取邮件
---@param uin number 玩家ID
---@param mailIds table 邮件ID列表
---@return boolean, number, string, table
function MailMgr:BatchClaimMails(uin, mailIds)
    local mailData = self:GetPlayerMailData(uin)
    if not mailData then
        return false, self.ERROR_CODE.PLAYER_NOT_FOUND, "玩家未上线", nil
    end

    local allRewards = {}
    local successCount = 0

    -- 遍历所有邮件ID进行批量领取
    for _, mailId in ipairs(mailIds or {}) do
        local success, _, _, rewards = self:ClaimPersonalMail(uin, mailId)
        if success and rewards then
            successCount = successCount + 1
            -- 合并奖励
            for _, reward in ipairs(rewards) do
                table.insert(allRewards, reward)
            end
        end
    end

    if successCount > 0 then
        -- 保存数据
        self:SavePlayerMailToCloud(uin, mailData)
        return true, self.ERROR_CODE.SUCCESS, string.format("成功领取%d封邮件", successCount), allRewards
    else
        return false, self.ERROR_CODE.MAIL_NOT_FOUND, "没有可领取的邮件", nil
    end
end

--- 删除已读邮件
---@param uin number 玩家ID
---@return boolean, number, string, number
function MailMgr:DeleteReadMails(uin)
    local mailData = self:GetPlayerMailData(uin)
    if not mailData or not mailData.playerMail then
        return false, self.ERROR_CODE.PLAYER_NOT_FOUND, "玩家未上线", 0
    end

    local deletedCount = 0
    local mailsToDelete = {}

    -- 收集需要删除的已读邮件
    for mailId, mail in pairs(mailData.playerMail.mails) do
        local mailObject = Mail.New(mail)
        -- 删除已读且没有未领取附件的邮件
        if mail.status == self.MAIL_STATUS.CLAIMED or (mail.status ~= self.MAIL_STATUS.UNREAD and not mailObject:CanClaimAttachment()) then
            table.insert(mailsToDelete, mailId)
        end
    end

    -- 执行删除
    for _, mailId in ipairs(mailsToDelete) do
        mailData.playerMail.mails[mailId] = nil
        deletedCount = deletedCount + 1
    end

    if deletedCount > 0 then
        mailData.playerMail.last_update = os.time()
        self:SavePlayerMailToCloud(uin, mailData)
    end

    return true, self.ERROR_CODE.SUCCESS, string.format("删除了%d封已读邮件", deletedCount), deletedCount
end

---------------------------------------------------------------------------------------------------
--                                      工具方法
---------------------------------------------------------------------------------------------------

--- 计算表中元素数量
---@param t table 表
---@return number 元素数量
function MailMgr:_CountTable(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

return MailMgr