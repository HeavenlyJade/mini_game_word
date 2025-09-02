-- WingMgr.lua
-- 翅膀系统管理模块
-- 负责管理所有在线玩家的翅膀管理器，提供系统级接口

local game = game
local os = os
local table = table
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local RunService = game:GetService('RunService')
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local CloudWingDataAccessor = require(ServerStorage.MSystems.Pet.CloudData.WingCloudDataMgr) ---@type CloudWingDataAccessor
local Wing = require(ServerStorage.MSystems.Pet.Compainion.Wing) ---@type Wing
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class WingMgr
local WingMgr = {
    -- 在线玩家翅膀管理器缓存 {uin = Wing管理器实例}
    server_player_wings = {}, ---@type table<number, Wing>

    -- 定时保存间隔（秒）
    SAVE_INTERVAL = 60
}


---保存指定玩家的翅膀数据（供统一存盘机制调用）
---@param uin number 玩家ID
function WingMgr.SavePlayerWingData(uin)
    local wingManager = WingMgr.server_player_wings[uin]
    if wingManager then
        local playerWingData = wingManager:GetSaveData()
        if playerWingData then
            CloudWingDataAccessor:SavePlayerWingData(uin, playerWingData)
            --gg.log("统一存盘：已保存玩家", uin, "的翅膀数据")
        end
    end
end

---玩家上线处理
---@param player MPlayer 玩家对象
function WingMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        --gg.log("翅膀系统：玩家上线处理失败：玩家对象无效")
        return
    end

    local uin = player.uin
    --gg.log("开始处理玩家翅膀上线", uin)

    -- 从云端加载玩家翅膀数据
    local playerWingData = CloudWingDataAccessor:LoadPlayerWingData(uin)

    -- 创建Wing管理器实例并缓存
    local wingManager = Wing.New(uin, playerWingData)
    WingMgr.server_player_wings[uin] = wingManager

    --gg.log("玩家翅膀管理器加载完成", uin, "翅膀数量数据", playerWingData)
end

---玩家离线处理
---@param uin number 玩家ID
function WingMgr.OnPlayerLeave(uin)
    local wingManager = WingMgr.server_player_wings[uin]
    if wingManager then
        -- 提取数据并保存到云端
        local playerWingData = wingManager:GetSaveData()
        if playerWingData then
            CloudWingDataAccessor:SavePlayerWingData(uin, playerWingData)
        end

        -- 清理内存缓存
        WingMgr.server_player_wings[uin] = nil
        gg.log("玩家翅膀数据已保存并清理", uin)
        gg.log("玩家翅膀数据", gg.printTable(playerWingData))
    end
end

---获取玩家翅膀管理器
---@param uin number 玩家ID
---@return Wing|nil 翅膀管理器实例
function WingMgr.GetPlayerWing(uin)
    local wingManager = WingMgr.server_player_wings[uin]
    if not wingManager then
        --gg.log("翅膀系统：在缓存中未找到玩家", uin, "的翅膀管理器，尝试动态加载。")
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            WingMgr.OnPlayerJoin(player)
            wingManager = WingMgr.server_player_wings[uin]
        end

        if wingManager then
            --gg.log("翅膀系统：为玩家", uin, "动态加载翅膀管理器成功。")
        else
            --gg.log("翅膀系统：为玩家", uin, "动态加载翅膀管理器失败。")
        end
    end
    return wingManager
end

