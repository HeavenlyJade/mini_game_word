-- AutoPlayManager.lua
-- 自动挂机管理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local SceneNodeType = require(MainStorage.Code.Common.TypeConfig.SceneNodeType) ---@type SceneNodeType
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask
local ActionCosteRewardCal = require(MainStorage.Code.GameReward.RewardCalc.ActionCosteRewardCal) ---@type ActionCosteRewardCal

---@class AutoPlayManager
local AutoPlayManager = {}

-- 存储玩家自动挂机状态
local playerAutoPlayState = {}

-- 初始化自动挂机管理器
function AutoPlayManager.Init()
    -- 启动定时检查
    AutoPlayManager.StartAutoPlayCheck()
end

-- 启动自动挂机检查定时器
function AutoPlayManager.StartAutoPlayCheck()
    local timer = ScheduledTask.AddInterval(5, "AutoPlayCheck", function()
        AutoPlayManager.CheckAllPlayersAutoPlay()
    end)
    
    gg.log("自动挂机检查定时器已启动，每5秒检查一次")
end

-- 检查所有玩家的自动挂机状态
function AutoPlayManager.CheckAllPlayersAutoPlay()
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    
    -- 检查是否有启用自动挂机的玩家
    local hasEnabledPlayers = false
    for uin, enabled in pairs(playerAutoPlayState) do
        if enabled then
            hasEnabledPlayers = true
            break
        end
    end
    
    -- 如果没有启用自动挂机的玩家，直接返回
    if not hasEnabledPlayers then
        return
    end
    
    -- 检查启用了自动挂机的玩家
    for uin, enabled in pairs(playerAutoPlayState) do
        if enabled then
            local player = MServerDataManager.getPlayerByUin(uin)
            if player then
                -- 检查玩家是否在挂机点
                local isInSpot = AutoPlayManager.IsPlayerInAutoPlaySpot(player)
                local currentSpot = player:GetCurrentIdleSpot()
                
                gg.log(string.format("玩家 %s (UIN: %s) 自动挂机检查 - 挂机状态: %s, 当前挂机点: %s", 
                    player.name, uin, 
                    isInSpot and "在挂机点" or "不在挂机点", 
                    currentSpot or "无"))
                
                if not isInSpot then
                    -- 玩家不在挂机点，重新寻找最佳挂机点
                    gg.log(string.format("玩家 %s 不在挂机点，开始寻找最佳挂机点", player.name))
                    AutoPlayManager.FindAndMoveToBestAutoPlaySpot(player)
                else
                    gg.log(string.format("玩家 %s 已在挂机点 %s，无需重新导航", player.name, currentSpot))
                end
            else
                -- 玩家不存在，清除状态
                playerAutoPlayState[uin] = nil
                gg.log(string.format("玩家 UIN: %s 不存在，已清除自动挂机状态", uin))
            end
        end
    end
end

-- 检查玩家是否在挂机点
---@param player MPlayer 玩家对象
---@return boolean 是否在挂机点
function AutoPlayManager.IsPlayerInAutoPlaySpot(player)
    if not player then
        return false
    end
    
    -- 直接使用玩家的挂机状态属性
    local isIdling = player:IsIdling()
    local currentSpot = player:GetCurrentIdleSpot()
    
    if isIdling and currentSpot then
        --gg.log(string.format("玩家 %s 正在挂机点: %s", player.name, currentSpot))
        return true
    end
    
    return false
end

