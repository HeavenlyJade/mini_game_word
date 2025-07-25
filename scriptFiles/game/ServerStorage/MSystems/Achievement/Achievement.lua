-- Achievement.lua
-- 玩家成就聚合类 - 管理单个玩家的所有成就和天赋数据

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local ClassMgr    = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local AchievementRewardCal = require(MainStorage.Code.GameReward.RewardCalc.AchievementRewardCal) ---@type AchievementRewardCal
local VariableSystem = require(MainStorage.Code.MServer.Systems.VariableSystem) ---@type VariableSystem

---@class Achievement 
---@field playerId number 玩家ID
---@field talentData table<string, TalentInfo> 天赋数据映射
---@field normalAchievements table<string, AchievementInfo> 普通成就数据
---@field talentVariableSystem VariableSystem 天赋变量系统
---@field lastUpdateTime number 最后更新时间
local Achievement = ClassMgr.Class("Achievement")

---@class TalentInfo
---@field currentLevel number 当前等级
---@field unlockTime number 解锁时间戳

---@class AchievementInfo
---@field unlocked boolean 是否已解锁
---@field unlockTime number 解锁时间戳

--- 初始化玩家成就聚合实例
---@param playerId number 玩家ID
---@param achievementData AchievementDataTable|nil 玩家成就数据
function Achievement:OnInit(playerId, achievementData)
    gg.log("开始初始化Achievement实例", playerId)

    self.playerId = playerId
    self.talentData = {} -- 天赋数据映射
    self.normalAchievements = {} -- 普通成就数据
    self.lastUpdateTime = os.time()
    
    -- 如果有成就数据，先恢复到内部数据结构
    if achievementData then
        self:_RestoreFromAchievementData(achievementData)
    end
    
    -- 将天赋数据转换为VariableSystem格式（同时处理玩家变量）
    
    -- 创建天赋变量系统，只存储系统变量
    self.talentVariableSystem = VariableSystem.New("天赋", self.talentVariableData)
    
    -- 初始化奖励计算器
    self._rewardCalculator = AchievementRewardCal.New()
    self.talentVariableData = self:_ConvertTalentDataToVariableFormat()

    -- gg.log("初始化玩家成就聚合实例", playerId,achievementData,self._rewardCalculator)

end

--- 从成就数据恢复到内部数据结构
---@param achievementData AchievementDataTable 成就数据
---@private
function Achievement:_RestoreFromAchievementData(achievementData)
    for achievementId, data in pairs(achievementData) do
        local achievementType = ConfigLoader.GetAchievement(achievementId)
        if achievementType then
            if achievementType:IsTalentAchievement() then
                -- 恢复天赋数据
                self.talentData[achievementId] = {
                    currentLevel = data.currentLevel or 1,
                    unlockTime = data.unlockTime or os.time()
                }
            else
                -- 恢复普通成就数据
                self.normalAchievements[achievementId] = {
                    unlocked = true,
                    unlockTime = data.unlockTime or os.time()
                }
            end
        end
    end
end

--- 将天赋数据转换为VariableSystem变量格式
---@return table<string, table> VariableSystem格式的变量数据
---@private
function Achievement:_ConvertTalentDataToVariableFormat()
    local talentVariableData = {}    -- 天赋系统的变量数据
    local playerVariableData = {}    -- 玩家系统的变量数据
    
    -- 遍历所有天赋数据
    for talentId, talentInfo in pairs(self.talentData) do
        local talentConfig = ConfigLoader.GetAchievement(talentId)
        if talentConfig and talentConfig:IsTalentAchievement() then
            -- 获取当前等级的效果配置
            local effectConfig = talentConfig:GetLevelEffect(talentInfo.currentLevel)
            if effectConfig then
                local effectType = effectConfig["效果类型"]        -- "玩家变量" 或 "系统变量"
                local fieldName = effectConfig["效果字段名称"]      -- 如 "加成_百分比_双倍训练"
                
                if fieldName then
                    -- 计算效果值
                    local effectValue = self._rewardCalculator:CalculateEffectValue(
                        effectConfig["效果数值"],
                        talentInfo.currentLevel,
                        talentConfig
                    )
                    
                    if effectValue then
                        -- 生成来源标识
                        local source = string.format("天赋_%s_L%d", talentId, talentInfo.currentLevel)
                        
                        -- 判断数值类型
                        local valueType = "固定值"
                        if string.find(fieldName, "^加成_") then
                            valueType = "百分比"
                        end
                        
                        -- 根据效果类型选择目标数据表
                        local targetData = nil
                        if effectType == "玩家变量" then
                            targetData = playerVariableData
                        else
                            -- 其他类型（系统变量等）存储在天赋变量系统中
                            targetData = talentVariableData
                        end
                        
                        -- 确保变量存在
                        if not targetData[fieldName] then
                            targetData[fieldName] = {
                                base = 0,
                                sources = {}
                            }
                        end
                        
                        -- 添加来源值
                        targetData[fieldName].sources[source] = {
                            value = effectValue,
                            type = valueType
                        }
                    end
                end
            end
        end
    end
    
    -- 将玩家变量数据应用到玩家的变量系统
    self:_ApplyToPlayerVariableSystem(playerVariableData)
    
    -- 返回天赋系统的变量数据
    return talentVariableData
