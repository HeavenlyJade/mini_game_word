local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Common.Untils.ClassMgr) ---@type ClassMgr
local common_const = require(MainStorage.Code.Common.GameConfig.MConst) ---@type common_const

local MailEventConfig = require(MainStorage.Code.Common.EventConf.EventMail)


---@class Mail
local _Mail = ClassMgr.Class("Mail")

-- 邮件状态常量（兼容MailEventConfig和内置状态）
_Mail.STATUS = {
    UNREAD = 0,      -- 未读
    READ = 1,        -- 已读
    CLAIMED = 2,     -- 已领取附件
    DELETED = 3      -- 已删除
}

-- 如果MailEventConfig存在，使用其状态常量
if MailEventConfig and MailEventConfig.STATUS then
    _Mail.STATUS = MailEventConfig.STATUS
end

-- 邮件类型常量
_Mail.TYPE = {
    PERSONAL = "personal",  -- 个人邮件
    SYSTEM = "system",     -- 系统邮件
    GLOBAL = "global"      -- 全服邮件
}

-- 默认过期天数（优先使用MailEventConfig）
_Mail.DEFAULT_EXPIRE_DAYS =  MailEventConfig.DEFAULT_EXPIRE_DAYS


--- 初始化邮件对象
---@param data MailData 邮件数据
function _Mail:OnInit(data)
    data = data or {}
    
    -- 基本信息
    self.id = data.id or ""
    self.title = data.title 
    self.content = data.content 
    self.sender = data.sender 
    -- 时间相关（支持snake_case和camelCase）
    self.send_time =  data.send_time or os.time()
    self.expire_days = data.expire_days or self.DEFAULT_EXPIRE_DAYS
    self.expire_time = data.expire_time or (self.send_time + (self.expire_days * 86400))
    -- 状态相关
    self.status = data.status
    -- 附件相关
    self.attachments = data.attachments or {}
    self.hasAttachment = self:CalculateHasAttachment()
    self.mail_type = data.mail_type
    self.has_attachment = data.has_attachment
    self.is_claimed = data.is_claimed
    self.is_global_mail = data.is_global_mail
end

--- 状态检查方法 --------------------------------------------------------

--- 检查邮件是否已过期
---@return boolean 是否已过期
function _Mail:IsExpired()
    return self.expire_time and self.expire_time < os.time()
end

--- 检查邮件是否已读
---@return boolean 是否已读
function _Mail:IsRead()
    return self.status >= self.STATUS.READ
end

--- 检查邮件是否已领取附件
---@return boolean 是否已领取附件
function _Mail:IsClaimed()
    return self.status >= self.STATUS.CLAIMED
end

--- 检查邮件是否已删除
---@return boolean 是否已删除
function _Mail:IsDeleted()
    return self.status >= self.STATUS.DELETED
end

--- 检查邮件是否有效（未过期且未删除）
---@return boolean 是否有效
function _Mail:IsValid()
    return not self:IsExpired() and not self:IsDeleted()
end

--- 检查是否可以领取附件
---@return boolean 是否可以领取附件
function _Mail:CanClaimAttachment()
    return self.hasAttachment and not self:IsClaimed() and self:IsValid()
end

--- 附件相关方法 --------------------------------------------------------

--- 计算是否有附件
---@return boolean 是否有附件
function _Mail:CalculateHasAttachment()
    return self.attachments and #self.attachments > 0
end

--- 添加附件
---@param attachment MailAttachment 附件对象
function _Mail:AddAttachment(attachment)
    if not self.attachments then
        self.attachments = {}
    end
    
    table.insert(self.attachments, attachment)
    self.hasAttachment = self:CalculateHasAttachment()
    self.has_attachment = self.hasAttachment  -- 兼容snake_case
    
    gg.log("添加邮件附件", self.id, attachment.name or attachment.id, attachment.count or attachment.amount or 1)
end

--- 移除附件（从MailBase迁移）
---@param index number 附件索引
function _Mail:RemoveAttachment(index)
    if self.attachments and self.attachments[index] then
        local removed = table.remove(self.attachments, index)
        self.hasAttachment = self:CalculateHasAttachment()
        self.has_attachment = self.hasAttachment  -- 兼容snake_case

        gg.log("移除邮件附件", self.id, removed.name)
        return removed
    end
    return nil
end

--- 获取附件列表
---@return table<number, MailAttachment> 附件列表
function _Mail:GetAttachments()
    return self.attachments or {}
end

--- 清空所有附件
function _Mail:ClearAttachments()
    self.attachments = {}
    self.hasAttachment = false
    self.has_attachment = false  -- 兼容snake_case
    gg.log("清空邮件附件", self.id)
end

--- 状态管理方法 --------------------------------------------------------

