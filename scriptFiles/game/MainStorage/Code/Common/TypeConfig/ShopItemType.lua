-- ShopItemType.lua
-- 商城商品类型配置类，用于解析和管理商城商品配置

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class ShopItemPrice
---@field currencyType string 货币类型
---@field amount number 价格数量
---@field miniCoinType string|nil 迷你币类型
---@field miniCoinAmount number 迷你币数量
---@field variableKey string 变量键
---@field adMode string 广告模式
---@field adCount number 广告次数


---@class ShopItemPurchaseCondition
---@field conditionType string 条件类型
---@field conditionValue any 条件值
---@field comparisonOperator string 比较操作符

---@class ShopItemLimitConfig
---@field limitType string 限购类型
---@field limitCount number 限购次数
---@field resetTime string 重置时间
---@field purchaseCondition ShopItemPurchaseCondition 购买条件

---@class ShopItemReward
---@field itemType string 商品类型
---@field itemName string|nil 商品名称
---@field variableName string|nil 变量名称
---@field amount number 数量
---@field gainDescription string|nil 获得商品描述
---@field simpleDescription string|nil 简单描述
---@field iconResource string|nil 资源图标

---@class ShopItemPool
---@field poolName string 奖池名称
---@field poolItems table[] 奖池物品
---@field guaranteedItem ShopItemReward 保底物品

---@class ShopItemTimeConfig
---@field isLimited boolean 是否限时
---@field startTime string 开始时间
---@field endTime string 结束时间

---@class ShopItemVipRequirement
---@field requireVip boolean 需要VIP
---@field vipLevel number VIP等级

---@class ShopItemSpecialProperties
---@field miniItemId number 迷你商品ID
---@field timeConfig ShopItemTimeConfig 时效配置
---@field vipRequirement ShopItemVipRequirement VIP需求

---@class ShopItemUIConfig
---@field sortWeight number 排序权重
---@field hotSaleTag boolean 热卖标签
---@field limitedTag boolean 限定标签
---@field recommendedTag boolean 推荐标签
---@field iconPath string 图标路径
---@field iconCount number 图标数量
---@field backgroundStyle string 背景样式

---@class ShopItemType : Class
---@field configName string 商品名
---@field description string 商品描述
---@field category string 商品分类
---@field price ShopItemPrice 价格配置
---@field limitConfig ShopItemLimitConfig 限购配置
---@field rewards ShopItemReward[] 获得物品
---@field executeCommands table[] 执行指令
---@field pool ShopItemPool 奖池配置
---@field uiConfig ShopItemUIConfig 界面配置
---@field specialProperties ShopItemSpecialProperties 特殊属性
---@field New fun(data:table):ShopItemType
local ShopItemType = ClassMgr.Class("ShopItemType")

function ShopItemType:OnInit(data)
    -- 基础信息
    self.configName = data["商品名"] or "未知商品"
    self.description = data["商品描述"] or ""
    self.category = data["商品分类"] or "普通商品"
    
    -- 价格配置
    self.price = self:ParsePrice(data["价格"] or {})
    
    -- 限购配置
    self.limitConfig = self:ParseLimitConfig(data["限购配置"] or {})
    
    -- 获得物品
    self.rewards = self:ParseRewards(data["获得物品"] or {})
    
    -- 执行指令
    self.executeCommands = data["执行指令"] or {}
    
    -- 奖池配置
    self.pool = self:ParsePool(data["奖池"] or {})
    
    -- 界面配置
    self.uiConfig = self:ParseUIConfig(data["界面配置"] or {})
    
    -- 特殊属性
    self.specialProperties = self:ParseSpecialProperties(data["特殊属性"] or {})
end

--- 解析价格配置
---@param priceData table 价格数据
---@return ShopItemPrice 价格配置对象
function ShopItemType:ParsePrice(priceData)
    return {
        currencyType = priceData["货币类型"] or nil,
        amount = tonumber(priceData["价格数量"]) or -1,
        miniCoinType = priceData["迷你币类型"],
        miniCoinAmount =priceData["迷你币数量"] or -1,
        variableKey = priceData["变量键"] or "",
        adMode = priceData["广告模式"] or "不可看广告",
        adCount = priceData["广告次数"] or 0,
    }
end

