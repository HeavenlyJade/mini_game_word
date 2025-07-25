---@class SkillData
---@field skill string
---@field level number
---@field slot number

---@class SkillDataContainer
---@field skills table<string, SkillData>

---@class SyncPlayerSkillsData
---@field cmd string
---@field uin number
---@field skillData SkillDataContainer --- 服务器返回的加载的技能格式

---@class MailAttachment
---@field name string @ 附件名称
---@field type string @ 附件类型
---@field amount number @ 数量

---@class MailData
---@field id string @ 邮件的唯一ID
---@field title string @ 邮件标题
---@field content string @ 邮件正文
---@field sender string @ 发件人
---@field send_time number @ 发送时间戳
---@field expire_time number @ 过期时间戳
---@field expire_days number @ 过期天数
---@field status number @ 邮件状态 (0: 未读, 1: 已读, 2: 已领取附件)
---@field attachments table<number, MailAttachment> @ 附件列表
---@field has_attachment boolean @ 是否有附件
---@field mail_type string @ 邮件类型 ("系统" 或 "玩家")
---@field is_claimed boolean @ (客户端) 附件是否已领取
---@field is_global_mail boolean @ (客户端) 是否是全局邮件

---@class MailListResponse
---@field cmd string
---@field personal_mails table<string, MailData> @ 个人邮件列表, key是邮件ID
---@field global_mails table<string, MailData> @ 全服邮件列表, key是邮件ID

---@class PlayerMailData
---@field uin number @ 玩家ID
---@field mails table<string, MailData> @ 玩家的个人邮件列表
---@field last_update number @ 最后更新时间戳

---@class GlobalMailCache
---@field mails table<string, MailData> @ 全服邮件列表
---@field last_update number @ 最后更新时间戳

---@class PlayerGlobalMailStatus
---@field status number @ 邮件状态 (0: 未读, 1: 已读, 2: 已领取附件)
---@field is_claimed boolean @ 附件是否已领取

---@class PlayerGlobalMailContainer
---@field uin number @ 玩家ID
---@field statuses table<string, PlayerGlobalMailStatus> @ key是全服邮件ID
---@field last_update number @ 最后更新时间戳

---@class PlayerMailBundle
---@field playerMail PlayerMailData @ 玩家个人邮件数据
---@field globalMailStatus PlayerGlobalMailContainer @ 玩家全服邮件状态数据

---@alias ItemCategory
---| "material"     # 材料类物品
---| "skill"        # 技能类物品  
---| "consumable"   # 消耗品类物品
---| "currency"     # 货币类物品
---| "card"         # 卡片类物品
---| "weapon"       # 武器类物品

---@class BagPosition
---@field c number 背包分类
---@field s number 背包格子

---@class ItemData
---@field itemCategory number 物品类型编号 (1:武器, 2:装备, 3:消耗品, 4:材料, 5:货币)
---@field enhanceLevel number 强化等级
---@field amount number 数量
---@field uuid string 唯一标识
---@field quality  string  品质
---@field level number 等级
---@field pos number 装备位置
---@field itype string 物品类型名称
---@field name string 物品名称
---@field bagPos BagPosition 背包位置
---@field isStackable boolean 是否可堆叠

---@alias BagItems table<ItemCategory, ItemData[]>