---设置激活翅膀
---@param uin number 玩家ID
---@param slotIndex number 槽位索引（0表示取消激活）
---@return boolean 是否成功
---@return string|nil 错误信息
function WingMgr.SetActiveWing(uin, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家数据不存在"
    end

    local success, errorMsg = wingManager:SetActiveWing(slotIndex)

    if success then
        --gg.log("翅膀激活状态设置成功", uin, slotIndex)
        -- 在这里添加更新模型的逻辑
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin) ---@type MPlayer
        if not player or not player.actor then
            --gg.log("错误：找不到玩家Actor，无法更新翅膀模型", uin)
            return success, errorMsg
        end

        local wingNode = player.actor:FindFirstChild("Wings1")
        if not wingNode then
            --gg.log("警告：在玩家Actor下未找到名为'Wings1'的节点", uin)
            return success, errorMsg
        end

        if slotIndex > 0 then
            -- 装备翅膀
            local activeWing = wingManager:GetActiveWing()
            if activeWing then
                local wingConfigName = activeWing:GetConfigName()
                if not wingConfigName then
                    --gg.log("错误：无法获取翅膀配置名称，隐藏节点", uin)
                    wingNode.Visible = false
                    return success, errorMsg
                end

                local wingConfig = ConfigLoader.GetWing(wingConfigName) ---@type PetType
                if wingConfig and wingConfig.modelResource and wingConfig.modelResource ~= "" then
                    wingNode.ModelId = wingConfig.modelResource
                    wingNode.Visible = true
                    --gg.log("成功更新玩家翅膀模型并显示节点", uin, wingConfig.modelResource)
                else
                    --gg.log("警告：翅膀没有配置模型资源或配置不存在，隐藏节点", uin, wingConfigName)
                    wingNode.Visible = false
                end
            else
                -- 安全起见，如果找不到激活的翅膀实例，也隐藏节点
                wingNode.Visible = false
            end
        else
            -- 卸下翅膀
            wingNode.Visible = false
            --gg.log("成功卸下翅膀并隐藏节点", uin)
        end
    end

    return success, errorMsg
end

---翅膀升级
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级，nil表示升1级
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否真的升级了
function WingMgr.LevelUpWing(uin, slotIndex, targetLevel)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家数据不存在", false
    end

    return wingManager:LevelUpWing(slotIndex, targetLevel)
end

---翅膀获得经验
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否升级了
function WingMgr.AddWingExp(uin, slotIndex, expAmount)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家数据不存在", false
    end

    return wingManager:AddWingExp(slotIndex, expAmount)
end

