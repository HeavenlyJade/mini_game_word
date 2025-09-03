-- RewardBonus.lua
-- 奖励加成核心数据类
-- 单一职责：管理单个玩家的奖励加成数据

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local RewardBonusType = require(MainStorage.Code.Common.TypeConfig.RewardBonusType) ---@type RewardBonusType

---@class RewardBonus : Class
---@field uin number 玩家ID
---@field configName string 当前配置名称
---@field config RewardBonusType 配置引用
---@field playerProgress table 玩家进度数据
---@field claimedTiers table<number, boolean> 已领取等级记录
---@field lastResetTime number 上次重置时间
---@field totalClaimedCount number 累计领取次数
---@field lastClaimTime number 最后领取时间
local RewardBonus = ClassMgr.Class("RewardBonus")

--- 初始化
---@param uin number 玩家ID
---@param data table|nil 云数据
function RewardBonus:OnInit(uin, data)
    self.uin = uin
    
    if data then
        -- 从云数据加载
        self.configName = data.configName or "累计充值"
        self.playerProgress = data.playerProgress or {}
        self.claimedTiers = data.claimedTiers or {}
        self.lastResetTime = data.lastResetTime or 0
        self.totalClaimedCount = data.totalClaimedCount or 0
        self.lastClaimTime = data.lastClaimTime or 0
    else
        -- 创建默认数据
        self:CreateDefaultData()
    end
    
    -- 加载配置
    self:LoadConfig()
end

--- 创建默认数据
function RewardBonus:CreateDefaultData()
    self.configName = "累计充值"
    self.playerProgress = {
        totalRecharge = 0,      -- 累计充值金额
        totalConsume = 0,       -- 累计消费金额
        vipLevel = 0,           -- VIP等级
        lastRechargeTime = 0,   -- 最后充值时间
    }
    self.claimedTiers = {}
    self.lastResetTime = 0
    self.totalClaimedCount = 0
    self.lastClaimTime = 0
end

--- 加载配置
function RewardBonus:LoadConfig()
    self.config = ConfigLoader.GetRewardBonus(self.configName)
    if not self.config then
        gg.log("错误：找不到奖励加成配置", self.configName)
    end
end

--- 更新玩家进度
---@param progressType string 进度类型 ("totalRecharge", "totalConsume", "vipLevel")
---@param value number 新值
function RewardBonus:UpdateProgress(progressType, value)
    if not self.playerProgress then
        self.playerProgress = {}
    end
    
    local oldValue = self.playerProgress[progressType] or 0
    self.playerProgress[progressType] = value
    
    gg.log("更新玩家进度", self.uin, progressType, oldValue, "->", value)
end

--- 增加玩家进度
---@param progressType string 进度类型
---@param amount number 增加数量
function RewardBonus:AddProgress(progressType, amount)
    if not self.playerProgress then
        self.playerProgress = {}
    end
    
    local oldValue = self.playerProgress[progressType] or 0
    local newValue = oldValue + amount
    self.playerProgress[progressType] = newValue
    
    gg.log("增加玩家进度", self.uin, progressType, "+" .. amount, "总计:", newValue)
end

--- 获取可领取的奖励等级
---@return table 可领取的等级列表
function RewardBonus:GetAvailableTiers()
    if not self.config then
        return {}
    end
    
    local availableTiers = {}
    local tierList = self.config:GetRewardTierList()
    
    for i, tier in ipairs(tierList) do
        -- 检查是否已领取
        if not self.claimedTiers[i] then
            -- 检查条件是否满足
            if self:CheckTierCondition(tier) then
                table.insert(availableTiers, {
                    index = i,
                    tier = tier
                })
            end
        end
    end
    
    return availableTiers
end

--- 检查等级条件是否满足
---@param tier RewardTier 奖励等级
---@return boolean 是否满足条件
function RewardBonus:CheckTierCondition(tier)
    if not tier.ConditionFormula or tier.ConditionFormula == "" then
        return true -- 无条件限制
    end
    
    -- 计算条件公式
    return self:EvaluateCondition(tier.ConditionFormula)
end