--- 解析限购配置
---@param limitData table 限购数据
---@return ShopItemLimitConfig 限购配置对象
function ShopItemType:ParseLimitConfig(limitData)
    local purchaseCondition = limitData["购买条件"] or {}
    return {
        limitType = limitData["限购类型"] or "无限制",
        limitCount = limitData["限购次数"] or -1,
        resetTime = limitData["重置时间"] or "",
        purchaseCondition = {
            conditionType = purchaseCondition["条件类型"] or "无",
            conditionValue = purchaseCondition["条件值"] or 0,
            comparisonOperator = purchaseCondition["比较操作符"] or "大于等于"
        }
    }
end

--- 解析获得物品
---@param rewardsData table[] 获得物品数据
---@return ShopItemReward[] 获得物品数组
function ShopItemType:ParseRewards(rewardsData)
    local rewards = {}
    for _, rewardData in ipairs(rewardsData) do
        table.insert(rewards, {
            itemType = rewardData["商品类型"] or "物品",
            itemName = rewardData["商品名称"],
            variableName = rewardData["变量名称"],
            amount = rewardData["数量"] or 1,
            gainDescription = rewardData["获得商品描述"],
            simpleDescription = rewardData["简单描述"],
            iconResource = rewardData["资源图标"],
        })
    end
    return rewards
end

--- 解析奖池配置
---@param poolData table 奖池数据
---@return ShopItemPool 奖池配置对象
function ShopItemType:ParsePool(poolData)
    local guaranteedItem = poolData["保底物品"] or {}
    return {
        poolName = poolData["奖池名称"] or "",
        poolItems = poolData["奖池物品"] or {},
        guaranteedItem = {
            itemType = guaranteedItem["商品类型"] or "物品",
            itemName = guaranteedItem["商品名称"],
            variableName = guaranteedItem["变量名称"],
            amount = guaranteedItem["数量"] or 1
        }
    }
end

--- 解析界面配置
---@param uiData table 界面数据
---@return ShopItemUIConfig 界面配置对象
function ShopItemType:ParseUIConfig(uiData)
    return {
        sortWeight = uiData["排序权重"] or 0,
        hotSaleTag = uiData["热卖标签"] or false,
        limitedTag = uiData["限定标签"] or false,
        recommendedTag = uiData["推荐标签"] or false,
        iconPath = uiData["图标路径"] or "",
        iconCount = uiData["图标数量"] or 0,
        backgroundStyle = uiData["背景样式"] or "N"
    }
end

--- 解析特殊属性
---@param specialData table 特殊属性数据
---@return ShopItemSpecialProperties 特殊属性对象
function ShopItemType:ParseSpecialProperties(specialData)
    local timeConfig = specialData["时效配置"] or {}
    local vipRequirement = specialData["VIP需求"] or {}
    return {
        miniItemId = specialData["迷你商品ID"] or -1,
        timeConfig = {
            isLimited = timeConfig["是否限时"] or false,
            startTime = timeConfig["开始时间"] or "",
            endTime = timeConfig["结束时间"] or ""
        },
        vipRequirement = {
            requireVip = vipRequirement["需要VIP"] or false,
            vipLevel = vipRequirement["VIP等级"] or 1
        }
    }
end

--- 检查玩家是否满足购买条件
---@param playerLevel number 玩家等级
---@return boolean, string 是否满足条件，失败原因
function ShopItemType:CheckPurchaseCondition(playerLevel)
    local condition = self.limitConfig.purchaseCondition
    if condition.conditionType == "无" or not condition.conditionType then
        return true, "无等级要求"
    end
    
    if condition.conditionType == "玩家等级" then
        local targetLevel = condition.conditionValue or 0
        if condition.comparisonOperator == "大于等于" then
            if playerLevel >= targetLevel then
                return true, "等级满足要求"
            else
                return false, string.format("等级不足，需要%d级", targetLevel)
            end
        elseif condition.comparisonOperator == "大于" then
            if playerLevel > targetLevel then
                return true, "等级满足要求"
            else
                return false, string.format("等级不足，需要%d级以上", targetLevel)
            end
        elseif condition.comparisonOperator == "等于" then
            if playerLevel == targetLevel then
                return true, "等级满足要求"
            else
                return false, string.format("等级必须为%d级", targetLevel)
            end
        elseif condition.comparisonOperator == "小于等于" then
            if playerLevel <= targetLevel then
                return true, "等级满足要求"
            else
                return false, string.format("等级过高，需要%d级以下", targetLevel)
            end
        elseif condition.comparisonOperator == "小于" then
            if playerLevel < targetLevel then
                return true, "等级满足要求"
            else
                return false, string.format("等级过高，需要%d级以下", targetLevel)
            end
        end
    end
    
    return true, "条件满足" -- 默认满足条件
