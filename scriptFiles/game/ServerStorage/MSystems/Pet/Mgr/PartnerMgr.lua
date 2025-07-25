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

---@class PartnerMgr
local PartnerMgr = {
    -- 在线玩家伙伴管理器缓存 {uin = Partner管理器实例}
    server_player_partners = {}, ---@type table<number, Partner>
    
    -- 定时保存间隔（秒）
    SAVE_INTERVAL = 60
}

function SaveAllPlayerPARTNER_()
    local count = 0
    for uin, partnerManager in pairs(PartnerMgr.server_player_partners) do
        if partnerManager then
            -- 提取数据并保存到云端
            local playerPartnerData = partnerManager:GetSaveData()
            if playerPartnerData then
                CloudPartnerDataAccessor:SavePlayerPartnerData(uin, playerPartnerData)
            end
        end
    end
    -- gg.log("定时保存伙伴数据完成，保存了", count, "个玩家的伙伴")
end

local saveTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
saveTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
saveTimer.Name = 'PARTNER_SAVE_ALL'
saveTimer.Delay = 60
saveTimer.Loop = true
saveTimer.Interval = 60
saveTimer.Callback = SaveAllPlayerPARTNER_  
saveTimer:Start()


---玩家上线处理
---@param player MPlayer 玩家对象
function PartnerMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        gg.log("伙伴系统：玩家上线处理失败：玩家对象无效")
        return
    end
    
    local uin = player.uin
    gg.log("开始处理玩家伙伴上线", uin)
    
    -- 从云端加载玩家伙伴数据
    local playerPartnerData = CloudPartnerDataAccessor:LoadPlayerPartnerData(uin)
    
    -- 创建Partner管理器实例并缓存
    local partnerManager = Partner.New(uin, playerPartnerData)
    PartnerMgr.server_player_partners[uin] = partnerManager
    
    gg.log("玩家伙伴管理器加载完成", uin, "伙伴数量", partnerManager:GetPartnerCount())
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
        gg.log("玩家伙伴数据已保存并清理", uin)
    end
end

---获取玩家伙伴管理器
---@param uin number 玩家ID
---@return Partner|nil 伙伴管理器实例
function PartnerMgr.GetPlayerPartner(uin)
    local partnerManager = PartnerMgr.server_player_partners[uin]
    if not partnerManager then
        gg.log("伙伴系统：在缓存中未找到玩家", uin, "的伙伴管理器，尝试动态加载。")
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            PartnerMgr.OnPlayerJoin(player)
            partnerManager = PartnerMgr.server_player_partners[uin]
        end

        if partnerManager then
            gg.log("伙伴系统：为玩家", uin, "动态加载伙伴管理器成功。")
        else
            gg.log("伙伴系统：为玩家", uin, "动态加载伙伴管理器失败。")
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
    
    return partnerManager:SetActivePartner(slotIndex)
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
        gg.log("PartnerMgr.AddPartner: 玩家对象无效")
        return false, nil
    end
    
    local success, errorMsg, actualSlot = PartnerMgr.AddPartnerToSlot(player.uin, partnerName, slotIndex)
    if success then
        gg.log("PartnerMgr.AddPartner: 成功给玩家", player.uin, "添加伙伴", partnerName, "槽位", actualSlot)
        -- 通知客户端更新
        PartnerMgr.NotifyPartnerDataUpdate(player.uin, actualSlot)
    else
        gg.log("PartnerMgr.AddPartner: 给玩家", player.uin, "添加伙伴失败", partnerName, "错误", errorMsg)
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
        gg.log("PartnerMgr.AddPartnerByUin: 玩家不存在", uin)
        return false, nil
    end
    
    return PartnerMgr.AddPartner(player, partnerName, slotIndex)
end

---通知客户端伙伴数据更新
---@param uin number 玩家ID
---@param slotIndex number|nil 具体槽位，nil表示全部更新
function PartnerMgr.NotifyPartnerDataUpdate(uin, slotIndex)
    -- TODO: 需要 PartnerEventManager
    -- local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager
    
    if slotIndex then
        -- 单个伙伴更新
        local partnerManager = PartnerMgr.GetPlayerPartner(uin)
        if partnerManager then
            local partnerInstance = partnerManager:GetPartnerBySlot(slotIndex)
            if partnerInstance then
                -- PartnerEventManager.NotifyPartnerUpdate(uin, partnerInstance:GetFullInfo())
                gg.log("通知客户端伙伴更新(stub)", uin, slotIndex)
            end
        end
    else
        -- 全部伙伴更新
        local result, errorMsg = PartnerMgr.GetPlayerPartnerList(uin)
        if result then
            -- PartnerEventManager.NotifyPartnerListUpdate(uin, result.partnerList)
            gg.log("通知客户端伙伴列表更新(stub)", uin)
        end
    end
end

---强制同步玩家伙伴数据到客户端
---@param uin number 玩家UIN
function PartnerMgr.ForceSyncToClient(uin)
    local result, errorMsg = PartnerMgr.GetPlayerPartnerList(uin)
    if result then
        -- TODO: 需要 PartnerEventManager
        -- local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager
        -- PartnerEventManager.NotifyPartnerListUpdate(uin, result.partnerList)
        gg.log("PartnerMgr.ForceSyncToClient: 强制同步伙伴数据", uin)
    else
        gg.log("PartnerMgr.ForceSyncToClient: 同步失败", uin, errorMsg)
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
            gg.log("PartnerMgr.ForceSavePlayerData: 强制保存伙伴数据", uin)
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
    if upgradedCount > 0 then
        -- 通知客户端更新
        PartnerMgr.NotifyPartnerDataUpdate(uin)
    end
    
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




return PartnerMgr