-- LotteryMgr.lua
-- 抽奖系统管理器 - 静态类
-- 负责管理所有在线玩家的抽奖数据实例，提供系统级接口

local game = game
local os = os
local table = table
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local LotteryCloudDataMgr = require(ServerStorage.MSystems.Lottery.LotteryCloudDataMgr) ---@type LotteryCloudDataMgr
local LotterySystem = require(ServerStorage.MSystems.Lottery.LotterySystem) ---@type LotterySystem
local PlayerRewardDispatcher = require(ServerStorage.MiniGameMgr.PlayerRewardDispatcher) ---@type PlayerRewardDispatcher

---@class LotteryMgr
local LotteryMgr = {
    -- 在线玩家抽奖系统实例缓存 {uin = LotterySystem实例}
    server_player_lottery = {}, ---@type table<number, LotterySystem>

    -- 定时保存间隔（秒）
    SAVE_INTERVAL = 60
}

--- 玩家上线处理
---@param player MPlayer 玩家对象
function LotteryMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        gg.log("抽奖系统：玩家上线处理失败，玩家对象无效")
        return
    end

    local uin = player.uin
    gg.log("抽奖系统：开始处理玩家上线", uin)

    -- 从云端加载玩家抽奖数据
    local playerLotteryData = LotteryCloudDataMgr.LoadPlayerLotteryData(uin)

    -- 创建LotterySystem实例并缓存
    local lotterySystem = LotterySystem.New(uin, playerLotteryData)
    LotteryMgr.server_player_lottery[uin] = lotterySystem

    gg.log("抽奖系统：玩家抽奖管理器加载完成", uin, "总抽奖次数", lotterySystem.totalDrawCount)
end

--- 玩家离线处理
---@param uin number 玩家ID
function LotteryMgr.OnPlayerLeave(uin)
    local lotterySystem = LotteryMgr.server_player_lottery[uin]
    if lotterySystem then
        -- 提取数据并保存到云端
        local playerLotteryData = lotterySystem:GetData()
        if playerLotteryData then
            LotteryCloudDataMgr.SavePlayerLotteryData(uin, playerLotteryData)
        end

        -- 清理内存缓存
        LotteryMgr.server_player_lottery[uin] = nil
        gg.log("抽奖系统：玩家抽奖数据已保存并清理", uin)
    end
end

--- 获取玩家抽奖系统实例
---@param uin number 玩家ID
---@return LotterySystem|nil 抽奖系统实例
function LotteryMgr.GetPlayerLottery(uin)
    local lotterySystem = LotteryMgr.server_player_lottery[uin]
    if not lotterySystem then
        gg.log("抽奖系统：在缓存中未找到玩家", uin, "的抽奖管理器，尝试动态加载")
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        
        if player then
            LotteryMgr.OnPlayerJoin(player)
            return LotteryMgr.server_player_lottery[uin]
        else
            gg.log("抽奖系统：未找到玩家", uin, "无法动态加载抽奖管理器")
        end
    end
    
    return lotterySystem
end

--- 执行单次抽奖
---@param uin number 玩家ID
---@param poolName string 抽奖池名称
---@return table 抽奖结果
function LotteryMgr.SingleDraw(uin, poolName)
    gg.log("=== 开始单次抽奖 ===")
    gg.log("玩家UIN:", uin, "抽奖池:", poolName)
    
    local lotterySystem = LotteryMgr.GetPlayerLottery(uin)
    if not lotterySystem then
        gg.log("错误：抽奖系统未初始化")
        return {
            success = false,
            errorMsg = "抽奖系统未初始化"
        }
    end

    -- 检查消耗
    gg.log("开始检查抽奖消耗...")
    local canConsume, consumeError = LotteryMgr.CheckAndConsumeCost(uin, poolName, "single")
    if not canConsume then
        gg.log("消耗检查失败:", consumeError)
        return {
            success = false,
            errorMsg = consumeError
        }
    end

    -- 执行抽奖
    gg.log("开始执行抽奖逻辑...")
    local result = lotterySystem:PerformDraw(poolName, "single")
    
    -- 发放奖励
    if result.success then
        gg.log("抽奖成功，开始发放奖励...")
        LotteryMgr.GrantRewards(uin, result.rewards)
    else
        gg.log("抽奖失败:", result.errorMsg)
    end

    gg.log("=== 单次抽奖完成 ===")
    return result
end

