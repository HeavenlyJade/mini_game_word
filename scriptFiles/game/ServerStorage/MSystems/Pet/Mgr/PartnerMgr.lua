-- PartnerMgr.lua
-- 伙伴系统管理模块
-- 负责管理所有在线玩家的伙伴管理器，提供系统级接口

local game = game
local os = os
local table = table
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local RunService = game:GetService('RunService')
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local CloudPartnerDataAccessor = require(ServerStorage.MSystems.Pet.CloudData.PartnerCloudDataMgr) ---@type CloudPetDataAccessor
local Partner = require(ServerStorage.MSystems.Pet.Compainion.Partner) ---@type Partner
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class PartnerMgr
local PartnerMgr = {
    -- 在线玩家伙伴管理器缓存 {uin = Partner管理器实例}
    server_player_partners = {}, ---@type table<number, Partner>

    -- 定时保存间隔（秒）
    SAVE_INTERVAL = 60
}

-- 移除定时存盘功能，现在使用统一的定时存盘机制
-- function SaveAllPlayerPARTNER_()
--     local count = 0
--     for uin, partnerManager in pairs(PartnerMgr.server_player_partners) do
--         if partnerManager then
--             -- 提取数据并保存到云端
--             local playerPartnerData = partnerManager:GetSaveData()
--             if playerPartnerData then
--                 CloudPartnerDataAccessor:SavePlayerPartnerData(uin, playerPartnerData)
--             end
--         end
--     end
--     -- --gg.log("定时保存伙伴数据完成，保存了", count, "个玩家的伙伴")
-- end

-- local saveTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
-- saveTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
-- saveTimer.Name = 'PARTNER_SAVE_ALL'
-- saveTimer.Delay = 60
-- saveTimer.Loop = true
-- saveTimer.Interval = 60
-- saveTimer.Callback = SaveAllPlayerPARTNER_
-- saveTimer:Start()

---保存指定玩家的伙伴数据（供统一存盘机制调用）
---@param uin number 玩家ID
function PartnerMgr.SavePlayerPartnerData(uin)
    local partnerManager = PartnerMgr.server_player_partners[uin]
    if partnerManager then
        local playerPartnerData = partnerManager:GetSaveData()
        if playerPartnerData then
            CloudPartnerDataAccessor:SavePlayerPartnerData(uin, playerPartnerData)
            --gg.log("统一存盘：已保存玩家", uin, "的伙伴数据")
        end
    end
end


---玩家上线处理
---@param player MPlayer 玩家对象
function PartnerMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        --gg.log("伙伴系统：玩家上线处理失败：玩家对象无效")
        return
    end

    local uin = player.uin
    --gg.log("开始处理玩家伙伴上线", uin)

    -- 从云端加载玩家伙伴数据
    local playerPartnerData = CloudPartnerDataAccessor:LoadPlayerPartnerData(uin)

    -- 创建Partner管理器实例并缓存
    local partnerManager = Partner.New(uin, playerPartnerData)
    PartnerMgr.server_player_partners[uin] = partnerManager

    --gg.log("玩家伙伴管理器加载完成", uin, "伙伴数量数据",playerPartnerData)
end

---玩家离线处理
---@param uin number 玩家ID
function PartnerMgr.OnPlayerLeave(uin)
    local partnerManager = PartnerMgr.server_player_partners[uin]
    if partnerManager then
        -- 提取数据并保存到云端
        local playerPartnerData = partnerManager:GetSaveData()
        if playerPartnerData then
            CloudPartnerDataAccessor:SavePlayerPartnerData(uin, playerPartnerData)
        end

        -- 清理内存缓存
        PartnerMgr.server_player_partners[uin] = nil
        --gg.log("玩家伙伴数据已保存并清理", uin)
    end
end

---获取玩家伙伴管理器
---@param uin number 玩家ID
---@return Partner|nil 伙伴管理器实例
function PartnerMgr.GetPlayerPartner(uin)
    local partnerManager = PartnerMgr.server_player_partners[uin]
    if not partnerManager then
        --gg.log("伙伴系统：在缓存中未找到玩家", uin, "的伙伴管理器，尝试动态加载。")
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            PartnerMgr.OnPlayerJoin(player)
            partnerManager = PartnerMgr.server_player_partners[uin]
        end

        if partnerManager then
            --gg.log("伙伴系统：为玩家", uin, "动态加载伙伴管理器成功。")
        else
            --gg.log("伙伴系统：为玩家", uin, "动态加载伙伴管理器失败。")
        end
    end
    return partnerManager
