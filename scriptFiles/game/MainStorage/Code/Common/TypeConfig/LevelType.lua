-- /scriptFiles/game/MainStorage/Code/Common/TypeConfig/LevelType.lua
-- 负责将 LevelConfig.lua 中的原始关卡数据，封装成程序中使用的Level对象。

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)

---@class LevelType : Class
---@field id string 关卡的唯一ID (来自配置的Key)
---@field levelName string 关卡名称
---@field defaultGameMode string 默认玩法模式 (例如 "RaceGameMode")
---@field rules table 玩法的具体规则 (例如 "准备时间", "比赛时长"等)
local LevelType = ClassMgr.Class("LevelType")

function LevelType:OnInit(data)
    self.id = data["ID"] or ""
    self.levelName = data["关卡名称"] or ""
    self.defaultGameMode = data["默认玩法"] or ""
    self.rules = {}

    -- 将所有其他字段都作为 "规则" 存储起来，方便扩展
    for key, value in pairs(data) do
        if key ~= "ID" and key ~= "关卡名称" and key ~= "默认玩法" then
            self.rules[key] = value
        end
    end
end

--- 获取此关卡的所有规则
---@return table
function LevelType:GetRules()
    return self.rules
end

return LevelType 