---翅膀升星
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function WingMgr.UpgradeWingStar(uin, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家数据不存在"
    end

    return wingManager:UpgradeWingStar(slotIndex)
end

---翅膀学习技能
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function WingMgr.LearnWingSkill(uin, slotIndex, skillId)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家数据不存在"
    end

    return wingManager:LearnWingSkill(slotIndex, skillId)
end

---获取玩家所有翅膀信息
---@param uin number 玩家ID
---@return table|nil 翅膀列表，失败返回nil
---@return string|nil 错误信息
function WingMgr.GetPlayerWingList(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return nil, "玩家数据不存在"
    end

    return wingManager:GetPlayerWingList(), nil
end

---获取翅膀数量
---@param uin number 玩家ID
---@return number 翅膀数量
function WingMgr.GetWingCount(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return 0
    end

    return wingManager:GetWingCount()
end

---获取激活的翅膀
---@param uin number 玩家ID
---@return CompanionInstance|nil 激活的翅膀实例
---@return number|nil 槽位索引
function WingMgr.GetActiveWing(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return nil, nil
    end

    return wingManager:GetActiveWing()
end

---获取指定槽位的翅膀实例
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return CompanionInstance|nil 翅膀实例
function WingMgr.GetWingInstance(uin, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return nil
    end

    return wingManager:GetWingBySlot(slotIndex)
end

---添加翅膀到指定槽位
---@param uin number 玩家ID
---@param wingName string 翅膀配置名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function WingMgr.AddWingToSlot(uin, wingName, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家数据不存在", nil
    end

    return wingManager:AddWing(wingName, slotIndex)
end

---移除指定槽位的翅膀
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function WingMgr.RemoveWingFromSlot(uin, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家数据不存在"
    end

    return wingManager:RemoveWing(slotIndex)
end

---获取翅膀的最终属性
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function WingMgr.GetWingFinalAttribute(uin, slotIndex, attrName)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return nil
    end

    return wingManager:GetWingFinalAttribute(slotIndex, attrName)
end

---检查翅膀是否可以升级
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function WingMgr.CanWingLevelUp(uin, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false
    end

    return wingManager:CanWingLevelUp(slotIndex)
end

---检查翅膀是否可以升星
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function WingMgr.CanWingUpgradeStar(uin, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家数据不存在"
    end

    return wingManager:CanWingUpgradeStar(slotIndex)
end

---给玩家添加翅膀
---@param player MPlayer 玩家对象
---@param wingName string 翅膀名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function WingMgr.AddWing(player, wingName, slotIndex)
    if not player or not player.uin then
        --gg.log("WingMgr.AddWing: 玩家对象无效")
        return false, nil
    end

    local success, errorMsg, actualSlot = WingMgr.AddWingToSlot(player.uin, wingName, slotIndex)
    if success then
        --gg.log("WingMgr.AddWing: 成功给玩家", player.uin, "添加翅膀", wingName, "槽位", actualSlot)
    else
        --gg.log("WingMgr.AddWing: 给玩家", player.uin, "添加翅膀失败", wingName, "错误", errorMsg)
    end

    return success, actualSlot
end

---给玩家添加翅膀（通过UIN）
---@param uin number 玩家UIN
---@param wingName string 翅膀名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function WingMgr.AddWingByUin(uin, wingName, slotIndex)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    if not player then
        --gg.log("WingMgr.AddWingByUin: 玩家不存在", uin)
        return false, nil
    end

    return WingMgr.AddWing(player, wingName, slotIndex)
end

---强制同步玩家翅膀数据到客户端
---@param uin number 玩家UIN
function WingMgr.ForceSyncToClient(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if wingManager then
        local wingListData = wingManager:GetPlayerWingList()
        local WingEventManager = require(ServerStorage.MSystems.Pet.EventManager.WingEventManager) ---@type WingEventManager
        WingEventManager.NotifyWingListUpdate(uin, wingListData)
    else
        --gg.log("警告: 玩家", uin, "的翅膀数据不存在，跳过翅膀数据同步")
    end
end

---强制保存玩家翅膀数据
---@param uin number 玩家UIN
function WingMgr.ForceSavePlayerData(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if wingManager then
        local playerWingData = wingManager:GetSaveData()
        if playerWingData then
            CloudWingDataAccessor:SavePlayerWingData(uin, playerWingData)
            --gg.log("WingMgr.ForceSavePlayerData: 强制保存翅膀数据", uin)
        end
    end
end

---批量升级所有可升级翅膀
---@param uin number 玩家ID
---@return number 升级的翅膀数量
function WingMgr.UpgradeAllPossibleWings(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return 0
    end

    local upgradedCount = wingManager:UpgradeAllPossibleWings()

    return upgradedCount
end

---获取指定类型的翅膀数量
---@param uin number 玩家ID
---@param wingName string 翅膀名称
---@param minStar number|nil 最小星级要求
---@return number 翅膀数量
function WingMgr.GetWingCountByType(uin, wingName, minStar)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return 0
    end

    return wingManager:GetWingCountByType(wingName, minStar)
end

--- 检查玩家是否有可用的翅膀槽位
---@param uin number 玩家ID
---@return boolean 是否有可用槽位
function WingMgr.HasAvailableSlot(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false
    end
    
    -- 检查是否有空槽位
    local wingCount = wingManager:GetWingCount()
    local maxSlots = wingManager.maxSlots  -- 默认最大槽位数
    
    return wingCount < maxSlots
end

---【新增】更新玩家所有已装备翅膀的模型
---@param player MPlayer 玩家对象
function WingMgr.UpdateAllEquippedWingModels(player)
    if not player or not player.uin then
        --gg.log("WingMgr.UpdateAllEquippedWingModels: 玩家对象无效")
        return
    end

    local uin = player.uin
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        --gg.log("WingMgr.UpdateAllEquippedWingModels: 找不到玩家翅膀数据", uin)
        return
    end

    local player_actor = player.actor
    if not player_actor then
        --gg.log("WingMgr.UpdateAllEquippedWingModels: 找不到玩家Actor", uin)
        return
    end

    local activeSlots = wingManager.activeCompanionSlots or {}
    -- 从翅膀管理器实例中获取所有可能的装备栏位ID
    local allEquipSlotIds = wingManager.equipSlotIds or {}
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)

    -- 1. 先隐藏所有翅膀节点，以处理离线时卸下装备的情况
    for _, equipSlotId in ipairs(allEquipSlotIds) do
        local wingNode = player_actor:FindFirstChild(equipSlotId)
        if wingNode then
            wingNode.Visible = false
        end
    end

    -- 2. 再根据当前激活的槽位，显示并更新正确的模型
    for equipSlotId, companionSlotId in pairs(activeSlots) do
        if companionSlotId and companionSlotId > 0 then
            local wingNode = player_actor:FindFirstChild(equipSlotId)
            if wingNode then
                local companionInstance = wingManager:GetWingBySlot(companionSlotId)
                if companionInstance then
                    local wingConfigName = companionInstance:GetConfigName()
                    local wingConfig = ConfigLoader.GetWing(wingConfigName)
                    if wingConfig and wingConfig.modelResource and wingConfig.modelResource ~= "" then
                        wingNode.ModelId = wingConfig.modelResource
                        wingNode.Visible = true

                        -- 【新增】更新动画控制器
                        local animatorNode = wingNode:FindFirstChild("Animator")
                        if animatorNode then
                            animatorNode.ControllerAsset = wingConfig.animationResource
                            --gg.log("更新翅膀动画控制器成功:", uin, equipSlotId, wingConfig.animationResource)
                        end

                        --gg.log("更新翅膀模型成功:", uin, equipSlotId, wingConfig.modelResource)
                    else
                        --gg.log("翅膀模型资源无效, 隐藏节点:", uin, equipSlotId)
                        wingNode.Visible = false
                    end
                else
                     --gg.log("找不到翅膀实例, 隐藏节点:", uin, companionSlotId)
                     wingNode.Visible = false
                end
            else
                --gg.log("找不到翅膀节点:", uin, equipSlotId)
            end
        end
    end
    --gg.log("玩家所有翅膀模型更新完毕", uin)
end

---【新增】装备翅膀接口
---@param uin number 玩家ID
---@param companionSlotId number 要装备的翅膀背包槽位ID
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function WingMgr.EquipWing(uin, companionSlotId, equipSlotId)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家翅膀数据不存在"
    end

    local success, errorMsg = wingManager:EquipWing(companionSlotId, equipSlotId)

    if success then
        --gg.log("翅膀装备数据更新成功, 开始更新模型", uin, companionSlotId, "->", equipSlotId)
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin) ---@type MPlayer
        if player then
            -- 【重构】调用通用函数来刷新所有翅膀模型
            WingMgr.UpdateAllEquippedWingModels(player)
        end
    end

    return success, errorMsg
end

---【新增】卸下翅膀接口
---@param uin number 玩家ID
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function WingMgr.UnequipWing(uin, equipSlotId)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家翅膀数据不存在"
    end

    local success, errorMsg = wingManager:UnequipWing(equipSlotId)

    if success then
        --gg.log("翅膀卸下数据更新成功, 开始更新模型", uin, equipSlotId)
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin) ---@type MPlayer
        if player then
            -- 【重构】调用通用函数来刷新所有翅膀模型
            WingMgr.UpdateAllEquippedWingModels(player)
        end
    end

    return success, errorMsg
end

--- 获取当前激活翅膀的物品加成
---@param uin number 玩家ID
---@return table<string, number> 激活翅膀的物品加成
function WingMgr.GetActiveItemBonuses(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return {}
    end

    local bonuses = wingManager:GetActiveItemBonuses()
    return bonuses
end

---【新增】设置玩家可携带栏位数量
---@param uin number 玩家ID
---@param count number 数量
---@return boolean
function WingMgr.SetUnlockedEquipSlots(uin, count)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if wingManager then
        wingManager:SetUnlockedEquipSlots(count)
        --gg.log("通过 WingMgr 更新玩家", uin, "的可携带栏位数量为", count)
        return true
    else
        --gg.log("更新可携带栏位失败，找不到玩家", uin, "的翅膀管理器")
        return false
    end
end

---【新增】设置玩家翅膀背包容量
---@param uin number 玩家ID
---@param capacity number 容量
---@return boolean
function WingMgr.SetWingBagCapacity(uin, capacity)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if wingManager then
        wingManager:SetWingBagCapacity(capacity)
        --gg.log("通过 WingMgr 更新玩家", uin, "的背包容量为", capacity)
        return true
    else
        --gg.log("更新背包容量失败，找不到玩家", uin, "的翅膀管理器")
        return false
    end
end

---【新增】清空玩家所有翅膀数据
---@param uin number 玩家ID
---@return boolean 是否成功
function WingMgr.ClearPlayerWingData(uin)
    gg.log("开始清空玩家翅膀数据:", uin)
    
    -- 清理内存中的翅膀管理器
    local wingManager = WingMgr.server_player_wings[uin]
    if wingManager then
        -- 先清理玩家身上的翅膀模型
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player and player.actor then
            local allEquipSlotIds = wingManager.equipSlotIds or {}
            for _, equipSlotId in ipairs(allEquipSlotIds) do
                local wingNode = player.actor:FindFirstChild(equipSlotId)
                if wingNode then
                    wingNode.Visible = false
                    wingNode.ModelId = ""
                end
            end
        end
        
        -- 清理内存缓存
        WingMgr.server_player_wings[uin] = nil
    end
    
    -- 清空云端数据
    local CloudWingDataAccessor = require(ServerStorage.MSystems.Pet.CloudData.WingCloudDataMgr)
    local success = CloudWingDataAccessor:ClearPlayerWingData(uin)
    
    if success then
        gg.log("成功清空玩家翅膀数据:", uin)
    else
        gg.log("清空玩家翅膀数据失败:", uin)
    end
    
    return success
end

-- =================================
-- 自动装备最优翅膀相关方法
-- =================================

---【新增】删除翅膀
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean, string|nil
function WingMgr.DeleteWing(uin, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家翅膀数据不存在"
    end
    
    local success, errorMsg = wingManager:DeleteWing(slotIndex)
    
    if success then
        --gg.log("删除翅膀成功", uin, "槽位", slotIndex)
        -- 可以在这里触发客户端通知
    end
    
    return success, errorMsg
end

---【新增】切换翅膀锁定状态
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean, string|nil, boolean|nil
function WingMgr.ToggleWingLock(uin, slotIndex)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家翅膀数据不存在", nil
    end
    
    local success, errorMsg, newLockStatus = wingManager:ToggleWingLock(slotIndex)
    
    if success then
        --gg.log("切换翅膀锁定状态成功", uin, "槽位", slotIndex, "新状态", newLockStatus)
    end
    
    return success, errorMsg, newLockStatus
end

---【新增】自动装备效果数值最高的翅膀
---@param uin number 玩家ID
---@param equipSlotId string 装备栏ID
---@param excludeEquipped boolean|nil 是否排除已装备的翅膀
---@return boolean, string|nil, number|nil
function WingMgr.AutoEquipBestEffectWing(uin, equipSlotId, excludeEquipped)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false, "玩家翅膀数据不存在", nil
    end
    
    local success, errorMsg, slotIndex = wingManager:AutoEquipBestWing(equipSlotId, excludeEquipped)
    
    if success then
        -- 更新模型显示和通知客户端
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            WingMgr.UpdateAllEquippedWingModels(player)
        end
        --gg.log("自动装备最优翅膀成功", uin, "装备栏", equipSlotId, "翅膀槽位", slotIndex)
    end
    
    return success, errorMsg, slotIndex
end

---【新增】自动装备所有装备栏的最优翅膀
---@param uin number 玩家ID
---@param excludeEquipped boolean|nil 是否排除已装备的翅膀
---@return table 装备结果
function WingMgr.AutoEquipAllBestEffectWings(uin, excludeEquipped)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return { error = "玩家翅膀数据不存在" }
    end
    
    local results = wingManager:AutoEquipAllBestWings(excludeEquipped)
    
    -- 更新模型显示
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    if player then
        WingMgr.UpdateAllEquippedWingModels(player)
    end
    
    --gg.log("自动装备所有最优翅膀完成", uin, results)
    return results
end

---【新增】获取翅膀效果数值排行
---@param uin number 玩家ID
---@param limit number|nil 返回数量限制
---@return table 排行列表
function WingMgr.GetWingEffectRanking(uin, limit)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return {}
    end
    
    return wingManager:GetWingEffectRanking(limit)
end

---【新增】检查玩家是否装备了翅膀
---@param uin number 玩家ID
---@return boolean 是否装备了翅膀
function WingMgr.HasEquippedWings(uin)
    local wingManager = WingMgr.GetPlayerWing(uin)
    if not wingManager then
        return false
    end
    
    -- 检查是否有激活的装备槽位
    local activeSlots = wingManager.activeCompanionSlots or {}
    for equipSlotId, companionSlotId in pairs(activeSlots) do
        if companionSlotId and companionSlotId > 0 then
            -- 检查该槽位是否真的有翅膀实例
            local companionInstance = wingManager:GetWingBySlot(companionSlotId)
            if companionInstance then
                return true -- 找到至少一个装备的翅膀
            end
        end
    end
    
    return false
end

return WingMgr 