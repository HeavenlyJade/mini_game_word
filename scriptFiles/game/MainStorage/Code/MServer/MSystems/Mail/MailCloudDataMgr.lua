local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg
local cloudService = game:GetService("CloudService") ---@type CloudService

---@class MailCloudDataMgr 邮件云数据管理器
local MailCloudDataMgr = {}

-- 云存储键前缀
local CLOUD_KEYS = {
    PLAYER_MAIL = "mail_player_",        -- 玩家个人邮件
    GLOBAL_MAIL = "mail_global",         -- 全服邮件
    GLOBAL_MAIL_STATUS = "mail_global_status_" -- 玩家全服邮件状态
}

--- 加载玩家邮件数据
---@param uin number 玩家ID
---@return table|nil 邮件数据
function MailCloudDataMgr.LoadPlayerMailData(uin)
    if not uin then
        gg.log("加载玩家邮件数据失败：玩家ID为空")
        return nil
    end
    
    local key = CLOUD_KEYS.PLAYER_MAIL .. uin
    local success, data = cloudService:GetTableOrEmpty(key)
    
    if success and data and data.mails then
        gg.log("加载玩家邮件数据成功", uin, "邮件数量:", #(data.mails or {}))
        return data
    else
        -- 创建默认邮件数据
        local defaultData = {
            uin = uin,
            mails = {},
            lastUpdate = os.time()
        }
        gg.log("创建玩家邮件默认数据", uin)
        return defaultData
    end
end

--- 保存玩家邮件数据
---@param uin number 玩家ID
---@param mailData table 邮件数据
---@return boolean 是否成功
function MailCloudDataMgr.SavePlayerMailData(uin, mailData)
    if not uin or not mailData then
        gg.log("保存玩家邮件数据失败：参数无效")
        return false
    end
    
    -- 更新时间戳
    mailData.lastUpdate = os.time()
    
    local key = CLOUD_KEYS.PLAYER_MAIL .. uin
    
    -- 异步保存到云存储
    cloudService:SetTableAsync(key, mailData, function(success)
        if success then
            gg.log("保存玩家邮件数据成功", uin)
        else
            gg.log("保存玩家邮件数据失败", uin)
        end
    end)
    
    return true
end

--- 加载全服邮件数据
---@return table 全服邮件数据
function MailCloudDataMgr.LoadGlobalMailData()
    local key = CLOUD_KEYS.GLOBAL_MAIL
    local success, data = cloudService:GetTableOrEmpty(key)
    
    if success and data and data.mails then
        gg.log("加载全服邮件数据成功，邮件数量:", MailCloudDataMgr._CountTable(data.mails))
        return data
    else
        -- 创建默认全服邮件数据
        local defaultData = {
            mails = {},
            lastUpdate = os.time()
        }
        gg.log("创建全服邮件默认数据")
        return defaultData
    end
end

--- 保存全服邮件数据
---@param globalMailData table 全服邮件数据
---@return boolean 是否成功
function MailCloudDataMgr.SaveGlobalMailData(globalMailData)
    if not globalMailData then
        gg.log("保存全服邮件数据失败：数据为空")
        return false
    end
    
    -- 更新时间戳
    globalMailData.lastUpdate = os.time()
    
    local key = CLOUD_KEYS.GLOBAL_MAIL
    
    -- 异步保存到云存储
    cloudService:SetTableAsync(key, globalMailData, function(success)
        if success then
            gg.log("保存全服邮件数据成功")
        else
            gg.log("保存全服邮件数据失败")
        end
    end)
    
    return true
end

--- 加载玩家全服邮件状态数据
---@param uin number 玩家ID
---@return table 全服邮件状态数据
function MailCloudDataMgr.LoadPlayerGlobalMailStatus(uin)
    if not uin then
        gg.log("加载玩家全服邮件状态失败：玩家ID为空")
        return nil
    end
    
    local key = CLOUD_KEYS.GLOBAL_MAIL_STATUS .. uin
    local success, data = cloudService:GetTableOrEmpty(key)
    
    if success and data and data.statuses then
        gg.log("加载玩家全服邮件状态成功", uin)
        return data
    else
        -- 创建默认状态数据
        local defaultData = {
            uin = uin,
            statuses = {},
            lastUpdate = os.time()
        }
        gg.log("创建玩家全服邮件状态默认数据", uin)
        return defaultData
    end
end

--- 保存玩家全服邮件状态数据
---@param uin number 玩家ID
---@param statusData table 状态数据
---@return boolean 是否成功
function MailCloudDataMgr.SavePlayerGlobalMailStatus(uin, statusData)
    if not uin or not statusData then
        gg.log("保存玩家全服邮件状态失败：参数无效")
        return false
    end
    
    -- 更新时间戳
    statusData.lastUpdate = os.time()
    
    local key = CLOUD_KEYS.GLOBAL_MAIL_STATUS .. uin
    
    -- 异步保存到云存储
    cloudService:SetTableAsync(key, statusData, function(success)
        if success then
            gg.log("保存玩家全服邮件状态成功", uin)
        else
            gg.log("保存玩家全服邮件状态失败", uin)
        end
    end)
    
    return true
end

--- 批量加载玩家邮件数据包（个人邮件 + 全服邮件状态）
---@param uin number 玩家ID
---@return table 邮件数据包
function MailCloudDataMgr.LoadPlayerMailBundle(uin)
    if not uin then
        gg.log("批量加载玩家邮件数据包失败：玩家ID为空")
        return nil
    end
    
    local bundle = {}
    
    -- 加载个人邮件数据
    bundle.playerMail = MailCloudDataMgr.LoadPlayerMailData(uin)
    
    -- 加载全服邮件状态数据
    bundle.globalMailStatus = MailCloudDataMgr.LoadPlayerGlobalMailStatus(uin)
    
    gg.log("批量加载玩家邮件数据包完成", uin)
    return bundle
end

--- 批量保存玩家邮件数据包
---@param uin number 玩家ID
---@param bundle table 邮件数据包
---@return boolean 是否成功
function MailCloudDataMgr.SavePlayerMailBundle(uin, bundle)
    if not uin or not bundle then
        gg.log("批量保存玩家邮件数据包失败：参数无效")
        return false
    end
    
    local success = true
    
    -- 保存个人邮件数据
    if bundle.playerMail then
        local result = MailCloudDataMgr.SavePlayerMailData(uin, bundle.playerMail)
        success = success and result
    end
    
    -- 保存全服邮件状态数据
    if bundle.globalMailStatus then
        local result = MailCloudDataMgr.SavePlayerGlobalMailStatus(uin, bundle.globalMailStatus)
        success = success and result
    end
    
    gg.log("批量保存玩家邮件数据包", success and "成功" or "失败", uin)
    return success
end

--- 清理过期邮件数据
---@param uin number 玩家ID
---@return number 清理数量
function MailCloudDataMgr.CleanExpiredMails(uin)
    local mailData = MailCloudDataMgr.LoadPlayerMailData(uin)
    if not mailData or not mailData.mails then
        return 0
    end
    
    local currentTime = os.time()
    local cleanedCount = 0
    local newMails = {}
    
    for mailId, mail in pairs(mailData.mails) do
        local Mail = require(ServerStorage.MSystems.Mail.Mail)
        local mailObj = Mail.New(mail)
        
        if mailObj:IsValid() then
            newMails[mailId] = mail
        else
            cleanedCount = cleanedCount + 1
            gg.log("清理过期邮件", uin, mailId)
        end
    end
    
    if cleanedCount > 0 then
        mailData.mails = newMails
        MailCloudDataMgr.SavePlayerMailData(uin, mailData)
        gg.log("清理过期邮件完成", uin, "清理数量:", cleanedCount)
    end
    
    return cleanedCount
end

--- 获取玩家邮件统计信息
---@param uin number 玩家ID
---@return table 统计信息
function MailCloudDataMgr.GetPlayerMailStats(uin)
    local mailData = MailCloudDataMgr.LoadPlayerMailData(uin)
    if not mailData or not mailData.mails then
        return {
            totalCount = 0,
            unreadCount = 0,
            claimableCount = 0
        }
    end
    
    local totalCount = 0
    local unreadCount = 0
    local claimableCount = 0
    
    local Mail = require(ServerStorage.MSystems.Mail.Mail)
    
    for _, mail in pairs(mailData.mails) do
        local mailObj = Mail.New(mail)
        if mailObj:IsValid() then
            totalCount = totalCount + 1
            
            if not mailObj:IsRead() then
                unreadCount = unreadCount + 1
            end
            
            if mailObj:CanClaimAttachment() then
                claimableCount = claimableCount + 1
            end
        end
    end
    
    return {
        totalCount = totalCount,
        unreadCount = unreadCount,
        claimableCount = claimableCount
    }
end

--- 工具方法：计算表中元素数量
---@param t table 表
---@return number 元素数量
function MailCloudDataMgr._CountTable(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

--- 检查云存储服务是否可用
---@return boolean 是否可用
function MailCloudDataMgr.IsCloudServiceAvailable()
    return cloudService ~= nil
end

--- 测试云存储连接
---@return boolean 是否连接正常
function MailCloudDataMgr.TestCloudConnection()
    if not MailCloudDataMgr.IsCloudServiceAvailable() then
        return false
    end
    
    local testKey = "mail_test_" .. os.time()
    local testData = { test = true, timestamp = os.time() }
    
    local success = pcall(function()
        cloudService:SetTableAsync(testKey, testData, function(result)
            gg.log("云存储连接测试", result and "成功" or "失败")
        end)
    end)
    
    return success
end

return MailCloudDataMgr 