-- 寻找并移动到最佳挂机点
---@param player MPlayer 玩家对象
function AutoPlayManager.FindAndMoveToBestAutoPlaySpot(player)
    if not player then return end
    
    local uin = player.uin
    local currentScene = player.currentScene
    
    gg.log("开始为玩家", uin, "寻找最佳挂机点，当前场景:", currentScene)
    
    -- 获取玩家历史最大战力值
    local historicalMaxPower = AutoPlayManager.GetPlayerHistoricalMaxPower(player)
    if not historicalMaxPower then
        gg.log("无法获取玩家历史最大战力值，跳过自动挂机")
        return
    end
    
    gg.log("玩家", uin, "的历史最大战力值:", historicalMaxPower)
    
    -- 获取当前场景的所有挂机点
    local autoPlayNodes = ConfigLoader.GetSceneNodesBy(currentScene, "挂机点")
    if #autoPlayNodes == 0 then
        gg.log("当前场景没有挂机点，跳过自动挂机")
        return
    end
    
    gg.log("找到", #autoPlayNodes, "个挂机点")
    
    -- 寻找最佳挂机点
    local bestSpot = AutoPlayManager.FindBestAutoPlaySpot(autoPlayNodes, player)
    if not bestSpot then
        gg.log("未找到合适的挂机点，跳过自动挂机")
        return
    end
    
    gg.log("找到最佳挂机点:", bestSpot.name, "，效率:", AutoPlayManager.CalculateEfficiency(bestSpot, player))
    
    -- 移动到最佳挂机点
    AutoPlayManager.MovePlayerToAutoPlaySpot(player, bestSpot)
end

-- 获取玩家历史最大战力值
---@param player MPlayer 玩家对象
---@return number|nil 历史最大战力值
function AutoPlayManager.GetPlayerHistoricalMaxPower(player)
    if not player then
        gg.log("玩家对象为空")
        return nil
    end
    
    if not player.variableSystem then
        gg.log("玩家变量系统为空")
        return nil
    end
    
    -- 从变量系统获取历史最大战力值
    local historicalMaxPower = player.variableSystem:GetVariable("数据_固定值_历史最大战力值")
    gg.log("从变量系统获取历史最大战力值:", historicalMaxPower)
    
    return historicalMaxPower
end

-- 寻找最佳挂机点
---@param autoPlayNodes SceneNodeType[] 挂机点列表
---@param player MPlayer 玩家对象
---@return SceneNodeType|nil 最佳挂机点
function AutoPlayManager.FindBestAutoPlaySpot(autoPlayNodes, player)
    local bestSpot = nil
    local bestEfficiency = 0
    
        -- 获取玩家历史最大战力值
    local playerPower = AutoPlayManager.GetPlayerHistoricalMaxPower(player)
    if not playerPower then
        gg.log("无法获取玩家战力值，无法筛选挂机点")
        return nil
    end
    
    gg.log("开始筛选挂机点，玩家战力:", playerPower)
    
    for _, node in ipairs(autoPlayNodes) do
        gg.log("检查挂机点:", node.name, "，作用描述:", node.effectDesc)
        
        -- 检查进入条件
        if AutoPlayManager.CheckEnterConditions(node, playerPower) then
            -- 计算挂机效率（从作用描述中提取）
            local efficiency = AutoPlayManager.CalculateEfficiency(node, player)
            gg.log("挂机点", node.name, "满足条件，效率:", efficiency)
            
            if efficiency > bestEfficiency then
                bestEfficiency = efficiency
                bestSpot = node
                gg.log("更新最佳挂机点:", node.name, "，新效率:", efficiency)
            end
        else
            gg.log("挂机点", node.name, "不满足条件")
        end
    end
    
    return bestSpot
end

-- 检查进入条件
---@param node SceneNodeType 挂机点节点
---@param playerPower number 玩家战力值
---@return boolean 是否满足进入条件
function AutoPlayManager.CheckEnterConditions(node, playerPower)
    if not node.enterConditions or #node.enterConditions == 0 then
        gg.log("挂机点", node.name, "无进入条件限制")
        return true -- 没有条件限制
    end
    
    gg.log("挂机点", node.name, "有", #node.enterConditions, "个进入条件")
    
    for _, condition in ipairs(node.enterConditions) do
        local formula = condition["条件公式"]
        if formula then
            gg.log("检查条件公式:", formula)
            -- 使用 ActionCosteRewardCal 逻辑直接检查条件
            -- 构建一个包含战力值的玩家数据结构
            local mockPlayerData = {
                variableData = {
                    ["数据_固定值_历史最大战力值"] = { base = playerPower }
                }
            }
            
            -- 检查条件是否满足
            local conditionCalculator = ActionCosteRewardCal.New()
            if not conditionCalculator:_CheckCondition(formula, mockPlayerData, {}, {}) then
                gg.log("玩家战力不足，不满足条件")
                return false -- 不满足条件
            else
                gg.log("玩家战力满足要求")
            end
        end
    end
    
    return true
end

-- 解析条件公式
---@param formula string 条件公式
---@param player MPlayer 玩家对象
---@return boolean 是否满足条件
function AutoPlayManager.ParseConditionFormula(formula, player)
    if not formula or formula == "" then
        return true -- 空条件默认满足
    end
    
    if not player then
        gg.log("玩家对象为空，无法解析条件公式")
        return false
    end
    
    -- 使用 ActionCosteRewardCal 的逻辑来检查条件
    local conditionCalculator = ActionCosteRewardCal.New()
    
    -- 获取玩家数据 - 使用MPlayer的GetConsumableData方法构建统一数据结构
    local playerData = player:GetConsumableData()
    
    -- 获取玩家的背包数据
    local bagData = {}
    if player.bagMgr then
        bagData = player.bagMgr
    end
    
    -- 构建外部上下文（如果需要的话）
    local externalContext = {}
    
    -- 直接使用ActionCosteRewardCal的_CheckCondition方法
    local result = conditionCalculator:_CheckCondition(formula, playerData, bagData, externalContext)
    
    gg.log("条件公式解析结果:", formula, "->", result)
    
    return result
end

-- 计算挂机效率（直接使用配置的“作数值的配置”）
---@param node SceneNodeType 挂机点节点
---@param player MPlayer 玩家对象
---@return number 挂机效率
function AutoPlayManager.CalculateEfficiency(node, player)
    local value = (node and node.effectValueConfig) or 0
    gg.log("计算挂机点", node and node.name or "", "的效率，作数值的配置:", value)
    return tonumber(value) or 0
end

-- 移动玩家到挂机点
---@param player MPlayer 玩家对象
---@param spot SceneNodeType 挂机点
function AutoPlayManager.MovePlayerToAutoPlaySpot(player, spot)
    if not player or not spot then return end
    
    local uin = player.uin
    
    -- 获取挂机点的导航节点位置
    local sceneNode = gg.GetChild(game.WorkSpace, spot.nodePath)
    if not sceneNode then
        gg.log("无法找到挂机点场景节点:", spot.nodePath)
        return
    end
    
    -- 使用包围盒节点作为导航目标
    local triggerBoxName = spot.areaConfig["包围盒节点"]
    local triggerBox = sceneNode[triggerBoxName]
    if not triggerBox then
        gg.log("无法找到挂机点包围盒:", triggerBoxName)
        return
    end
    
    -- 发送导航指令到客户端
    local targetPosition = triggerBox.Position
    local AutoRaceEventManager = require(ServerStorage.AutoRaceSystem.AutoRaceEvent) ---@type AutoRaceEventManager
    AutoRaceEventManager.SendNavigateToPosition(uin, targetPosition, "自动导航到最佳挂机点")
    
    gg.log("已发送导航指令给玩家", uin, "，目标挂机点:", spot.name)
end

-- 设置玩家自动挂机状态
---@param player MPlayer 玩家对象
---@param enabled boolean 是否启用自动挂机
function AutoPlayManager.SetPlayerAutoPlayState(player, enabled)
    if not player then return end
    
    local uin = player.uin
    if enabled then
        playerAutoPlayState[uin] = true
        -- 立即寻找最佳挂机点
        AutoPlayManager.FindAndMoveToBestAutoPlaySpot(player)
    else
        playerAutoPlayState[uin] = nil
    end
end

-- 检查玩家是否在自动挂机中
---@param player MPlayer 玩家实例
---@return boolean 是否在自动挂机中
function AutoPlayManager.IsPlayerAutoPlaying(player)
    if not player then return false end
    return playerAutoPlayState[player.uin] == true
end

return AutoPlayManager