end

--- 将玩家变量数据应用到玩家的变量系统
---@param playerVariableData table 玩家变量数据
---@private
function Achievement:_ApplyToPlayerVariableSystem(playerVariableData)
    -- 获取玩家实例
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager)
    local player = MServerDataManager.getPlayerInfoByUin(tonumber(self.playerId))
    
    if not player or not player.variableSystem then
        gg.log("玩家或玩家变量系统不存在:", self.playerId)
        return
    end
    
    -- 应用每个变量
    for fieldName, variableData in pairs(playerVariableData) do
        for source, sourceData in pairs(variableData.sources) do
            player.variableSystem:SetSourceValue(fieldName, source, sourceData.value, sourceData.type)
        end
    end
    
    gg.log(string.format("玩家[%s]应用了%d个天赋变量到玩家系统", 
        self.playerId, self:_CountVariables(playerVariableData)))
end

--- 统计变量数量
---@param variableData table
---@return number
function Achievement:_CountVariables(variableData)
    local count = 0
    for _, v in pairs(variableData) do
        if v.sources then
            for _ in pairs(v.sources) do
                count = count + 1
            end
        end
    end
    return count
end

-- 天赋管理方法 --------------------------------------------------------

--- 获取天赋等级
---@param talentId string 天赋ID
---@return number 当前等级，未解锁返回0
function Achievement:GetTalentLevel(talentId)
    local talentInfo = self.talentData[talentId]
    return talentInfo and talentInfo.currentLevel or 0
end

--- 设置天赋等级（用于数据恢复）
---@param talentId string 天赋ID
---@param level number 等级
---@param unlockTime number|nil 解锁时间戳
function Achievement:SetTalentLevel(talentId, level, unlockTime)
    if not self.talentData[talentId] then
        self.talentData[talentId] = {}
    end
    
    self.talentData[talentId].currentLevel = level
    self.talentData[talentId].unlockTime = unlockTime or os.time()
    
    gg.log(string.format("玩家[%s]天赋[%s]设置为L%d", tostring(self.playerId), tostring(talentId), level))
end

--- 检查天赋是否可以升级
---@param talentId string 天赋ID
---@param player MPlayer 玩家实例
---@return boolean 是否可以升级
function Achievement:CanUpgradeTalent(talentId, player)
    local talentConfig = ConfigLoader.GetAchievement(talentId) ---@type AchievementType
    
    if not talentConfig or not talentConfig:IsTalentAchievement() then
        return false
    end
    
    local currentLevel = self:GetTalentLevel(talentId)
    
    -- 检查是否已达到最大等级
    if currentLevel >= talentConfig:GetMaxLevel() then
        return false
    end
    
    -- TODO: 检查升级条件（资源消耗等）
    return true
end

--- 升级天赋
---@param talentId string 天赋ID
---@param player MPlayer 玩家实例
---@return boolean 是否升级成功
function Achievement:UpgradeTalent(talentId, player)
    if not self:CanUpgradeTalent(talentId, player) then
        gg.log(string.format("玩家[%s]天赋[%s]升级条件不满足", self.playerId, talentId))
        return false
    end
    
    local oldLevel = self:GetTalentLevel(talentId)
    local newLevel = oldLevel + 1
    
    -- 如果是首次解锁
    if oldLevel == 0 then
        self.talentData[talentId] = {
            currentLevel = 1,
            unlockTime = os.time()
        }
        gg.log(string.format("玩家[%s]解锁天赋[%s]", self.playerId, talentId))
    else
        -- 升级现有天赋
        self.talentData[talentId].currentLevel = newLevel
    end
    
    -- 移除旧等级效果并应用新等级效果
    self:_RemoveTalentEffect(talentId, oldLevel, player)
    self:ApplyTalentEffect(talentId, player)
    
    gg.log(string.format("玩家[%s]天赋[%s]从L%d升级到L%d", 
        self.playerId, talentId, oldLevel, newLevel))
    
    return true