end

--- 检查是否可购买（基于限购配置和玩家条件）
---@param player MPlayer 玩家对象
---@return boolean, string 是否可购买，失败原因
function ShopItemType:CanPurchase(player)
    if not player then
        return false, "玩家对象无效"
    end
    
    -- 检查玩家等级条件
    local canBuyCondition, conditionReason = self:CheckPurchaseCondition(player.level or 0)
    if not canBuyCondition then
        return false, conditionReason
    end
    
    -- 检查VIP需求
    local canBuyVip, vipReason = self:CheckVipRequirement(player.vipLevel or 0)
    if not canBuyVip then
        return false, vipReason
    end
    
    -- 检查时效性
    local canBuyTime, timeReason = self:IsInValidTime()
    if not canBuyTime then
        return false, timeReason
    end
    
    -- 检查限购（这里需要从玩家的购买记录中获取当前购买次数）
    -- 由于这里无法直接访问玩家的购买记录，我们只做基础验证
    local limitType = self.limitConfig.limitType
    local limitCount = self.limitConfig.limitCount
    
    if limitType == "无限制" then
        return true, "可以购买"
    elseif limitType == "永久一次" then
        -- 这里需要从玩家数据中检查是否已购买过
        return true, "可以购买（永久一次）"
    elseif limitType == "每日限制" or limitType == "每周限制" or limitType == "每月限制" then
        -- 这里需要从玩家数据中检查当前周期的购买次数
        return true, "可以购买（" .. limitType .. "）"
    end
    
    return true, "可以购买"
end

--- 检查是否在有效时间内
---@return boolean, string 是否在有效时间内，原因
function ShopItemType:IsInValidTime()
    local timeConfig = self.specialProperties.timeConfig
    if not timeConfig.isLimited then
        return true, "无时间限制"
    end
    
    -- 这里可以根据实际需求实现时间检查逻辑
    -- 暂时返回true，实际使用时需要根据当前时间判断
    return true, "在有效时间内"
end

--- 检查VIP需求
---@param playerVipLevel number 玩家VIP等级
---@return boolean, string 是否满足VIP需求，失败原因
function ShopItemType:CheckVipRequirement(playerVipLevel)
    local vipReq = self.specialProperties.vipRequirement
    if not vipReq.requireVip then
        return true, "无VIP要求"
    end
    
    if playerVipLevel >= vipReq.vipLevel then
        return true, "VIP等级满足要求"
    else
        return false, string.format("VIP等级不足，需要%d级", vipReq.vipLevel)
    end
end

--- 获取商品总价值（用于排序）
---@return number 商品价值
function ShopItemType:GetTotalValue()
    local baseValue = self.price.amount or 0
    local sortWeight = self.uiConfig.sortWeight or 0
    
    -- 根据标签调整价值
    if self.uiConfig.hotSaleTag then
        baseValue = baseValue * 1.2
    end
    if self.uiConfig.limitedTag then
        baseValue = baseValue * 1.5
    end
    if self.uiConfig.recommendedTag then
        baseValue = baseValue * 1.3
    end
    
    return baseValue + sortWeight
end

--- 获取商品显示名称
---@return string 显示名称
function ShopItemType:GetDisplayName()
    local displayName = self.configName
    
    -- 添加标签前缀
    if self.uiConfig.limitedTag then
        displayName = "[限定] " .. displayName
    end
    if self.uiConfig.hotSaleTag then
        displayName = "[热卖] " .. displayName
    end
    if self.uiConfig.recommendedTag then
        displayName = "[推荐] " .. displayName
    end
    
    return displayName
end