end

---设置激活伙伴
---@param uin number 玩家ID
---@param slotIndex number 槽位索引（0表示取消激活）
---@return boolean 是否成功
---@return string|nil 错误信息
function PartnerMgr.SetActivePartner(uin, slotIndex)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家数据不存在"
    end

    local success, errorMsg = partnerManager:SetActivePartner(slotIndex)

    if success then
        --gg.log("伙伴激活状态设置成功", uin, slotIndex)
        -- 在这里添加更新模型的逻辑
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin) ---@type MPlayer
        if not player or not player.actor then
            --gg.log("错误：找不到玩家Actor，无法更新伙伴模型", uin)
            return success, errorMsg
        end

        local partnerNode = player.actor:FindFirstChild("Partner1")
        if not partnerNode then
            --gg.log("警告：在玩家Actor下未找到名为'Partner1'的节点", uin)
            return success, errorMsg
        end

        if slotIndex > 0 then
            -- 装备伙伴
            local activePartner = partnerManager:GetActivePartner()
            if activePartner then
                local partnerConfigName = activePartner:GetConfigName()
                if not partnerConfigName then
                    --gg.log("错误：无法获取伙伴配置名称，隐藏节点", uin)
                    partnerNode.Visible = false
                    return success, errorMsg
                end

                local partnerConfig = ConfigLoader.GetPartner(partnerConfigName) ---@type PetType
                if partnerConfig and partnerConfig.modelResource and partnerConfig.modelResource ~= "" then
                    partnerNode.ModelId = partnerConfig.modelResource
                    partnerNode.Visible = true
                    --gg.log("成功更新玩家伙伴模型并显示节点", uin, partnerConfig.modelResource)
                else
                    --gg.log("警告：伙伴没有配置模型资源或配置不存在，隐藏节点", uin, partnerConfigName)
                    partnerNode.Visible = false
                end
            else
                -- 安全起见，如果找不到激活的伙伴实例，也隐藏节点
                partnerNode.Visible = false
            end
        else
            -- 卸下伙伴
            partnerNode.Visible = false
            --gg.log("成功卸下伙伴并隐藏节点", uin)
        end
    end

    return success, errorMsg
end

---伙伴升级
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param targetLevel number|nil 目标等级，nil表示升1级
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否真的升级了
function PartnerMgr.LevelUpPartner(uin, slotIndex, targetLevel)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家数据不存在", false
    end

    return partnerManager:LevelUpPartner(slotIndex, targetLevel)
end

---伙伴获得经验
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param expAmount number 经验值
---@return boolean 是否成功
---@return string|nil 错误信息
---@return boolean|nil 是否升级了
function PartnerMgr.AddPartnerExp(uin, slotIndex, expAmount)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家数据不存在", false
    end

    return partnerManager:AddPartnerExp(slotIndex, expAmount)
end

---伙伴升星
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function PartnerMgr.UpgradePartnerStar(uin, slotIndex)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家数据不存在"
    end

    return partnerManager:UpgradePartnerStar(slotIndex)
end

---伙伴学习技能
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param skillId string 技能ID
---@return boolean 是否成功
---@return string|nil 错误信息
function PartnerMgr.LearnPartnerSkill(uin, slotIndex, skillId)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家数据不存在"
    end

    return partnerManager:LearnPartnerSkill(slotIndex, skillId)
end

---获取玩家所有伙伴信息
---@param uin number 玩家ID
---@return table|nil 伙伴列表，失败返回nil
---@return string|nil 错误信息
function PartnerMgr.GetPlayerPartnerList(uin)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return nil, "玩家数据不存在"
    end

    return partnerManager:GetPlayerPartnerList(), nil
end

---获取伙伴数量
---@param uin number 玩家ID
---@return number 伙伴数量
function PartnerMgr.GetPartnerCount(uin)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return 0
    end

    return partnerManager:GetPartnerCount()
end

---获取激活的伙伴
---@param uin number 玩家ID
---@return CompanionInstance|nil 激活的伙伴实例
---@return number|nil 槽位索引
function PartnerMgr.GetActivePartner(uin)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return nil, nil
    end

    return partnerManager:GetActivePartner()
end

---获取指定槽位的伙伴实例
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return CompanionInstance|nil 伙伴实例
function PartnerMgr.GetPartnerInstance(uin, slotIndex)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return nil
    end

    return partnerManager:GetPartnerBySlot(slotIndex)
end