end

--- 重置指定天赋
---@param talentId string 天赋ID
---@param player MPlayer 玩家实例
function Achievement:ResetTalent(talentId, player)
    local oldLevel = self:GetTalentLevel(talentId)
    
    if oldLevel > 0 then
        -- 移除当前效果
        self:_RemoveTalentEffect(talentId, oldLevel, player)
        
        -- 重置到1级
        self.talentData[talentId].currentLevel = 1
        
        -- 应用1级效果
        self:ApplyTalentEffect(talentId, player)
        
        gg.log(string.format("玩家[%s]天赋[%s]从L%d重置到L1", 
            self.playerId, talentId, oldLevel))
    end
end

--- 重置所有天赋
---@param player MPlayer 玩家实例
function Achievement:ResetAllTalents(player)
    gg.log(string.format("开始重置玩家[%s]的所有天赋", self.playerId))
    
    -- 移除所有天赋效果
    if self.talentVariableSystem then
        self.talentVariableSystem:RemoveSourcesByPattern("天赋_")
    end
    
    -- 重置所有天赋等级到1级
    local resetCount = 0
    for talentId, talentInfo in pairs(self.talentData) do
        if talentInfo.currentLevel > 1 then
            talentInfo.currentLevel = 1
            resetCount = resetCount + 1
        end
    end
    
    -- 重新应用所有1级天赋效果
    self:ApplyAllTalentEffects(player)
    
    gg.log(string.format("玩家[%s]天赋系统重置完成，重置了%d个天赋", 
        self.playerId, resetCount))
end

-- 天赋效果应用 --------------------------------------------------------

--- 应用单个天赋效果
---@param talentId string 天赋ID
---@param player MPlayer 玩家实例
function Achievement:ApplyTalentEffect(talentId, player)
    local talentInfo = self.talentData[talentId]
    if not talentInfo or talentInfo.currentLevel <= 0 then
        return
    end
    
    local talentConfig = ConfigLoader.GetAchievement(talentId)
    
    if not talentConfig or not talentConfig:IsTalentAchievement() then
        gg.log("警告：天赋配置不存在或非天赋成就:", talentId)
        return
    end
    
    -- 获取当前等级的效果配置
    local effectConfig = talentConfig:GetLevelEffect(talentInfo.currentLevel)
    if not effectConfig then
        gg.log("警告：天赋等级效果配置不存在:", talentId, talentInfo.currentLevel)
        return
    end
    
    -- 计算效果数值
    local effectValue = self._rewardCalculator:CalculateEffectValue(
        effectConfig["效果数值"],
        talentInfo.currentLevel,
        talentConfig
    )
    
    if not effectValue then
        gg.log("警告：天赋效果数值计算失败:", talentId, effectConfig["效果数值"])
        return
    end
    
    -- 应用到天赋变量系统
    self:_ApplyToTalentVariableSystem(talentId, effectConfig, effectValue, player)
end

--- 应用所有天赋效果
---@param player MPlayer|nil 玩家实例
function Achievement:ApplyAllTalentEffects(player)
    local count = 0
    for talentId, _ in pairs(self.talentData) do
        self:ApplyTalentEffect(talentId, player)
        count = count + 1
    end
    
    gg.log("玩家[%s]应用了%d个天赋效果", self.playerId, count)
end

--- 应用效果到天赋变量系统
---@param talentId string 天赋ID
---@param effectConfig table 效果配置
---@param effectValue number 效果值
---@param player MPlayer 玩家实例
---@private
function Achievement:_ApplyToTalentVariableSystem(talentId, effectConfig, effectValue, player)
    if not self.talentVariableSystem then
        gg.log("天赋变量系统不存在:", self.playerId)
        return
    end
    
    local fieldName = effectConfig["效果字段名称"]
    if not fieldName then
        gg.log("效果字段名称未配置:", talentId)
        return
    end
    
    -- 生成天赋来源标识
    local currentLevel = self:GetTalentLevel(talentId)
    local source = string.format("天赋_%s_L%d", talentId, currentLevel)
    
    -- 判断数值类型
    local valueType = "固定值"
    if string.find(fieldName, "^加成_") then
        valueType = "百分比"
    end
    
    -- 应用到天赋变量系统
    self.talentVariableSystem:SetSourceValue(fieldName, source, effectValue, valueType)
    
    gg.log(string.format("天赋[%s-L%d]应用变量效果: %s = %s (%s, 来源:%s)", 
        talentId, currentLevel, fieldName, tostring(effectValue), valueType, source))