--- 获取商品描述信息
---@return string 描述信息
function ShopItemType:GetDescription()
    local desc = self.description
    
    -- 添加限购信息
    if self.limitConfig.limitType ~= "无限制" then
        desc = desc .. "\n限购类型: " .. self.limitConfig.limitType
        if self.limitConfig.limitCount > 0 then
            desc = desc .. " (" .. self.limitConfig.limitCount .. "次)"
        end
    end
    
    -- 添加VIP需求信息
    if self.specialProperties.vipRequirement.requireVip then
        desc = desc .. "\n需要VIP等级: " .. self.specialProperties.vipRequirement.vipLevel
    end
    
    return desc
end

function ShopItemType:GetToStringParams()
    return {
        configName = self.configName,
        category = self.category,
        price = self.price.amount
    }
end

--- 是否为限购商品
---@return boolean 是否限购
function ShopItemType:IsLimitedPurchase()
    return self.limitConfig.limitType ~= "无限制"
end

--- 获取限购显示文本
---@return string 限购文本
function ShopItemType:GetLimitText()
    local limitType = self.limitConfig.limitType
    local limitCount = self.limitConfig.limitCount
    
    if limitType == "无限制" then
        return "无限购"
    elseif limitType == "永久" then
        return string.format("限购%d次", limitCount)
    else
        return string.format("%s限购%d次", limitType, limitCount)
    end
end

--- 获取折扣价格（如果有活动）
---@return number 折扣后价格
function ShopItemType:GetDiscountPrice()
    local originalPrice = self.price.amount
    
    -- 可以根据活动系统计算折扣
    if self.uiConfig.hotSaleTag then
        return math.floor(originalPrice * 0.8) -- 热卖8折
    end
    
    return originalPrice
end

--- 格式化价格显示
---@return string 价格文本
function ShopItemType:FormatPriceText()
    local discountPrice = self:GetDiscountPrice()
    local originalPrice = self.price.amount
    local currencyType = self.price.currencyType
    
    if discountPrice < originalPrice then
        return string.format("~~%d~~ %d %s", originalPrice, discountPrice, currencyType)
    else
        return string.format("%d %s", originalPrice, currencyType)
    end
end

--- 生成购买日志
---@param player MPlayer 玩家对象
---@return string 日志文本
function ShopItemType:GeneratePurchaseLog(player)
    return string.format("玩家[%s]购买商品[%s]，价格[%s]", 
        player.name, 
        self.configName, 
        self:FormatPriceText()
    )
end

--- 验证商品配置数据完整性
---@return boolean, string 是否有效，错误信息
function ShopItemType:ValidateConfig()
    if not self.configName or self.configName == "" then
        return false, "商品名不能为空"
    end
    
    if not self.price or not self.price.amount or self.price.amount < 0 then
        return false, "价格配置无效"
    end
    
    if not self.rewards or #self.rewards == 0 then
        return false, "奖励配置不能为空"
    end
    
    return true, "配置有效"
end

-- 获取商品价格信息
function ShopItemType:GetCost()
    if not self.price then return nil end
    
    local MConfig = require(MainStorage.Code.Common.GameConfig.MConfig) ---@type common_config
    
    -- 根据货币类型返回对应的价格信息
    local currencyType = self.price.currencyType
    local amount = self.price.amount or 0
    
    if currencyType == "迷你币" then
        return { item = MConfig.CurrencyType.MiniCoin, amount = amount }
    elseif currencyType == "金币" then
        return { item = "金币", amount = amount }
    else
        return { item = currencyType, amount = amount }
    end
end

-- 获取商品图标路径
function ShopItemType:GetIconPath()
    if self.uiConfig and self.uiConfig.iconPath then
        return self.uiConfig.iconPath
    end
    return ""
end

-- 获取商品背景样式
function ShopItemType:GetBackgroundStyle()
    if self.uiConfig and self.uiConfig.backgroundStyle then
        return self.uiConfig.backgroundStyle
    end
    return "N"
end

-- 检查是否为热卖商品
function ShopItemType:IsHotSale()
    return self.uiConfig and self.uiConfig.hotSaleTag == true
end

-- 检查是否为限定商品
function ShopItemType:IsLimited()
    return self.uiConfig and self.uiConfig.limitedTag == true
end

-- 检查是否为推荐商品
function ShopItemType:IsRecommended()
    return self.uiConfig and self.uiConfig.recommendedTag == true
end

-- 获取排序权重
function ShopItemType:GetSortWeight()
    if self.uiConfig and self.uiConfig.sortWeight then
        return self.uiConfig.sortWeight
    end
    return 0
end

return ShopItemType
