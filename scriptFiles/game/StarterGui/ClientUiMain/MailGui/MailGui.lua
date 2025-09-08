local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local MailEventConfig = require(MainStorage.Code.Event.EventMail) ---@type MailEventConfig
local TimeUtils = require(MainStorage.Code.Untils.TimeUntils) ---@type TimeUtils
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class NewMailNotificationPayload
---@field cmd string 事件命令
---@field mail_info MailData 新邮件的详细数据

local uiConfig = {
    uiName = "MailGui",
    layer = -1,
    hideOnInit = true,
    closeHuds = false,  -- 设置为false，不隐藏layer=0的界面
}

-- 邮件类型常量
local MAIL_TYPE = {
    PLAYER = "玩家",
    SYSTEM = "系统"
}

---@class MailGui:ViewBase
local MailGui = ClassMgr.Class("MailGui", ViewBase)

---@override
function MailGui:OnInit(node, config)
    -- UI组件初始化
    self.closeButton = self:Get("关闭", ViewButton) ---@type ViewButton
    self.mailCategoryList = self:Get("邮箱分类", ViewList) ---@type ViewList
    self.mailBackground = self:Get("邮箱背景", ViewComponent) ---@type ViewComponent
    self.mailListFrame = self:Get("邮箱背景/邮件列表框", ViewComponent) ---@type ViewComponent
    self.mailSystemButtom =    self:Get("邮箱分类/系统邮件", ViewButton) ---@type ViewButton
    self.mailPlayerButtom =    self:Get("邮箱分类/玩家邮件", ViewButton) ---@type ViewButton

    -- 邮件内容面板
    self.mailContentPanel = self:Get("邮箱背景/邮件内容", ViewComponent) ---@type ViewComponent


    -- 功能按钮 (基于邮件内容面板)
    self.claimButton = self:Get("邮箱背景/邮件内容/领取", ViewButton) ---@type ViewButton
    self.batchClaimButton = self:Get("邮箱背景/一键领取", ViewButton) ---@type ViewButton
    self.deleteButton = self:Get("邮箱背景/删除邮件", ViewButton) ---@type ViewButton

    -- 奖励显示器
    self.rewardDisplay = self:Get("邮箱背景/邮件内容/附件", ViewComponent) ---@type ViewComponent
    self.rewardListTemplate = self:Get("邮箱背景/邮件内容/附件/附件模板", ViewList) ---@type ViewList
    self.rewardItemTemplate = self:Get("邮箱背景/邮件内容/附件/附件模板/素材_1", ViewComponent) ---@type ViewComponent

    -- 邮件列表及模板
    self.mailItemTemplateList = self:Get("邮箱背景/邮件列表框/模板", ViewList) ---@type ViewList

    self.mailItemTemplate = self:Get("邮箱背景/邮件列表框/模板/邮件_1", ViewComponent)
    self.mailSystemList = self:Get("邮箱背景/邮件列表框/系统邮件", ViewList) ---@type ViewList
    self.mailPlayerList = self:Get("邮箱背景/邮件列表框/玩家邮件", ViewList) ---@type ViewList

    self.mailItemTemplateList:SetVisible(false)
    self.rewardDisplay:SetVisible(false)
    self.rewardListTemplate:SetVisible(false)

    -- 数据存储
    self.playerMails = {} ---@type table<string, MailData> -- 玩家邮件数据（mail_type为"玩家"的邮件）
    self.systemMails = {} ---@type table<string, MailData> -- 系统邮件数据（mail_type非"玩家"的邮件）
    self.currentSelectedMail = nil ---@type table -- 当前选中的邮件
    self.currentCategory = "系统邮件" ---@type string -- 当前选中的分类：系统邮件、玩家邮件
    self.mailButtons = {} ---@type table<string, ViewComponent> -- 邮件按钮缓存
    self.attachmentLists = {} ---@type table<string, ViewList>

    -- 为列表设置 onAddElementCb
    local function createMailItem(itemNode)
        local button = ViewButton.New(itemNode, self)
        button.clickCb = function(ui, btn)
            if btn.extraParams then
                self:OnMailItemClick(btn.extraParams.mailId, btn.extraParams.mailInfo)
            end
        end
        return button
    end
    self.mailSystemList.onAddElementCb = createMailItem
    self.mailPlayerList.onAddElementCb = createMailItem

    -- 初始化UI状态
    self:InitializeUI()

    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()

    -- 默认显示系统邮件
    self:SwitchCategory("系统邮件")
end

-- 初始化UI状态
function MailGui:InitializeUI()
    -- 初始时隐藏邮件详情面板和奖励列表
    if self.mailContentPanel then self.mailContentPanel:SetVisible(false) end
    if self.rewardDisplay then self.rewardDisplay:SetVisible(false) end
    ------gg.log("MailGui UI初始化完成")
end

-- 切换邮件分类
function MailGui:SwitchCategory(categoryName)
    self.currentCategory = categoryName

    -- 根据分类切换列表的可见性
    if categoryName == "系统邮件" then
        self.mailSystemList:SetVisible(true)
        self.mailPlayerList:SetVisible(false)
        -- TODO: 更新按钮选中状态
    elseif categoryName == "玩家邮件" then
        self.mailSystemList:SetVisible(false)
        self.mailPlayerList:SetVisible(true)
        -- TODO: 更新按钮选中状态
    end

    -- 清空当前选中的邮件并隐藏详情
    self.currentSelectedMail = nil
    self:HideMailDetail()
end

