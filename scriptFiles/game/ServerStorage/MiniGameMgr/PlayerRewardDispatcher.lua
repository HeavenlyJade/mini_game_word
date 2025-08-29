-- PlayerRewardDispatcher.lua
-- 玩家奖励分发器 - 统一处理所有奖励发放逻辑

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class PlayerRewardDispatcher 玩家奖励分发器（静态类）
local PlayerRewardDispatcher = {}

-- 延迟加载各子系统管理器，避免循环引用
local function getBagMgr()
    return require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
end

local function getPetMgr()
    return require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr
end

local function getPartnerMgr()
    return require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
end

local function getWingMgr()
    return require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
end

local function getTrailMgr()
    return require(ServerStorage.MSystems.Trail.TrailMgr) ---@type TrailMgr
end

local function getCommandManager()
    return require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager
end

--- 奖励类型定义
local RewardType = {
    ITEM = "物品",           -- 背包物品
    PET = "宠物",            -- 宠物
    PARTNER = "伙伴",        -- 伙伴
    WING = "翅膀",           -- 翅膀
    TRAIL = "尾迹",          -- 尾迹
    COMMAND = "指令执行",    -- 指令执行
    VARIABLE = "玩家变量"    -- 玩家变量
}

--- 验证玩家对象
---@param player MPlayer 玩家对象
---@return boolean 是否有效
local function validatePlayer(player)
    return player and player.uin and player.name
end

--- 验证奖励数据
---@param reward table 奖励数据
---@return boolean 是否有效
local function validateReward(reward)
    return reward and reward.itemType and 
           (reward.itemName or reward.variableName or reward.value)  -- 支持玩家变量的value字段
end

--- 发放单个奖励
---@param player MPlayer 玩家对象
---@param reward table 奖励数据
---@return boolean 是否成功
---@return string|nil 错误信息
local function dispatchSingleReward(player, reward)
    local itemType = reward.itemType
    local itemName = reward.itemName
    local amount = reward.amount or 1
    
    if itemType == RewardType.ITEM then
        -- 发放背包物品
        if not itemName or itemName == "" then
            return false, "奖励配置无效：物品名称缺失"
        end
        
        local BagMgr = getBagMgr()
        local success = BagMgr.AddItem(player, itemName, amount)
        if not success then
            return false, string.format("添加物品失败：%s x%d", itemName, amount)
        end
        
        --gg.log("物品发放成功", player.name, itemName, "x" .. amount)
        return true
        
    elseif itemType == RewardType.PET then
        -- 发放宠物
        if not itemName or itemName == "" then
            return false, "奖励配置无效：宠物名称缺失"
        end
        
        local PetMgr = getPetMgr()
        local success, actualSlot = PetMgr.AddPet(player, itemName)
        if not success then
            return false, string.format("添加宠物失败：%s", itemName)
        end
        
        --gg.log("宠物发放成功", player.name, itemName, "槽位", actualSlot)
        return true
        
    elseif itemType == RewardType.PARTNER then
        -- 发放伙伴
        if not itemName or itemName == "" then
            return false, "奖励配置无效：伙伴名称缺失"
        end
        
        local PartnerMgr = getPartnerMgr()
        local success, actualSlot = PartnerMgr.AddPartner(player, itemName)
        if not success then
            return false, string.format("添加伙伴失败：%s", itemName)
        end
        
        --gg.log("伙伴发放成功", player.name, itemName, "槽位", actualSlot)
        return true
        
    elseif itemType == RewardType.WING then
        -- 发放翅膀
        if not itemName or itemName == "" then
            return false, "奖励配置无效：翅膀名称缺失"
        end
        
        local WingMgr = getWingMgr()
        local success, actualSlot = WingMgr.AddWing(player, itemName)
        if not success then
            return false, string.format("添加翅膀失败：%s", itemName)
        end
        
        --gg.log("翅膀发放成功", player.name, itemName, "槽位", actualSlot)
        return true
        
    elseif itemType == RewardType.TRAIL then
        -- 发放尾迹
        if not itemName or itemName == "" then
            return false, "奖励配置无效：尾迹名称缺失"
        end
        
        local TrailMgr = getTrailMgr()
        local success, actualSlot = TrailMgr.AddTrail(player, itemName)
        if not success then
            return false, string.format("添加尾迹失败：%s", itemName)
        end
        
        --gg.log("尾迹发放成功", player.name, itemName, "槽位", actualSlot)
        return true
        
    elseif itemType == RewardType.COMMAND then
        -- 执行指令
        local commandStr = reward.variableName
        if not commandStr or commandStr == "" then
            return false, "奖励配置无效：指令字符串缺失"
        end
        
        local CommandManager = getCommandManager()
        CommandManager.ExecuteCommand(commandStr, player, true)
        
        --gg.log("指令执行成功", player.name, commandStr)
        return true
        
    elseif itemType == RewardType.VARIABLE then
        -- 设置玩家变量
        local variableName = reward.variableName or reward.itemName
        local value = reward.value or reward.amount or 0
        
        if not variableName or variableName == "" then
            return false, "奖励配置无效：变量名称缺失"
        end
        
        if not player.variableSystem then
            return false, "玩家变量系统未初始化"
        end
        
        -- 根据数值正负判断操作类型
        if value > 0 then
            player.variableSystem:AddVariable(variableName, value)
            --gg.log("玩家变量增加成功", player.name, variableName, "+" .. value)
        elseif value < 0 then
            player.variableSystem:SubtractVariable(variableName, math.abs(value))
            --gg.log("玩家变量减少成功", player.name, variableName, value)
        else
            --gg.log("玩家变量数值为0，跳过操作", player.name, variableName)
        end
        
        return true
        
    else
        return false, string.format("不支持的奖励类型：%s", itemType or "未知")
    end