--- 标记为已读
function _Mail:MarkAsRead()
    if self.status < self.STATUS.READ then
        self.status = self.STATUS.READ
        gg.log("邮件标记为已读", self.id)
        return true
    end
    return false
end

--- 标记为已领取附件
function _Mail:MarkAsClaimed()
    if self.hasAttachment and self.status < self.STATUS.CLAIMED then
        self.status = self.STATUS.CLAIMED
        gg.log("邮件附件已领取", self.id)
        return true
    end
    return false
end

--- 标记为已删除
function _Mail:MarkAsDeleted()
    if self.status < self.STATUS.DELETED then
        self.status = self.STATUS.DELETED
        gg.log("邮件标记为已删除", self.id)
        return true
    end
    return false
end

--- 数据转换方法 --------------------------------------------------------

--- 转换为客户端数据格式
---@return MailData 客户端邮件数据
function _Mail:ToClientData()
    return {
        id = self.id,
        title = self.title,
        content = self.content,
        sender = self.sender,
        send_time = self.send_time,
        expire_time = self.expire_time,
        expire_days = self.expire_days,
        status = self.status,
        attachments = self.attachments,
        has_attachment = self.hasAttachment,
        mail_type = self.mail_type,
        is_claimed = self:IsClaimed(),
        is_global_mail = self.is_global_mail
    }
end

--- 转换为存储数据格式
---@return MailData 存储邮件数据
function _Mail:ToStorageData()
    return {
        id = self.id,
        title = self.title,
        content = self.content,
        sender = self.sender,
        send_time = self.send_time,
        expire_time = self.expire_time,
        expire_days = self.expire_days,
        status = self.status,
        attachments = self.attachments,
        has_attachment = self.hasAttachment,
        mail_type = self.mail_type
    }
end

--- 从存储数据更新
---@param data MailData 存储数据
function _Mail:UpdateFromStorageData(data)
    self.status = data.status or self.status
    self.attachments = data.attachments or self.attachments
    self.hasAttachment = self:CalculateHasAttachment()
    self.has_attachment = self.hasAttachment  -- 兼容snake_case
end

--- 工具方法（从MailBase迁移）--------------------------------------------------------



--- 获取格式化的发送时间
---@return string 格式化时间
function _Mail:GetFormattedSendTime()
    return tostring(os.date("%Y-%m-%d %H:%M:%S", self.send_time))
end

--- 获取格式化的过期时间
---@return string 格式化时间
function _Mail:GetFormattedExpireTime()
    return tostring(os.date("%Y-%m-%d %H:%M:%S", self.expire_time))
end

--- 获取剩余有效时间（秒）
---@return number 剩余时间，负数表示已过期
function _Mail:GetRemainingTime()
    return self.expire_time - os.time()
end

--- 验证邮件数据完整性
---@return boolean, string 是否有效，错误信息
function _Mail:Validate()
    if not self.id or self.id == "" then
        return false, "邮件ID不能为空"
    end

    if not self.title or self.title == "" then
        return false, "邮件标题不能为空"
    end

    if not self.send_time or self.send_time <= 0 then
        return false, "发送时间无效"
    end

    if not self.expire_time or self.expire_time <= 0 then
        return false, "过期时间无效"
    end

    if self.expire_time <= self.send_time then
        return false, "过期时间不能早于发送时间"
    end

    return true, ""
end


--- 静态工具方法 --------------------------------------------------------

--- 生成邮件ID
---@param prefix string 前缀
---@return string 邮件ID
function _Mail.GenerateMailId(prefix)
    local timestamp = os.time()
    local random = math.random(10000, 99999)
    return (prefix or "mail_") .. timestamp .. "_" .. random
end

--- 创建系统邮件数据
---@param title string 标题
---@param content string 内容
---@param attachments table<number, MailAttachment> 附件列表
---@return MailData 邮件数据
function _Mail.CreateSystemMailData(title, content, attachments)
    return {
        id = _Mail.GenerateMailId("mail_sys_"),
        title = title,
        content = content,
        sender = "系统",
        attachments = attachments or {},
        mail_type = _Mail.TYPE.SYSTEM,
        send_time = os.time()
    }
end

--- 创建个人邮件数据
---@param title string 标题
---@param content string 内容
---@param sender string 发件人
---@param attachments table<number, MailAttachment> 附件列表
---@return MailData 邮件数据
function _Mail.CreatePersonalMailData(title, content, sender, attachments)
    return {
        id = _Mail.GenerateMailId("mail_p_"),
        title = title,
        content = content,
        sender = sender or "玩家",
        attachments = attachments or {},
        mail_type = _Mail.TYPE.PERSONAL,
        send_time = os.time()
    }
end

return _Mail