--- 执行五连抽
---@param uin number 玩家ID
---@param poolName string 抽奖池名称
---@return table 抽奖结果
function LotteryMgr.FiveDraw(uin, poolName)
    gg.log("=== 开始五连抽 ===")
    gg.log("玩家UIN:", uin, "抽奖池:", poolName)
    
    local lotterySystem = LotteryMgr.GetPlayerLottery(uin)
    if not lotterySystem then
        gg.log("错误：抽奖系统未初始化")
        return {
            success = false,
            errorMsg = "抽奖系统未初始化"
        }
    end

    -- 检查消耗
    gg.log("开始检查抽奖消耗...")
    local canConsume, consumeError = LotteryMgr.CheckAndConsumeCost(uin, poolName, "five")
    if not canConsume then
        gg.log("消耗检查失败:", consumeError)
        return {
            success = false,
            errorMsg = consumeError
        }
    end

    -- 执行抽奖
    gg.log("开始执行抽奖逻辑...")
    local result = lotterySystem:PerformDraw(poolName, "five")
    
    -- 发放奖励
    if result.success then
        gg.log("抽奖成功，开始发放奖励...")
        LotteryMgr.GrantRewards(uin, result.rewards)
    else
        gg.log("抽奖失败:", result.errorMsg)
    end

    gg.log("=== 五连抽完成 ===")
    return result
end

--- 执行十连抽
---@param uin number 玩家ID
---@param poolName string 抽奖池名称
---@return table 抽奖结果
function LotteryMgr.TenDraw(uin, poolName)
    local lotterySystem = LotteryMgr.GetPlayerLottery(uin)
    if not lotterySystem then
        return {
            success = false,
            errorMsg = "抽奖系统未初始化"
        }
    end

    -- 检查消耗
    local canConsume, consumeError = LotteryMgr.CheckAndConsumeCost(uin, poolName, "ten")
    if not canConsume then
        return {
            success = false,
            errorMsg = consumeError
        }
    end

    -- 执行抽奖
    local result = lotterySystem:PerformDraw(poolName, "ten")
    
    -- 发放奖励
    if result.success then
        LotteryMgr.GrantRewards(uin, result.rewards)
    end

    return result
end

--- 检查并扣除抽奖消耗
---@param uin number 玩家ID
---@param poolName string 抽奖池名称
---@param drawType string 抽奖类型
---@return boolean, string 是否成功，错误信息
function LotteryMgr.CheckAndConsumeCost(uin, poolName, drawType)
    gg.log("=== 开始检查抽奖消耗 ===")
    gg.log("玩家UIN:", uin, "抽奖池:", poolName, "抽奖类型:", drawType)
    
    -- 获取抽奖配置
    gg.log("正在获取抽奖配置，ConfigLoader类型:", type(ConfigLoader))
    local lotteryConfig = ConfigLoader.GetLottery(poolName)
    gg.log("GetLottery调用结果:", lotteryConfig)
    
    if not lotteryConfig then
        gg.log("错误：抽奖池配置不存在，poolName:", poolName)
        return false, "抽奖池配置不存在"
    end

    local cost = lotteryConfig:GetCost(drawType)
    if not cost then
        gg.log("错误：抽奖消耗配置不存在，drawType:", drawType)
        return false, "抽奖消耗配置不存在"
    end

    -- 检查背包系统中的货币
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local BagMgr = serverDataMgr.BagMgr ---@type BagMgr
    
    if not BagMgr then
        gg.log("错误：背包系统未初始化")
        return false, "背包系统未初始化"
    end

    local playerBag = BagMgr.GetPlayerBag(uin)
    if not playerBag then
        gg.log("错误：玩家背包未找到，UIN:", uin)
        return false, "玩家背包未找到"
    end

    -- 检查是否有足够的货币
    local hasEnough = playerBag:HasItems({ [cost.costItem] = cost.costAmount })
    if not hasEnough then
        gg.log("错误：货币不足，需要:", cost.costAmount, "当前货币:" ,playerBag:GetItemAmount(cost.costItem))
        return false, "货币不足"
    end

    -- 扣除货币
    local success = playerBag:RemoveItems({ [cost.costItem] = cost.costAmount })
    if not success then
        gg.log("错误：扣除货币失败")
        return false, "扣除货币失败"
    end

    gg.log("=== 抽奖消耗检查完成，扣除成功 ===")
    return true, ""
end