---添加伙伴到指定槽位
---@param uin number 玩家ID
---@param partnerName string 伙伴配置名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function PartnerMgr.AddPartnerToSlot(uin, partnerName, slotIndex)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家数据不存在", nil
    end

    return partnerManager:AddPartner(partnerName, slotIndex)
end

---移除指定槽位的伙伴
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function PartnerMgr.RemovePartnerFromSlot(uin, slotIndex)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家数据不存在"
    end

    return partnerManager:RemovePartner(slotIndex)
end

---获取伙伴的最终属性
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param attrName string 属性名称
---@return number|nil 属性值
function PartnerMgr.GetPartnerFinalAttribute(uin, slotIndex, attrName)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return nil
    end

    return partnerManager:GetPartnerFinalAttribute(slotIndex, attrName)
end

---检查伙伴是否可以升级
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否可以升级
function PartnerMgr.CanPartnerLevelUp(uin, slotIndex)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false
    end

    return partnerManager:CanPartnerLevelUp(slotIndex)
end

---检查伙伴是否可以升星
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否可以升星
---@return string|nil 错误信息
function PartnerMgr.CanPartnerUpgradeStar(uin, slotIndex)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家数据不存在"
    end

    return partnerManager:CanPartnerUpgradeStar(slotIndex)
end

---给玩家添加伙伴
---@param player MPlayer 玩家对象
---@param partnerName string 伙伴名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function PartnerMgr.AddPartner(player, partnerName, slotIndex)
    if not player or not player.uin then
        --gg.log("PartnerMgr.AddPartner: 玩家对象无效")
        return false, nil
    end

    local success, errorMsg, actualSlot = PartnerMgr.AddPartnerToSlot(player.uin, partnerName, slotIndex)
    if success then
        --gg.log("PartnerMgr.AddPartner: 成功给玩家", player.uin, "添加伙伴", partnerName, "槽位", actualSlot)
    else
        --gg.log("PartnerMgr.AddPartner: 给玩家", player.uin, "添加伙伴失败", partnerName, "错误", errorMsg)
    end

    return success, actualSlot
end

---给玩家添加伙伴（通过UIN）
---@param uin number 玩家UIN
---@param partnerName string 伙伴名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function PartnerMgr.AddPartnerByUin(uin, partnerName, slotIndex)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    if not player then
        --gg.log("PartnerMgr.AddPartnerByUin: 玩家不存在", uin)
        return false, nil
    end

    return PartnerMgr.AddPartner(player, partnerName, slotIndex)
end

---强制同步玩家伙伴数据到客户端
---@param uin number 玩家UIN
function PartnerMgr.ForceSyncToClient(uin)
    local result, errorMsg = PartnerMgr.GetPlayerPartnerList(uin)
    if result then
        -- TODO: 需要 PartnerEventManager
        -- local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager
        -- PartnerEventManager.NotifyPartnerListUpdate(uin, result.partnerList)
        --gg.log("PartnerMgr.ForceSyncToClient: 强制同步伙伴数据", uin)
    else
        --gg.log("PartnerMgr.ForceSyncToClient: 同步失败", uin, errorMsg)
    end
end

---强制保存玩家伙伴数据
---@param uin number 玩家UIN
function PartnerMgr.ForceSavePlayerData(uin)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if partnerManager then
        local playerPartnerData = partnerManager:GetSaveData()
        if playerPartnerData then
            CloudPartnerDataAccessor:SavePlayerPartnerData(uin, playerPartnerData)
            --gg.log("PartnerMgr.ForceSavePlayerData: 强制保存伙伴数据", uin)
        end
    end
end

---批量升级所有可升级伙伴
---@param uin number 玩家ID
---@return number 升级的伙伴数量
function PartnerMgr.UpgradeAllPossiblePartners(uin)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return 0
    end

    local upgradedCount = partnerManager:UpgradeAllPossiblePartners()

    return upgradedCount
end

---获取指定类型的伙伴数量
---@param uin number 玩家ID
---@param partnerName string 伙伴名称
---@param minStar number|nil 最小星级要求
---@return number 伙伴数量
function PartnerMgr.GetPartnerCountByType(uin, partnerName, minStar)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return 0
    end

    return partnerManager:GetPartnerCountByType(partnerName, minStar)
end