--- 计算条件公式
---@param formula string 条件公式
---@return boolean 计算结果
function RewardBonus:EvaluateCondition(formula)
    if not formula or formula == "" then
        return true
    end
    
    -- 构建计算环境
    local env = {
        totalRecharge = self.playerProgress.totalRecharge or 0,
        totalConsume = self.playerProgress.totalConsume or 0,
        vipLevel = self.playerProgress.vipLevel or 0,
    }
    
    -- 简单的条件解析（支持 totalRecharge >= 100 这样的格式）
    local success, result = pcall(function()
        -- 替换变量
        local evalFormula = formula
        for key, value in pairs(env) do
            evalFormula = string.gsub(evalFormula, key, tostring(value))
        end
        
        -- 使用gg.eval计算
        return gg.eval(evalFormula)
    end)
    
    if success then
        return result == true or result == 1
    else
        gg.log("条件公式计算失败", formula, result)
        return false
    end
end

--- 领取奖励等级
---@param tierIndex number 等级索引
---@return table|nil, string|nil 奖励内容，错误信息
function RewardBonus:ClaimTier(tierIndex)
    if not self.config then
        return nil, "配置未加载"
    end
    
    local tierList = self.config:GetRewardTierList()
    local tier = tierList[tierIndex]
    if not tier then
        return nil, "等级不存在"
    end
    
    -- 检查是否已领取
    if self.claimedTiers[tierIndex] then
        return nil, "已经领取过该等级奖励"
    end
    
    -- 检查条件是否满足
    if not self:CheckTierCondition(tier) then
        return nil, "条件不满足"
    end
    
    -- 检查消耗迷你币
    if tier.CostMiniCoin > 0 then
        -- 这里需要调用消耗迷你币的逻辑
        -- 暂时跳过实现
    end
    
    -- 标记为已领取
    self.claimedTiers[tierIndex] = true
    self.totalClaimedCount = self.totalClaimedCount + 1
    self.lastClaimTime = gg.GetTimeStamp()
    
    -- 根据权重随机选择奖励
    local rewardItems = self:SelectRewardsByWeight(tier.RewardItemList, tier.Weight)
    
    gg.log("领取奖励等级成功", self.uin, tierIndex, "奖励数量:", #rewardItems)
    
    return rewardItems, nil
end

--- 根据权重选择奖励
---@param rewardItemList RewardItem[] 奖励列表
---@param weight number 权重
---@return RewardItem[] 选中的奖励
function RewardBonus:SelectRewardsByWeight(rewardItemList, weight)
    -- 简单实现：返回所有奖励
    -- 在实际项目中可以根据权重进行随机选择
    return rewardItemList
end

--- 获取状态信息
---@return table 状态信息
function RewardBonus:GetStatus()
    local availableTiers = self:GetAvailableTiers()
    
    return {
        configName = self.configName,
        playerProgress = self.playerProgress,
        claimedTiers = self.claimedTiers,
        availableTierCount = #availableTiers,
        availableTiers = availableTiers,
        totalClaimedCount = self.totalClaimedCount,
        lastClaimTime = self.lastClaimTime,
    }
end

--- 检查是否有可领取奖励
---@return boolean 是否有可领取奖励
function RewardBonus:HasAvailableRewards()
    local availableTiers = self:GetAvailableTiers()
    return #availableTiers > 0
end

--- 切换配置
---@param configName string 新配置名称
function RewardBonus:SwitchConfig(configName)
    if self.configName == configName then
        return -- 相同配置，无需切换
    end
    
    self.configName = configName
    self:LoadConfig()
    
    -- 清空已领取记录（切换配置后重新开始）
    self.claimedTiers = {}
    
    gg.log("切换奖励加成配置", self.uin, configName)
end

--- 获取保存数据
---@return table 保存数据
function RewardBonus:GetSaveData()
    return {
        lastSaveTime = gg.GetTimeStamp(),
        configName = self.configName,
        playerProgress = self.playerProgress,
        claimedTiers = self.claimedTiers,
        lastResetTime = self.lastResetTime,
        totalClaimedCount = self.totalClaimedCount,
        lastClaimTime = self.lastClaimTime,
    }
end

return RewardBonus