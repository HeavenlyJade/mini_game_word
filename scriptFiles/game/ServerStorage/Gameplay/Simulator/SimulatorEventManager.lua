local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

---@class SimulatorEventManager
local SimulatorEventManager = ClassMgr.Class("SimulatorEventManager")

---@param simulatorMgrs table<string, SimulatorGrowthMgr> PlayerUID -> Mgr
function SimulatorEventManager:OnInit(simulatorMgrs)
    self.simulatorMgrs = simulatorMgrs

    self:RegisterServerEvents()
end

function SimulatorEventManager:RegisterServerEvents()
    -- 示例: 监听一个来自客户端的事件，请求执行某个动作来获得经验
    ServerEventManager.Subscribe("Simulator_PlayerRequestAction", function(player, actionData)
        local playerUID = player.UserId
        local growthMgr = self.simulatorMgrs[playerUID]

        if growthMgr then
            -- 假设 actionData 包含要增加的经验值
            local expToAdd = actionData.exp or 10
            growthMgr:AddExperience(expToAdd)
        end
    end)
end

return SimulatorEventManager