end

--- 移除天赋效果
---@param talentId string 天赋ID
---@param level number 要移除的等级
---@param player MPlayer 玩家实例
---@private
function Achievement:_RemoveTalentEffect(talentId, level, player)
    if not self.talentVariableSystem or level <= 0 then
        return
    end
    
    -- 移除指定等级的天赋效果
    local source = string.format("天赋_%s_L%d", talentId, level)
    self.talentVariableSystem:RemoveSourcesByPattern(source)
    
    gg.log(string.format("移除天赋[%s-L%d]的效果", talentId, level))
end

-- 普通成就管理 --------------------------------------------------------

--- 解锁普通成就
---@param achievementId string 成就ID
---@param unlockTime number|nil 解锁时间戳
function Achievement:UnlockNormalAchievement(achievementId, unlockTime)
    if self.normalAchievements[achievementId] then
        gg.log("成就已解锁:", achievementId)
        return false
    end
    
    self.normalAchievements[achievementId] = {
        unlocked = true,
        unlockTime = unlockTime or os.time()
    }
    
    gg.log(string.format("玩家[%s]解锁成就[%s]", self.playerId, achievementId))
    return true
end

--- 检查普通成就是否已解锁
---@param achievementId string 成就ID
---@return boolean 是否已解锁
function Achievement:IsNormalAchievementUnlocked(achievementId)
    local achievementInfo = self.normalAchievements[achievementId]
    return achievementInfo and achievementInfo.unlocked or false
end

-- 查询方法 --------------------------------------------------------

--- 获取所有天赋数据
---@return table<string, TalentInfo>
function Achievement:GetAllTalentData()
    return self.talentData
end

--- 获取所有普通成就数据
---@return table<string, AchievementInfo>
function Achievement:GetAllNormalAchievements()
    return self.normalAchievements
end

--- 获取天赋总数
---@return number
function Achievement:GetTalentCount()
    local count = 0
    for _ in pairs(self.talentData) do
        count = count + 1
    end
    return count
end

--- 获取已解锁的普通成就总数
---@return number
function Achievement:GetUnlockedNormalAchievementCount()
    local count = 0
    for _, achievementInfo in pairs(self.normalAchievements) do
        if achievementInfo.unlocked then
            count = count + 1
        end
    end
    return count
end

-- 数据持久化 --------------------------------------------------------

--- 获取保存数据格式
---@return table 保存数据
function Achievement:GetSaveData()
    local saveData = {}
    
    -- 保存天赋数据
    for talentId, talentInfo in pairs(self.talentData) do
        saveData[talentId] = {
            achievementId = talentId,
            playerId = self.playerId,
            unlockTime = talentInfo.unlockTime,
            currentLevel = talentInfo.currentLevel
        }
    end
    
    -- 保存普通成就数据
    for achievementId, achievementInfo in pairs(self.normalAchievements) do
        saveData[achievementId] = {
            achievementId = achievementId,
            playerId = self.playerId,
            unlockTime = achievementInfo.unlockTime,
            currentLevel = 1 -- 普通成就固定为1级
        }
    end
    
    return saveData
end

--- 从保存数据恢复（保持兼容性，但主要逻辑已移到OnInit）
---@param saveData AchievementDataTable 保存的数据
function Achievement:RestoreFromSaveData(saveData)
    self:_RestoreFromAchievementData(saveData)
    gg.log(string.format("玩家[%s]成就数据补充恢复完成", self.playerId))
end

-- 调试和工具方法 --------------------------------------------------------

--- 获取调试信息
---@return string 调试信息字符串
function Achievement:GetDebugInfo()
    local info = string.format("玩家[%s]成就数据:\n", self.playerId)
    info = info .. string.format("  天赋数量: %d\n", self:GetTalentCount())
    info = info .. string.format("  普通成就数量: %d\n", self:GetUnlockedNormalAchievementCount())
    info = info .. "  天赋详情:\n"
    
    for talentId, talentInfo in pairs(self.talentData) do
        info = info .. string.format("    %s: L%d (解锁时间:%s)\n", 
            talentId, talentInfo.currentLevel, os.date("%Y-%m-%d %H:%M:%S", talentInfo.unlockTime))
    end
    
    return info
end

return Achievement