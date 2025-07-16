local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local gg = require(MainStorage.Code.Untils.MGlobal)

---@class RewardBase : Class
---@field calcType string 计算器类型名称
local RewardBase = ClassMgr.Class("RewardBase")

--- 初始化奖励计算器
---@param calcType string 计算器类型（如"飞车挑战赛"）
function RewardBase:OnInit(calcType)
    self.calcType = calcType or "未知计算器"
end

--- 计算基础奖励（子类必须重写）
---@param playerData table 玩家数据 {rank, distance, ...}
---@param levelInstance LevelType 关卡实例，包含所有配置
---@return table<string, number>|nil 基础奖励 {物品名称: 数量}
function RewardBase:CalcBaseReward(playerData, levelInstance)
    gg.log(string.format("警告: 计算器 %s 未实现 CalcBaseReward 方法", self.calcType))
    return nil
end

--- 计算排名奖励（子类必须重写）
---@param playerData table 玩家数据
---@param levelInstance LevelType 关卡实例，包含所有配置
---@return table[]|nil 排名奖励列表 {{物品: string, 数量: number}}
function RewardBase:CalcRankReward(playerData, levelInstance)
    gg.log(string.format("警告: 计算器 %s 未实现 CalcRankReward 方法", self.calcType))
    return nil
end

--- 验证关卡实例有效性
---@param levelInstance LevelType 关卡实例
---@return boolean
function RewardBase:ValidateLevel(levelInstance)
    if not levelInstance or not levelInstance:Is("LevelType") then
        gg.log(string.format("错误: %s - 无效的关卡实例(LevelType)", self.calcType))
        return false
    end
    return true
end

--- 验证玩家数据有效性
---@param playerData table 玩家数据
---@return boolean 数据是否有效
function RewardBase:ValidatePlayerData(playerData)
    if not playerData then
        gg.log(string.format("错误: %s - 玩家数据为空", self.calcType))
        return false
    end
    
    if not playerData.rank or playerData.rank <= 0 then
        gg.log(string.format("错误: %s - 玩家排名无效: %s", self.calcType, tostring(playerData.rank)))
        return false
    end
    
    if not playerData.uin then
        gg.log(string.format("错误: %s - 玩家UIN无效", self.calcType))
        return false
    end
    
    return true
end

--- 获取支持的计算变量列表（子类可重写）
---@return string[] 支持的变量名列表
function RewardBase:GetSupportedVars()
    return {"rank", "distance", "playerName", "uin"}
end

return RewardBase