-- 注册按钮事件
function MailGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function()
        --gg.log("🔴 关闭按钮被点击")
        self:Close()
    end
    
    -- 领取按钮
    self.claimButton.clickCb = function()
        --gg.log("🎁 领取按钮被点击")
        self:OnClaimReward()
    end
    
    -- 一键领取按钮
    self.batchClaimButton.clickCb = function()
        --gg.log("🎁 一键领取按钮被点击")
        self:OnBatchClaim()
    end
    
    -- 系统邮件按钮
    self.mailSystemButtom.clickCb = function()
        --gg.log("📧 系统邮件按钮被点击")
        self:SwitchCategory("系统邮件")
    end
    
    -- 玩家邮件按钮
    self.mailPlayerButtom.clickCb = function()
        --gg.log("📧 玩家邮件按钮被点击")
        self:SwitchCategory("玩家邮件")
    end
    
    -- 删除已读邮件按钮
    self.deleteButton.clickCb = function()
        --gg.log("🗑️ 删除已读邮件按钮被点击")
        self:OnDeleteReadMails()
    end

    --gg.log("✅ 所有按钮事件注册完成")
end

-- 注册服务端事件
function MailGui:RegisterEvents()
    -- 监听邮件列表响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.LIST_RESPONSE, function(data)
        self:HandleMailListResponse(data)
    end)

    -- 监听邮件删除响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.DELETE_RESPONSE, function(data)
        self:HandleDeleteResponse(data)
    end)

    -- 监听邮件领取响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.CLAIM_RESPONSE, function(data)
        self:HandleClaimResponse(data)
    end)

    -- 监听批量领取响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.BATCH_CLAIM_SUCCESS, function(data)
        self:HandleBatchClaimResponse(data)
    end)

    -- 新增：监听删除已读响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.DELETE_READ_SUCCESS, function(data)
        self:HandleDeleteReadResponse(data)
    end)



    -- ------gg.log("MailGui客户端事件注册完成，共注册", 6, "个事件处理器")
end

-- 处理邮件列表响应
function MailGui:HandleMailListResponse(data)
    gg.log("=== HandleMailListResponse 开始 ===")
    -- gg.log("HandleMailListResponse收到邮件列表响应", data)

    if not data then
        ----gg.log("邮件列表响应数据为空")
        return
    end

    -- 内部辅助函数：处理一批邮件并将其分类到 self.playerMails 或 self.systemMails
    local function processAndCategorizeMails(mailBatch)
        if not mailBatch then 
            ----gg.log("邮件批次为空，跳过处理")
            return 
        end
        
        local count = 0
        for mailId, mailInfo in pairs(mailBatch) do
            count = count + 1
            ----gg.log("处理邮件", count, "ID:", mailId, "类型:", mailInfo.mail_type, "标题:", mailInfo.title)
            
            -- 兼容字段：优先使用 mail_type，否则回退到 type
            local mt = mailInfo.mail_type or mailInfo.type
            if mt == MAIL_TYPE.PLAYER then
                self.playerMails[tostring(mailId)] = mailInfo
                ----gg.log("添加到玩家邮件列表")
            else
                -- 对于全服/系统邮件：如果服务端标记为已删除(STATUS.DELETED)，则不创建对应节点
                if mailInfo.status == MailEventConfig.STATUS.DELETED then
                    ----gg.log("跳过已删除的全服邮件:", mailId)
                else
                    self.systemMails[tostring(mailId)] = mailInfo
                    ----gg.log("添加到系统邮件列表")
                end
            end
        end
        ----gg.log("邮件批次处理完成，共处理", count, "封邮件")
    end

    -- 内部辅助函数：为分类好的一批邮件创建附件列表
    local function createAttachmentListsForMails(mailBatch)
        if not mailBatch then return end
        for mailId, mailInfo in pairs(mailBatch) do
            if mailInfo.has_attachment and mailInfo.attachments then
                self:CreateAttachmentListForMail(mailId, mailInfo)
            end
        end
    end

    -- 步骤1: 清空现有数据
    ----gg.log("清空现有数据...")
    self:ClearAllAttachmentLists()
    self.playerMails = {}
    self.systemMails = {}

    -- 步骤2: 处理和分类个人邮件和全服邮件
    ----gg.log("处理个人邮件...")
    processAndCategorizeMails(data.personal_mails)
    ----gg.log("处理全服邮件...")
    processAndCategorizeMails(data.global_mails)

    -- 步骤3: 为所有已分类的邮件创建附件列表
    ----gg.log("创建附件列表...")
    createAttachmentListsForMails(self.playerMails)
    createAttachmentListsForMails(self.systemMails)

    -- 步骤4: 刷新整个UI列表
    ----gg.log("调用 InitMailList...")
    self:InitMailList()

    ----gg.log("邮件列表响应处理完成，玩家邮件:", self:GetMailCount(self.playerMails), "系统邮件:", self:GetMailCount(self.systemMails))
    ----gg.log("=== HandleMailListResponse 结束 ===")
end

-- 处理新邮件通知
---@param data NewMailNotificationPayload
function MailGui:HandleNewMailNotification(data)
    gg.log("收到新邮件通知", data)

    local mailInfo = data and data.mail_info

    ------gg.log("收到新邮件数据:", mailInfo.title, mailInfo.id)

    -- 1. 根据邮件类型，将新邮件添加到对应的本地数据表中
    local targetDataList
    local targetViewList
    if mailInfo.mail_type == MAIL_TYPE.PLAYER then
        targetDataList = self.playerMails
        targetViewList = self.mailPlayerList
    else
        targetDataList = self.systemMails
        targetViewList = self.mailSystemList
    end

    -- 检查邮件是否已存在，避免重复添加
    if targetDataList[mailInfo.id] then
        ------gg.log("⚠️ 邮件已存在，跳过添加:", mailInfo.id)
        return
    end

    targetDataList[mailInfo.id] = mailInfo

    -- 构造正确格式的 mailItemData
    local mailItemData = { id = mailInfo.id, data = mailInfo }
    self:_createMailListItem(targetViewList, mailItemData, 1)

    -- 2. 如果邮件有附件，为其创建附件UI列表
    if mailInfo.has_attachment and mailInfo.attachments then
        self:CreateAttachmentListForMail(mailInfo.id, mailInfo)
    end
    targetViewList:_refreshLayout()