end

--- 同步数据到客户端
---@param player MPlayer 玩家对象
---@param stats table 发放统计
local function syncDataToClient(player, stats)
    -- 按需同步，仅在对应类型发放过奖励时同步一次

    local BagMgr = getBagMgr()
    if BagMgr then
        --gg.log("开始同步背包数据到客户端", player.uin)
        BagMgr.ForceSyncToClient(player.uin)
        --gg.log("背包数据同步完成", player.uin)
    else
        --gg.log("警告：无法获取背包管理器", player.uin)
    end
    
    if stats.pet > 0 then
        local PetMgr = getPetMgr()
        if PetMgr then
            PetMgr.ForceSyncToClient(player.uin)
        end
    end
    
    if stats.partner > 0 then
        local PartnerMgr = getPartnerMgr()
        if PartnerMgr then
            PartnerMgr.ForceSyncToClient(player.uin)
        end
    end
    
    if stats.wing > 0 then
        local WingMgr = getWingMgr()
        if WingMgr then
            WingMgr.ForceSyncToClient(player.uin)
        end
    end
    
    if stats.trail > 0 then
        local TrailMgr = getTrailMgr()
        if TrailMgr then
            TrailMgr.ForceSyncToClient(player.uin)
        end
    end
    
    if stats.variable > 0 then
        -- 同步玩家变量数据到客户端
        if player.variableSystem then
            local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
            local allVars = player.variableSystem.variables
            gg.network_channel:fireClient(player.uin, {
                cmd = EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE,
                variableData = allVars,
            })
        end
    end
end

--- 统计奖励类型
---@param rewards table 奖励列表
---@return table 统计结果
local function calculateStats(rewards)
    local stats = { bag = 0, pet = 0, partner = 0, wing = 0, trail = 0, command = 0, variable = 0 }
    
    for _, reward in ipairs(rewards) do
        local itemType = reward.itemType
        if itemType == RewardType.ITEM then
            stats.bag = stats.bag + 1
        elseif itemType == RewardType.PET then
            stats.pet = stats.pet + 1
        elseif itemType == RewardType.PARTNER then
            stats.partner = stats.partner + 1
        elseif itemType == RewardType.WING then
            stats.wing = stats.wing + 1
        elseif itemType == RewardType.TRAIL then
            stats.trail = stats.trail + 1
        elseif itemType == RewardType.COMMAND then
            stats.command = stats.command + 1
        elseif itemType == RewardType.VARIABLE then
            stats.variable = stats.variable + 1
        end
    end
    
    return stats
end

-- ============================= 公共接口 ============================= 