---【新增】更新玩家所有已装备伙伴的模型
---@param player MPlayer 玩家对象
function PartnerMgr.UpdateAllEquippedPartnerModels(player)
    if not player or not player.uin then
        --gg.log("PartnerMgr.UpdateAllEquippedPartnerModels: 玩家对象无效")
        return
    end

    local uin = player.uin
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        --gg.log("PartnerMgr.UpdateAllEquippedPartnerModels: 找不到玩家伙伴数据", uin)
        return
    end

    local player_actor = player.actor
    if not player_actor then
        --gg.log("PartnerMgr.UpdateAllEquippedPartnerModels: 找不到玩家Actor", uin)
        return
    end

    local activeSlots = partnerManager.activeCompanionSlots or {}
    -- 从伙伴管理器实例中获取所有可能的装备栏位ID
    local allEquipSlotIds = partnerManager.equipSlotIds or {}
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)

    -- 1. 先隐藏所有伙伴节点，以处理离线时卸下装备的情况
    for _, equipSlotId in ipairs(allEquipSlotIds) do
        local partnerNode = player_actor:FindFirstChild(equipSlotId)
        if partnerNode then
            partnerNode.Visible = false
        end
    end

    -- 2. 再根据当前激活的槽位，显示并更新正确的模型
    for equipSlotId, companionSlotId in pairs(activeSlots) do
        if companionSlotId and companionSlotId > 0 then
            local partnerNode = player_actor:FindFirstChild(equipSlotId)
            if partnerNode then
                local companionInstance = partnerManager:GetPartnerBySlot(companionSlotId)
                if companionInstance then
                    local partnerConfigName = companionInstance:GetConfigName()
                    local partnerConfig = ConfigLoader.GetPartner(partnerConfigName)
                    if partnerConfig and partnerConfig.modelResource and partnerConfig.modelResource ~= "" then
                        partnerNode.ModelId = partnerConfig.modelResource
                        partnerNode.Visible = true
                        
                        -- 【新增】确保同步设置正确
                        partnerNode.IgnoreStreamSync = false
                        partnerNode.SyncMode = Enum.NodeSyncMode.NORMAL

                        -- 【新增】更新动画控制器
                        local animatorNode = partnerNode:FindFirstChild("Animator")
                        if animatorNode then
                            animatorNode.ControllerAsset = partnerConfig.animationResource
                            --gg.log("更新伙伴动画控制器成功:", uin, equipSlotId, partnerConfig.animationResource)
                        end

                        --gg.log("更新伙伴模型成功:", uin, equipSlotId, partnerConfig.modelResource)
                    else
                        --gg.log("伙伴模型资源无效, 隐藏节点:", uin, equipSlotId)
                        partnerNode.Visible = false
                    end
                else
                     --gg.log("找不到伙伴实例, 隐藏节点:", uin, companionSlotId)
                     partnerNode.Visible = false
                end
            else
                --gg.log("找不到伙伴节点:", uin, equipSlotId)
            end
        end
    end
    --gg.log("玩家所有伙伴模型更新完毕", uin)
end


---【新增】装备伙伴接口
---@param uin number 玩家ID
---@param companionSlotId number 要装备的伙伴背包槽位ID
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function PartnerMgr.EquipPartner(uin, companionSlotId, equipSlotId)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家伙伴数据不存在"
    end

    local success, errorMsg = partnerManager:EquipPartner(companionSlotId, equipSlotId)

    if success then
        --gg.log("伙伴装备数据更新成功, 开始更新模型", uin, companionSlotId, "->", equipSlotId)
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin) ---@type MPlayer
        if player then
            -- 【重构】调用通用函数来刷新所有伙伴模型
            PartnerMgr.UpdateAllEquippedPartnerModels(player)
        end
    end

    return success, errorMsg
end

---【新增】卸下伙伴接口
---@param uin number 玩家ID
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function PartnerMgr.UnequipPartner(uin, equipSlotId)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return false, "玩家伙伴数据不存在"
    end

    local success, errorMsg = partnerManager:UnequipPartner(equipSlotId)

    if success then
        --gg.log("伙伴卸下数据更新成功, 开始更新模型", uin, equipSlotId)
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin) ---@type MPlayer
        if player then
            -- 【重构】调用通用函数来刷新所有伙伴模型
            PartnerMgr.UpdateAllEquippedPartnerModels(player)
        end
    end

    return success, errorMsg
end

--- 获取当前激活伙伴的物品加成
---@param uin number 玩家ID
---@return table<string, number> 激活伙伴的物品加成
function PartnerMgr.GetActiveItemBonuses(uin)
    local partnerManager = PartnerMgr.GetPlayerPartner(uin)
    if not partnerManager then
        return {}
    end

    local bonuses = partnerManager:GetActiveItemBonuses()
    return bonuses
end


return PartnerMgr