end

-- 获取邮件总数
function MailGui:GetMailCount(mailTable)
    local count = 0
    if mailTable then
        for _ in pairs(mailTable) do
            count = count + 1
        end
    end
    return count
end

-- 初始化邮件列表显示
function MailGui:InitMailList()
    ----gg.log("=== InitMailList 开始 ===")
    
    if not self.mailItemTemplate then
        ----gg.log("❌ 邮件列表模板未找到，无法初始化邮件")
        return
    end

    -- 清空当前选中
    self.currentSelectedMail = nil
    self:HideMailDetail()

    self.mailButtons = {}
    
    -- 检查邮件数据
    ----gg.log("系统邮件数量:", self:GetMailCount(self.systemMails))
    ----gg.log("玩家邮件数量:", self:GetMailCount(self.playerMails))
    
    -- 排序邮件
    local sortedSystemMails = self:SortMails(self.systemMails)
    local sortedPlayerMails = self:SortMails(self.playerMails)
    
    ----gg.log("排序后系统邮件数量:", #sortedSystemMails)
    ----gg.log("排序后玩家邮件数量:", #sortedPlayerMails)
    
    -- 将服务器的邮件数据安装玩家还是系统分发给给类的uilist
    ----gg.log("开始填充系统邮件列表...")
    self:PopulateMailList(self.mailSystemList, sortedSystemMails)
    ----gg.log("开始填充玩家邮件列表...")
    self:PopulateMailList(self.mailPlayerList, sortedPlayerMails)
    
    -- 更新一键领取按钮状态
    if self.batchClaimButton then
        local hasUnclaimedMails = self:HasUnclaimedMails()
        self.batchClaimButton:SetVisible(hasUnclaimedMails)
        self.batchClaimButton:SetTouchEnable(hasUnclaimedMails)
    end

    ----gg.log("📧 所有邮件列表更新完成")
    ----gg.log("=== InitMailList 结束 ===")
end

---邮件排序的比较函数
---@param a table
---@param b table
---@return boolean
function MailGui:_sortMailComparator(a, b)
    local aClaimed = a.data.is_claimed or false
    local bClaimed = b.data.is_claimed or false

    -- 优先级1: 未领取的在前面
    if not aClaimed and bClaimed then
        return true
    elseif aClaimed and not bClaimed then
        return false
    end

    -- 优先级2: 在同一个领取状态下，按时间倒序
    local timeA = a.data.send_time or a.data.timestamp or 0
    local timeB = b.data.send_time or a.data.timestamp or 0
    return timeA > timeB
end

-- 对邮件进行排序
function MailGui:SortMails(mailTable)
    local sorted = {}
    if not mailTable then return sorted end

    for mailId, mailInfo in pairs(mailTable) do
        table.insert(sorted, {id = mailId, data = mailInfo})
    end
    -- 使用独立的比较函数进行排序
    table.sort(sorted, function(a, b) return self:_sortMailComparator(a, b) end)

    return sorted
end

-- 填充邮件列表
---@param targetList ViewList 目标列表
---@param mailArray table 邮件数据
function MailGui:PopulateMailList(targetList, mailArray)
    ----gg.log("PopulateMailList 开始，目标列表:", targetList and targetList.node and targetList.node.Name or "nil", "邮件数量:", #mailArray)
    
    if not targetList then
        ----gg.log("❌ 目标列表为空")
        return
    end
    
    if not mailArray or #mailArray == 0 then
        ----gg.log("⚠️ 邮件数组为空或长度为0")
        return
    end
    
    -- 清空现有邮件项，避免重复显示
    targetList:ClearChildren()
    ----gg.log("清空现有邮件项", targetList)
    
    -- 批量创建邮件项
    for i, mailItemData in ipairs(mailArray) do
        ----gg.log("创建邮件项", i, "ID:", mailItemData.id, "标题:", mailItemData.data and mailItemData.data.title or "nil")
        self:_createMailListItem(targetList, mailItemData, i)
    end
    
    -- 批量添加后，手动刷新一次UI布局
    ----gg.log("刷新UI布局...")
    -- targetList:_refreshLayout()
    
    -- 验证创建结果
    local actualCount = targetList:GetChildCount()
    ----gg.log("PopulateMailList 完成，期望:", #mailArray, "实际:", actualCount)
    
    if actualCount ~= #mailArray then
        ----gg.log("⚠️ 邮件项数量不匹配，可能存在创建失败")
    end
end

---创建单个邮件列表项并添加到列表中
---@param targetList ViewList 目标列表
---@param mailItemData table 邮件数据
---@param index number 要插入的位置
function MailGui:_createMailListItem(targetList, mailItemData, index)
    local mailIdStr = tostring(mailItemData.id)
    ----gg.log("_createMailListItem 开始，邮件ID:", mailIdStr, "索引:", index)

    -- 检查UI中是否已存在相同ID的邮件项
    if targetList:GetChildByName(mailIdStr) then
        ----gg.log("⚠️ UI中已存在相同ID的邮件项，跳过创建:", mailIdStr)
        return
    end

    -- 检查按钮缓存中是否已存在
    if self.mailButtons[mailIdStr] then
        ----gg.log("⚠️ 按钮缓存中已存在相同ID的邮件，跳过创建:", mailIdStr)
        return
    end

    if not self.mailItemTemplate or not self.mailItemTemplate.node then
        ----gg.log("❌ 邮件项模板为空")
        return
    end

    -- 创建邮件项节点
    local itemNode = self.mailItemTemplate.node:Clone()
    itemNode.Visible = true
    itemNode.Name = mailIdStr
    ----gg.log("克隆邮件项模板成功，节点名称:", itemNode.Name)
    
    -- 重要修复：先设置父节点，再插入到ViewList
    itemNode.Parent = targetList.node
    ----gg.log("插入子节点到目标列表成功",targetList,targetList.node)
    
    -- 使用InsertChild并设置shouldRefresh为false，避免每次添加都刷新UI
    targetList:InsertChild(itemNode, index, false)
    
    -- 获取刚创建的组件（应该在指定索引位置）
    local mailItemComponent = targetList:GetChildByName(mailIdStr)
    ----gg.log("获取邮件项组件:", mailItemComponent and "成功" or "失败")

    if mailItemComponent then
        -- 设置邮件显示信息
        self:SetupMailItemDisplay(mailItemComponent.node, mailItemData.data)
        
        -- 设置额外参数用于点击事件
        mailItemComponent.extraParams = {
            mailId = mailItemData.id, 
            mailInfo = mailItemData.data
        }
        
        -- 缓存到按钮字典
        self.mailButtons[mailIdStr] = mailItemComponent
        ----gg.log("✅ 邮件项创建成功:", mailIdStr)
    else
        ----gg.log("❌ 无法获取邮件项组件，检查 onAddElementCb 是否正常工作")
    end
end
-- 设置邮件项显示信息
function MailGui:SetupMailItemDisplay(itemNode, mailInfo)
    ----gg.log("SetupMailItemDisplay 开始，邮件标题:", mailInfo.title, "发件人类型:", type(mailInfo.sender), "发件人值:", mailInfo.sender)
    
    -- 检查标题是否为字符串
    if type(mailInfo.title) ~= "string" then
        ----gg.log("⚠️ 邮件标题不是字符串类型:", type(mailInfo.title), "值:", mailInfo.title)
        mailInfo.title = tostring(mailInfo.title or "无标题")
    end
    itemNode["主标题"].Title = mailInfo.title
    
    -- 处理发件人信息，可能是字符串或表
    local senderName = "系统"
    if type(mailInfo.sender) == "string" then
        senderName = mailInfo.sender
    elseif type(mailInfo.sender) == "table" and mailInfo.sender.name then
        senderName = mailInfo.sender.name
    end
    
    -- 确保senderName是字符串
    if type(senderName) ~= "string" then
        ----gg.log("⚠️ 发件人名称不是字符串类型:", type(senderName), "值:", senderName)
        senderName = tostring(senderName or "系统")
    end
    
    itemNode["来自谁"].Title = "来自: " .. senderName
    
    -- 安全处理布尔值
    local hasAttachment = mailInfo.has_attachment == true
    local isClaimed = mailInfo.is_claimed == true
    
    itemNode["是否有物品"].Visible = hasAttachment
    -- new: 邮件是否领取
    local newNode = itemNode["new"]
    if hasAttachment then
        newNode.Visible = not isClaimed
    else
        newNode.Visible = false
    end
    
    ----gg.log("SetupMailItemDisplay 完成，标题:", mailInfo.title, "发件人:", senderName, "有附件:", hasAttachment, "已领取:", isClaimed)
end

-- 邮件项点击事件
function MailGui:OnMailItemClick(mailId, mailInfo)
    ------gg.log("点击邮件项", mailId, mailInfo.title)

    -- 更新当前选中邮件
    self.currentSelectedMail = {
        id = mailId,
        data = mailInfo
    }

    -- 显示邮件详情
    self:ShowMailDetail(mailInfo)
end

-- 显示邮件详情
function MailGui:ShowMailDetail(mailInfo)
    -- 显示邮件详情面板
    ------gg.log("mailInfo邮件的切换数据",mailInfo)
    if self.mailContentPanel then self.mailContentPanel:SetVisible(true) end
    local mailContentPanelNode = self.mailContentPanel.node
    
    -- 安全处理标题
    local title = mailInfo.title or "无标题"
    if type(title) ~= "string" then
        title = tostring(title)
    end
    mailContentPanelNode["Title"].Title = title
    
    -- 安全处理时间
    local sendTime = TimeUtils.FormatTimestamp(mailInfo.send_time or 0)
    local expireTime = TimeUtils.FormatTimestamp(mailInfo.expire_time or 0)
    mailContentPanelNode["发送时间"].Title = "发送时间: " .. sendTime
    mailContentPanelNode["截止时间"].Title = "截止时间: " .. expireTime
    
    -- 安全处理内容
    local content = mailInfo.content or "无内容"
    if type(content) ~= "string" then
        content = tostring(content)
    end
    mailContentPanelNode["正文内容"].Title = content

    -- 安全处理发件人信息
    local senderName = "系统"
    if type(mailInfo.sender) == "string" then
        senderName = mailInfo.sender
    elseif type(mailInfo.sender) == "table" and mailInfo.sender.name then
        senderName = mailInfo.sender.name
    end
    
    -- 确保senderName是字符串
    if type(senderName) ~= "string" then
        senderName = tostring(senderName or "系统")
    end
    
    mailContentPanelNode["发送人"].Title = "发送人: " .. senderName
    -- 更新按钮状态
    self:UpdateDetailButtons(mailInfo)

    -- 隐藏所有附件列表，然后显示当前邮件的附件列表
    self:HideAllAttachmentLists()
    if mailInfo.has_attachment then
        if self.rewardDisplay then self.rewardDisplay:SetVisible(true) end
        local attachmentList = self.attachmentLists[tostring(mailInfo.id)]
        if attachmentList then
            attachmentList:SetVisible(true)
            -- 根据领取状态更新附件外观
            self:UpdateAttachmentListAppearance(mailInfo.id, mailInfo.is_claimed)
        else
            ------gg.log("⚠️ 找不到邮件对应的附件列表:", mailInfo.id)
        end
    end

    ------gg.log("邮件详情显示完成")
end

-- 隐藏邮件详情
function MailGui:HideMailDetail()
    if self.mailContentPanel then self.mailContentPanel:SetVisible(false) end
    self:HideAllAttachmentLists()
end

-- 新增：隐藏所有附件列表
function MailGui:HideAllAttachmentLists()
    if self.rewardDisplay then self.rewardDisplay:SetVisible(false) end
    if self.attachmentLists then
        for _, attachmentViewList in pairs(self.attachmentLists) do
            if attachmentViewList then
                attachmentViewList:SetVisible(false)
            end
        end
    end
end

--- 更新附件列表外观（是否置灰）
function MailGui:UpdateAttachmentListAppearance(mailId, isClaimed)
    local attachmentList = self.attachmentLists[tostring(mailId)]
    if attachmentList then
        ------gg.log("节点置为灰色", mailId, isClaimed)
        attachmentList:SetGray(isClaimed)
    else
        ------gg.log("⚠️ 未找到邮件对应的附件列表:", mailId)
    end
end

-- 新增：清空所有已生成的附件列表
function MailGui:ClearAllAttachmentLists()
    if self.attachmentLists then
        for mailId, attachmentlist in pairs(self.attachmentLists) do
            if attachmentlist and attachmentlist.node  then
                attachmentlist.node:Destroy()
            end
        end
    end
    self.attachmentLists = {}
end

-- 新增：为单个邮件创建其专属的附件列表
function MailGui:CreateAttachmentListForMail(mailId, mailInfo)
    if not self.rewardListTemplate or not self.rewardItemTemplate or not self.rewardDisplay then
        ------gg.log("❌ 奖励列表模板、项目模板或容器未找到，无法为邮件创建附件列表:", mailId)
        return
    end

    local str_mailid = tostring(mailId)

    -- 检查是否已存在该邮件的附件列表
    if self.attachmentLists[str_mailid] then
        ------gg.log("⚠️ 邮件附件列表已存在，跳过创建:", str_mailid)
        return
    end

    -- 1. 克隆列表容器节点
    local newListContainerNode = self.rewardListTemplate.node:Clone()
    newListContainerNode.Parent = self.rewardDisplay.node
    newListContainerNode.Name = str_mailid

    -- 2. 处理奖励数据
    local rewardItems = self:ProcessRewardData(mailInfo.attachments)

    -- 3. 创建ViewList实例来管理附件列表
    local rewardDisplayNode = ViewList.New(newListContainerNode, self, "邮箱背景/邮件内容/附件/" .. str_mailid, function(itemNode, childPath)
        -- 为每个附件项创建ViewComponent
        local component = ViewComponent.New(itemNode, self, childPath)
        return component
    end)

    -- 4. 为ViewList设置元素数量
    rewardDisplayNode:SetElementSize(#rewardItems)

    -- 5. 填充每个附件项的数据
    for i, rewardData in ipairs(rewardItems) do
        local childComponent = rewardDisplayNode:GetChild(i)
        if childComponent then
            childComponent.node.Name = tostring(rewardData.itemName)
            self:SetupRewardItemDisplay(childComponent.node, rewardData)
        end
    end

    -- 6. 默认隐藏并缓存
    rewardDisplayNode:SetVisible(false)
    self.attachmentLists[str_mailid] = rewardDisplayNode
    ------gg.log("✅ 为邮件创建附件列表成功:", mailId, "共", #rewardItems, "个附件")
end

-- 处理奖励数据，转换为统一格式
function MailGui:ProcessRewardData(rewards)
    local rewardItems = {}
    local ItemTypeConfig = require(MainStorage.Code.Common.Config.ItemTypeConfig) ---@type ItemTypeConfig

    if type(rewards) == "table" then
        -- 附件的数据格式是一个 table 数组, e.g., { {type="itemA", amount=1}, {type="itemB", amount=2} }
        -- 因此需要用 ipairs 遍历
        for _, rewardData in ipairs(rewards) do
            -- rewardData 的格式是 { type = "物品名", amount = 数量 }
            local itemName = rewardData.type
            local amount = rewardData.amount
            if itemName and amount and amount > 0 then
                ---@type ItemType
                local itemConfig = ConfigLoader.GetItem(itemName)

                if itemConfig then
                    table.insert(rewardItems, {
                        itemName = itemName,
                        amount = amount,
                        icon = itemConfig.icon,

                    })
                else
                    ------gg.log("⚠️ 找不到物品配置:", itemName)
                    -- 即使找不到配置，也添加一个默认项，以防显示不全
                    table.insert(rewardItems, {
                        itemName = itemName,
                        amount = amount,
                        icon = nil, -- 使用默认图标

                    })
                end
            end
        end
    end

    -- 按物品名称排序
    table.sort(rewardItems, function(a, b)
        return a.itemName < b.itemName
    end)

    ------gg.log("🎁 处理奖励数据完成，共", #rewardItems, "个物品")
    return rewardItems
end

-- 为单个奖励物品设置UI显示
function MailGui:SetupRewardItemDisplay(itemNode, rewardItem)
    if not itemNode then return end

    -- 设置物品图标
    local iconNode = itemNode["图标"]
    ------gg.log("iconNode",iconNode,rewardItem.icon)
    if iconNode and rewardItem.icon and  rewardItem.icon ~="" then
        -- 如果配置了图标则使用，否则使用默认图标
        iconNode.Icon = rewardItem.icon
    end

    -- 设置物品数量
    local amountNode = itemNode["数量"]
    if amountNode and amountNode.Title then
        amountNode.Title = gg.FormatLargeNumber(rewardItem.amount)
    end
end

-- 更新详情面板按钮状态
function MailGui:UpdateDetailButtons(mailInfo)
    --gg.log("🔧 UpdateDetailButtons 开始更新按钮状态")
    
    -- 安全处理布尔值
    local hasAttachment = mailInfo.has_attachment == true
    local isClaimed = mailInfo.is_claimed == true
    --gg.log("📎 邮件状态 - 有附件:", hasAttachment, "已领取:", isClaimed)
    
    -- 领取按钮：只有有附件时显示，根据是否领取决定是否可交互和置灰
    if self.claimButton then
        self.claimButton:SetVisible(hasAttachment)
        --gg.log("🎁 领取按钮可见性设置为:", hasAttachment)

        if hasAttachment then
            local canClaim = not isClaimed
            self.claimButton:SetTouchEnable(canClaim)
            --gg.log("🎁 领取按钮可交互性设置为:", canClaim)
        end
    else
        --gg.log("❌ 领取按钮未找到")
    end

    -- 删除按钮：总是可用
    if self.deleteButton then
        self.deleteButton:SetVisible(true)
        self.deleteButton:SetTouchEnable(true)
        --gg.log("🗑️ 删除按钮状态已设置")
    else
        --gg.log("❌ 删除按钮未找到")
    end

    -- 一键领取按钮：根据全局状态决定
    if self.batchClaimButton then
        local hasUnclaimedMails = self:HasUnclaimedMails()
        self.batchClaimButton:SetVisible(hasUnclaimedMails)
        self.batchClaimButton:SetTouchEnable(hasUnclaimedMails)
        --gg.log("🎁 一键领取按钮状态 - 可见:", hasUnclaimedMails, "可交互:", hasUnclaimedMails)
    else
        --gg.log("❌ 一键领取按钮未找到")
    end
    
    --gg.log("✅ 按钮状态更新完成")
end

-- 检查是否有未领取的邮件
function MailGui:HasUnclaimedMails()
    --gg.log("🔍 检查是否有未领取的邮件")
    
    local playerUnclaimedCount = 0
    local systemUnclaimedCount = 0
    
    -- 检查玩家邮件
    for mailId, mailInfo in pairs(self.playerMails) do
        local hasAttachment = mailInfo.has_attachment == true
        local isClaimed = mailInfo.is_claimed == true
        if hasAttachment and not isClaimed then
            playerUnclaimedCount = playerUnclaimedCount + 1
            --gg.log("📧 玩家邮件未领取:", mailId, "标题:", mailInfo.title)
        end
    end
    
    -- 检查系统邮件
    for mailId, mailInfo in pairs(self.systemMails) do
        local hasAttachment = mailInfo.has_attachment == true
        local isClaimed = mailInfo.is_claimed == true
        if hasAttachment and not isClaimed then
            systemUnclaimedCount = systemUnclaimedCount + 1
            --gg.log("📧 系统邮件未领取:", mailId, "标题:", mailInfo.title)
        end
    end
    
    local totalUnclaimed = playerUnclaimedCount + systemUnclaimedCount
    --gg.log("📊 未领取邮件统计 - 玩家邮件:", playerUnclaimedCount, "系统邮件:", systemUnclaimedCount, "总计:", totalUnclaimed)
    
    return totalUnclaimed > 0
end

-- 删除邮件
function MailGui:OnDeleteMail()
    if not self.currentSelectedMail then
        ------gg.log("没有选中的邮件")
        return
    end

    local mailId = self.currentSelectedMail.id
    local mailInfo = self.currentSelectedMail.data
    local isGlobal = mailInfo.is_global_mail or false

    gg.log("删除邮件", mailId, "is_global:", isGlobal)

    -- 发送删除请求
    self:SendDeleteRequest(mailId, isGlobal)
end

-- 领取附件
function MailGui:OnClaimReward()
    --gg.log("🎁 OnClaimReward 开始执行")
    
    if not self.currentSelectedMail then
        --gg.log("❌ 没有选中的邮件，无法领取")
        return
    end

    local mailId = self.currentSelectedMail.id
    local mailInfo = self.currentSelectedMail.data
    --gg.log("📧 当前选中邮件ID:", mailId, "标题:", mailInfo.title)

    -- 检查附件状态
    local hasAttachment = mailInfo.has_attachment == true
    local isClaimed = mailInfo.is_claimed == true
    --gg.log("📎 邮件附件状态 - 有附件:", hasAttachment, "已领取:", isClaimed)

    if not hasAttachment then
        --gg.log("❌ 邮件没有附件，无法领取")
        return
    end
    
    if isClaimed then
        --gg.log("❌ 邮件附件已领取，无法重复领取")
        return
    end

    local isGlobal = mailInfo.is_global_mail or false
    --gg.log("🌐 邮件类型 - 全服邮件:", isGlobal)

    -- 发送领取请求
    --gg.log("📤 发送领取请求到服务器...")
    self:SendClaimRequest(mailId, isGlobal)
    --gg.log("✅ 领取请求已发送")
end

-- 一键领取
function MailGui:OnBatchClaim()
    --gg.log("🎁 OnBatchClaim 开始执行")
    --gg.log("📂 当前分类:", self.currentCategory)

    local mailListToScan
    if self.currentCategory == "系统邮件" then
        mailListToScan = self.systemMails
        --gg.log("📧 扫描系统邮件列表，数量:", self:GetMailCount(self.systemMails))
    else
        mailListToScan = self.playerMails
        --gg.log("📧 扫描玩家邮件列表，数量:", self:GetMailCount(self.playerMails))
    end

    local mailIdsToClaim = {}
    local totalMails = 0
    local claimableMails = 0
    
    for mailId, mailInfo in pairs(mailListToScan) do
        totalMails = totalMails + 1
        local hasAttachment = mailInfo.has_attachment == true
        local isClaimed = mailInfo.is_claimed == true
        
        --gg.log("📧 检查邮件:", mailId, "标题:", mailInfo.title, "有附件:", hasAttachment, "已领取:", isClaimed)
        
        if hasAttachment and not isClaimed then
            table.insert(mailIdsToClaim, mailId)
            claimableMails = claimableMails + 1
            --gg.log("✅ 可领取邮件:", mailId)
        end
    end

    --gg.log("📊 扫描结果 - 总邮件数:", totalMails, "可领取数:", claimableMails)

    if #mailIdsToClaim == 0 then
        --gg.log("❌ 没有可领取的邮件")
        return
    end

    --gg.log("📤 发送批量领取请求，邮件ID列表:", mailIdsToClaim)
    
    -- 发送批量领取请求
    local requestData = {
        cmd = MailEventConfig.REQUEST.BATCH_CLAIM,
        category = self.currentCategory,
        mail_ids = mailIdsToClaim
    }
    
    --gg.log("📤 请求数据:", requestData)
    gg.network_channel:FireServer(requestData)
    --gg.log("✅ 批量领取请求已发送")
end

-- 新增：删除已读邮件
function MailGui:OnDeleteReadMails()
    --gg.log("🗑️ OnDeleteReadMails 开始执行")
    --gg.log("📂 当前分类:", self.currentCategory)

    local mailListToScan = {}
    local isGlobalCategory = false
    if self.currentCategory == "系统邮件" then
        mailListToScan = self.systemMails
        isGlobalCategory = true
        --gg.log("📧 扫描系统邮件列表，数量:", self:GetMailCount(self.systemMails))
    else
        mailListToScan = self.playerMails
        --gg.log("📧 扫描玩家邮件列表，数量:", self:GetMailCount(self.playerMails))
    end

    local personalMailIdsToDelete = {}
    local globalMailIdsToDelete = {}

    for mailId, mailInfo in pairs(mailListToScan) do
        local hasAttachment = mailInfo.has_attachment == true
        local isClaimed = mailInfo.is_claimed == true
        local canDelete = not hasAttachment or isClaimed
        
        --gg.log("📧 检查邮件:", mailId, "标题:", mailInfo.title, "有附件:", hasAttachment, "已领取:", isClaimed, "可删除:", canDelete)
        
        -- 已读条件：没有附件，或者有附件但已领取
        if canDelete then
            if isGlobalCategory then
                table.insert(globalMailIdsToDelete, mailId)
                --gg.log("✅ 添加到全服邮件删除列表:", mailId)
            else
                table.insert(personalMailIdsToDelete, mailId)
                --gg.log("✅ 添加到个人邮件删除列表:", mailId)
            end
        end
    end

    --gg.log("📊 删除统计 - 个人邮件:", #personalMailIdsToDelete, "全服邮件:", #globalMailIdsToDelete)

    if #personalMailIdsToDelete == 0 and #globalMailIdsToDelete == 0 then
        --gg.log("❌ 没有可删除的已读邮件")
        return
    end

    local requestData = {
        cmd = MailEventConfig.REQUEST.DELETE_READ_MAILS,
        personalMailIds = personalMailIdsToDelete,
        globalMailIds = globalMailIdsToDelete
    }
    
    --gg.log("📤 发送删除已读邮件请求:", requestData)
    gg.network_channel:FireServer(requestData)
    --gg.log("✅ 删除已读邮件请求已发送")
end

-- 发送删除请求
function MailGui:SendDeleteRequest(mailId, isGlobal)
    gg.network_channel:FireServer({
        cmd = MailEventConfig.REQUEST.DELETE_MAIL,
        mailId = mailId,  -- 修改为服务端期望的参数名
        is_global = isGlobal
    })
end

-- 发送领取请求
function MailGui:SendClaimRequest(mailId, isGlobal)
    local requestData = {
        cmd = MailEventConfig.REQUEST.CLAIM_MAIL,
        mailId = mailId,  -- 修改为服务端期望的参数名
        is_global = isGlobal
    }
    
    --gg.log("📤 SendClaimRequest - 邮件ID:", mailId, "全服邮件:", isGlobal)
    --gg.log("📤 请求数据:", requestData)
    
    gg.network_channel:FireServer(requestData)
    --gg.log("✅ 领取请求已发送到服务器")
end

-- 处理删除响应
function MailGui:HandleDeleteResponse(data)
    ------gg.log("收到删除响应", data)

    if data.success and data.mail_id then
        local mailIdStr = tostring(data.mail_id)
        local targetList

        -- 从本地数据中移除，并确定在哪个UI列表中操作
        if self.playerMails[mailIdStr] then
            self.playerMails[mailIdStr] = nil
            targetList = self.mailPlayerList
        elseif self.systemMails[mailIdStr] then
            self.systemMails[mailIdStr] = nil
            targetList = self.mailSystemList
        end

        -- 如果找到了对应的UI列表，则从中移除节点
        if targetList then
            targetList:RemoveChildByName(mailIdStr)
        end

        -- 从按钮缓存中移除
        self.mailButtons[mailIdStr] = nil

        -- 如果删除的是当前选中的邮件，则清空详情面板
        if self.currentSelectedMail and self.currentSelectedMail.id == data.mail_id then
            self.currentSelectedMail = nil
            self:HideMailDetail()
        end

        ------gg.log("邮件删除成功（增量更新）", data.mail_id)
    else
        ------gg.log("邮件删除失败", data.error or "未知错误")
    end
end

-- 处理领取响应
function MailGui:HandleClaimResponse(data)
    ------gg.log("收到领取响应", data)

    if data.success and data.mail_id then
        local mailIdStr = tostring(data.mail_id)

        -- 1. 更新本地数据
        local mailInfo
        if self.playerMails[mailIdStr] then
            self.playerMails[mailIdStr].is_claimed = true
            mailInfo = self.playerMails[mailIdStr]
        elseif self.systemMails[mailIdStr] then
            self.systemMails[mailIdStr].is_claimed = true
            mailInfo = self.systemMails[mailIdStr]
        end

        -- 2. 更新对应的邮件项UI显示（直接更新，无需重建列表）
        local mailItemComponent = self.mailButtons[mailIdStr]
        if mailItemComponent and mailInfo then
            self:SetupMailItemDisplay(mailItemComponent.node, mailInfo)
        end

        -- 3. 更新当前选中邮件的状态
        if self.currentSelectedMail and tostring(self.currentSelectedMail.id) == mailIdStr then
            self.currentSelectedMail.data.is_claimed = true
            self:UpdateDetailButtons(self.currentSelectedMail.data)
            -- 领取成功后，更新附件列表外观
            self:UpdateAttachmentListAppearance(mailIdStr, true)
        end

        -- 4. 更新全局按钮状态（如一键领取按钮）
        if self.batchClaimButton then
            local hasUnclaimedMails = self:HasUnclaimedMails()
            self.batchClaimButton:SetVisible(hasUnclaimedMails)
            self.batchClaimButton:SetTouchEnable(hasUnclaimedMails)
        end

        ------gg.log("附件领取成功", data.mail_id)
    else
        ------gg.log("附件领取失败", data.error or "未知错误")
    end
end

-- 处理批量领取响应
function MailGui:HandleBatchClaimResponse(data)
    ------gg.log("收到批量领取响应", data)

    if data.success and data.claimedMails then
        -- 更新所有相关邮件的状态
        for _, claimedMail in ipairs(data.claimedMails) do
            local mailIdStr = tostring(claimedMail.id)
            ---@type MailData
            local mailInfo

            if self.playerMails[mailIdStr] then
                mailInfo = self.playerMails[mailIdStr]
            elseif self.systemMails[mailIdStr] then
                mailInfo = self.systemMails[mailIdStr]
            end

            if mailInfo then
                mailInfo.is_claimed = true

                -- 更新UI项
                local mailItemComponent = self.mailButtons[mailIdStr]
                if mailItemComponent then
                    self:SetupMailItemDisplay(mailItemComponent.node, mailInfo)
                end

                -- 如果是当前选中的邮件，也更新详情面板
                if self.currentSelectedMail and tostring(self.currentSelectedMail.id) == mailIdStr then
                    self.currentSelectedMail.data.is_claimed = true
                    self:UpdateDetailButtons(self.currentSelectedMail.data)
                    self:UpdateAttachmentListAppearance(mailIdStr, true)
                end
            end
        end

        -- 更新一键领取按钮状态
        self:UpdateDetailButtons(self.currentSelectedMail and self.currentSelectedMail.data or {})

        ------gg.log("批量领取成功", data.claimedCount or 0, "封邮件")
    else
        ------gg.log("批量领取失败", data.error or "未知错误")
    end
end

-- 新增：处理删除已读响应
function MailGui:HandleDeleteReadResponse(data)
    --gg.log("🗑️ 收到删除已读邮件响应", data)
    
    -- 检查成功状态：使用code字段而不是success字段
    local isSuccess = data.code == 0 and data.deletedMailIds and #data.deletedMailIds > 0
    --gg.log("🔍 响应状态检查 - code:", data.code, "deletedMailIds存在:", data.deletedMailIds ~= nil, "数量:", data.deletedMailIds and #data.deletedMailIds or 0, "判断为成功:", isSuccess)
    
    if isSuccess then
        --gg.log("✅ 删除成功，删除的邮件数量:", #data.deletedMailIds)
        
        -- 遍历返回的ID列表，从UI和数据中移除
        for _, mailId in ipairs(data.deletedMailIds) do
            local mailIdStr = tostring(mailId)
            local targetList
            if self.playerMails[mailIdStr] then
                self.playerMails[mailIdStr] = nil
                targetList = self.mailPlayerList
                --gg.log("🗑️ 从玩家邮件中移除:", mailIdStr)
            elseif self.systemMails[mailIdStr] then
                -- 对于系统邮件，我们实际上是在删除玩家的状态，而不是邮件本身
                self.systemMails[mailIdStr] = nil
                targetList = self.mailSystemList
                --gg.log("🗑️ 从系统邮件中移除:", mailIdStr)
            end

            if targetList then
                targetList:RemoveChildByName(mailIdStr)
                --gg.log("🗑️ 从UI列表中移除:", mailIdStr)
            end
            self.mailButtons[mailIdStr] = nil
        end

        -- 如果当前选中的邮件被删除了，则隐藏详情
        if self.currentSelectedMail and data.deletedMailIds then
            local currentMailDeleted = false
            for _, deletedMailId in ipairs(data.deletedMailIds) do
                if tostring(deletedMailId) == tostring(self.currentSelectedMail.id) then
                    currentMailDeleted = true
                    break
                end
            end
            if currentMailDeleted then
                --gg.log("🗑️ 当前选中的邮件被删除，隐藏详情面板")
                self.currentSelectedMail = nil
                self:HideMailDetail()
            end
        end
        
        --gg.log("✅ 成功删除", #data.deletedMailIds, "封已读邮件")
    else
        --gg.log("❌ 删除已读邮件失败", data.message or data.error or "未知错误")
    end
end

-- 打开界面时请求邮件数据
function MailGui:OnOpen()
    ------gg.log("MailGui打开，请求邮件数据")

    -- 请求服务端同步邮件数据
    gg.network_channel:FireServer({
        cmd = MailEventConfig.REQUEST.GET_LIST
    })
end

return MailGui.New(script.Parent, uiConfig)