--- 分发奖励给玩家
---@param player MPlayer 玩家对象
---@param rewards table 奖励列表
---@return boolean 是否全部成功
---@return string 结果消息
---@return table|nil 失败的奖励列表
function PlayerRewardDispatcher.DispatchRewards(player, rewards)
    -- 参数验证
    if not validatePlayer(player) then
        return false, "玩家对象无效", nil
    end
    
    if not rewards or type(rewards) ~= "table" or #rewards == 0 then
        return true, "无奖励需要发放", nil
    end
    
    --gg.log("开始发放奖励", player.name, "奖励数量", #rewards)
    
    local failedRewards = {}
    local successCount = 0
    local stats = calculateStats(rewards)
    
    -- 逐个发放奖励
    for i, reward in ipairs(rewards) do
        if not validateReward(reward) then
            table.insert(failedRewards, {
                index = i,
                reward = reward,
                error = "奖励数据格式无效"
            })
        else
            local success, errorMsg = dispatchSingleReward(player, reward)
            if success then
                successCount = successCount + 1
            else
                table.insert(failedRewards, {
                    index = i,
                    reward = reward,
                    error = errorMsg
                })
            end
        end
    end
    
    -- 同步数据到客户端
    syncDataToClient(player, stats)
    
    -- 生成结果消息
    local resultMsg
    if #failedRewards == 0 then
        resultMsg = string.format("奖励发放完成，共发放 %d 个奖励", successCount)
    else
        resultMsg = string.format("奖励发放完成，成功 %d 个，失败 %d 个", successCount, #failedRewards)
    end
    
    -- gg.log("奖励发放结果", player.name, resultMsg, 
    --        "物品:", stats.bag, "宠物:", stats.pet, "伙伴:", stats.partner, 
    --        "翅膀:", stats.wing, "尾迹:", stats.trail, "指令:", stats.command, "变量:", stats.variable)
    
    return #failedRewards == 0, resultMsg, #failedRewards > 0 and failedRewards or nil
end

--- 分发单个奖励给玩家（便捷接口）
---@param player MPlayer 玩家对象
---@param itemType string 奖励类型
---@param itemName string 奖励名称
---@param amount number|nil 数量（默认1）
---@param variableName string|nil 变量名称（指令执行或玩家变量时使用）
---@param value number|nil 变量值（玩家变量时使用）
---@return boolean 是否成功
---@return string|nil 错误信息
function PlayerRewardDispatcher.DispatchSingleReward(player, itemType, itemName, amount, variableName, value)
    local reward = {
        itemType = itemType,
        itemName = itemName,
        amount = amount or 1,
        variableName = variableName,
        value = value
    }
    
    local success, resultMsg, failedRewards = PlayerRewardDispatcher.DispatchRewards(player, {reward})
    
    if not success and failedRewards and #failedRewards > 0 then
        return false, failedRewards[1].error
    end
    
    return success, success and nil or resultMsg
end

--- 检查玩家是否有足够空间接收奖励
---@param player MPlayer 玩家对象
---@param rewards table 奖励列表
---@return boolean 是否有足够空间
---@return string|nil 错误信息
function PlayerRewardDispatcher.CheckRewardSpace(player, rewards)
    if not validatePlayer(player) then
        return false, "玩家对象无效"
    end
    
    if not rewards or type(rewards) ~= "table" or #rewards == 0 then
        return true, nil
    end
    
    -- 检查各类型槽位空间
    for _, reward in ipairs(rewards) do
        if validateReward(reward) then
            local itemType = reward.itemType
            
            if itemType == RewardType.PET then
                local PetMgr = getPetMgr()
                if not PetMgr.HasAvailableSlot(player.uin) then
                    return false, "宠物槽位已满"
                end
                
            elseif itemType == RewardType.PARTNER then
                local PartnerMgr = getPartnerMgr()
                if not PartnerMgr.HasAvailableSlot(player.uin) then
                    return false, "伙伴槽位已满"
                end
                
            elseif itemType == RewardType.WING then
                local WingMgr = getWingMgr()
                if not WingMgr.HasAvailableSlot(player.uin) then
                    return false, "翅膀槽位已满"
                end
                
            elseif itemType == RewardType.TRAIL then
                local TrailMgr = getTrailMgr()
                if not TrailMgr.HasAvailableSlot(player.uin) then
                    return false, "尾迹槽位已满"
                end
            end
        end
    end
    
    return true, nil
end

--- 获取支持的奖励类型列表
---@return table 奖励类型列表
function PlayerRewardDispatcher.GetSupportedRewardTypes()
    return {
        RewardType.ITEM,
        RewardType.PET,
        RewardType.PARTNER,
        RewardType.WING,
        RewardType.TRAIL,
        RewardType.COMMAND,
        RewardType.VARIABLE
    }
end

--- 玩家变量奖励便捷接口
---@param player MPlayer 玩家对象
---@param variableName string 变量名称
---@param value number 变量值（正数为增加，负数为减少）
---@return boolean 是否成功
---@return string|nil 错误信息
function PlayerRewardDispatcher.DispatchVariable(player, variableName, value)
    return PlayerRewardDispatcher.DispatchSingleReward(player, RewardType.VARIABLE, nil, nil, variableName, value)
end

--- 指令执行奖励便捷接口
---@param player MPlayer 玩家对象
---@param commandStr string 指令字符串
---@return boolean 是否成功
---@return string|nil 错误信息
function PlayerRewardDispatcher.DispatchCommand(player, commandStr)
    return PlayerRewardDispatcher.DispatchSingleReward(player, RewardType.COMMAND, nil, nil, commandStr)
end

return PlayerRewardDispatcher