--- 发放抽奖奖励
---@param uin number 玩家ID
---@param rewards LotteryRecord[] 奖励列表
function LotteryMgr.GrantRewards(uin, rewards)
    gg.log("=== 开始发放抽奖奖励 ===")
    gg.log("玩家UIN:", uin, "奖励数量:", #rewards)

    -- 获取玩家对象
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    
    if not player then
        gg.log("错误：未找到玩家对象，UIN:", uin)
        return
    end

    -- 转换抽奖奖励格式为 PlayerRewardDispatcher 标准格式
    local rewardList = {}
    for _, reward in ipairs(rewards) do
        local rewardData = {
            itemType = reward.rewardType,
            itemName = reward.rewardName,
            amount = reward.quantity or 1
        }
        table.insert(rewardList, rewardData)
    end

    -- 使用统一奖励分发器发放奖励
    local success, resultMsg, failedRewards = PlayerRewardDispatcher.DispatchRewards(player, rewardList)
    
    if success then
        gg.log("=== 抽奖奖励发放完成 ===")
        gg.log("抽奖系统：为玩家", uin, "发放了", #rewards, "个奖励")
    else
        gg.log("=== 抽奖奖励发放失败 ===")
        gg.log("抽奖系统：玩家", uin, "奖励发放失败:", resultMsg)
        
        -- 记录失败的奖励详情
        if failedRewards and #failedRewards > 0 then
            for _, failedReward in ipairs(failedRewards) do
                gg.log("失败奖励:", failedReward.reward.itemType, failedReward.reward.itemName, "错误:", failedReward.error)
            end
        end
    end
end

--- 获取玩家抽奖数据
---@param uin number 玩家ID
---@param poolName string|nil 抽奖池名称（nil为全部）
---@return table 抽奖数据
function LotteryMgr.GetPlayerLotteryData(uin, poolName)
    local lotterySystem = LotteryMgr.GetPlayerLottery(uin)
    if not lotterySystem then
        return {
            success = false,
            errorMsg = "抽奖系统未初始化"
        }
    end

    if poolName then
        -- 返回指定抽奖池数据
        return {
            success = true,
            poolData = lotterySystem:GetPoolData(poolName),
            pityProgress = lotterySystem:GetPityProgress(poolName),
            poolStats = lotterySystem:GetPoolStats(poolName)
        }
    else
        -- 返回全部数据
        return {
            success = true,
            lotteryPools = lotterySystem.lotteryPools,
            totalDrawCount = lotterySystem.totalDrawCount,
            poolStats = lotterySystem.poolStats
        }
    end
end

--- 获取玩家抽奖历史
---@param uin number 玩家ID
---@param poolName string|nil 抽奖池名称（nil为全部）
---@param limit number|nil 限制条数
---@return table 历史记录
function LotteryMgr.GetPlayerDrawHistory(uin, poolName, limit)
    local lotterySystem = LotteryMgr.GetPlayerLottery(uin)
    if not lotterySystem then
        return {
            success = false,
            errorMsg = "抽奖系统未初始化"
        }
    end

    local history = lotterySystem:GetDrawHistory(poolName, limit)
    return {
        success = true,
        history = history,
        total = #history
    }
end

--- 检查抽奖池是否可用
---@param poolName string 抽奖池名称
---@return boolean 是否可用
function LotteryMgr.IsPoolAvailable(poolName)
    local lotteryConfig = ConfigLoader.GetLottery(poolName)
    return lotteryConfig ~= nil and lotteryConfig:IsEnabled()
end

--- 获取所有可用的抽奖池
---@return string[] 抽奖池名称列表
function LotteryMgr.GetAvailablePools()
    local pools = {}
    local allConfigs = ConfigLoader.GetAllLotteries()
    
    for poolName, config in pairs(allConfigs) do
        if config:IsEnabled() then
            table.insert(pools, poolName)
        end
    end
    
    return pools
end


---保存指定玩家的抽奖数据（供统一存盘机制调用）
---@param uin number 玩家ID
function LotteryMgr.SavePlayerLotteryData(uin)
    local lotterySystem = LotteryMgr.server_player_lottery[uin]
    if lotterySystem then
        local playerData = lotterySystem:GetData()
        if playerData then
            LotteryCloudDataMgr.SavePlayerLotteryData(uin, playerData)
            -- gg.log("统一存盘：已保存玩家", uin, "的抽奖数据")
        end
    end
end

return LotteryMgr