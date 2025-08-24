-- SceneNodeType.lua
-- 该文件定义了场景节点的数据结构类，用于包装从 SceneNodeConfig.lua 加载的数据。

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ActionCosteRewardCal = require(MainStorage.Code.GameReward.RewardCalc.ActionCosteRewardCal) ---@type ActionCosteRewardCal


---@class SceneNodeType : Class
---@field name string 名字
---@field uuid string 唯一ID
---@field nodePath string 场景节点路径
---@field sceneType string 场景类型
---@field belongScene string 所属场景
---@field areaConfig table 区域节点配置
---@field respawnNodeName string 复活节点
---@field teleportNodeName string 传送节点
---@field triggerBoxNodeName string 包围盒节点
---@field raceScenePath string 比赛场景
---@field requirementDescNode string 需求描述节点
---@field effectDescNode string 作用描述节点
---@field countdownDisplayNode string 倒计时显示节点
---@field linkedLevel string 关联关卡
---@field gameplayRules table 玩法规则
---@field soundAsset string 音效资源
---@field requirementDesc string 需求描述
---@field effectDesc string 作用描述
---@field enterConditions EnterCondition[] 进入条件列表
---@field enterCommand string 进入指令
---@field leaveCommand string 离开指令
---@field timedCommands table 定时指令列表
---@field New fun(data:table):SceneNodeType

---@class EnterCondition
---@field 条件公式 string 条件公式，如 "$数据_固定值_历史最大战力值$ >= 1500"
local SceneNodeType = ClassMgr.Class("SceneNodeType")

-- 从原始配置数据初始化场景节点类型对象
function SceneNodeType:OnInit(data)
    self.name = data["名字"] or ""
    self.uuid = data["唯一ID"] or ""
    self.nodePath = data["场景节点路径"] or ""
    self.sceneType = data["场景类型"] or ""
    self.belongScene = data["所属场景"] or ""
    self.areaConfig = data["区域节点配置"] or {}
    
    -- 为方便访问，同时将areaConfig中的嵌套属性赋给主对象
    self.respawnNodeName = self.areaConfig["复活节点"] or ""
    self.teleportNodeName = self.areaConfig["传送节点"] or ""
    self.triggerBoxNodeName = self.areaConfig["包围盒节点"] or ""
    self.raceScenePath = self.areaConfig["比赛场景"] or ""
    self.requirementDescNode = self.areaConfig["需求描述节点"] or ""
    self.effectDescNode = self.areaConfig["作用描述节点"] or ""
    self.countdownDisplayNode = self.areaConfig["倒计时显示节点"] or ""
    
    self.linkedLevel = data["关联关卡"] or ""
    self.gameplayRules = data["玩法规则"] or {}
    self.soundAsset = data["音效资源"] or ""
    self.requirementDesc = data["需求描述"] or ""
    self.effectDesc = data["作用描述"] or ""
    -- 新增：数值化的效率配置，直接用于效率比较
    self.effectValueConfig = data["作数值的配置"] or 0
    self.enterConditions = data["进入条件列表"] or {}
    self.enterCommand = data["进入指令"] or ""
    self.leaveCommand = data["离开指令"] or ""
    self.timedCommands = data["定时指令列表"] or {}
end



-- 检查场景节点配置是否为飞行比赛类型
---@return boolean 是否为飞行比赛类型
function SceneNodeType:IsRaceGame()
    return self.sceneType == "飞行比赛"
end

--- 检查变量表达公式是否满足条件
---@param playerData table 玩家数据
---@param bagData table|nil 背包数据（可选）
---@param externalContext table|nil 外部上下文（可选）
---@return boolean, string
function SceneNodeType:CheckVariableCondition(playerData, bagData, externalContext)
    if not self.enterConditions or #self.enterConditions == 0 then
        return true, '无变量条件限制'
    end
    
    -- 检查所有进入条件，任何一个不满足就返回false
    for _, condition in ipairs(self.enterConditions) do
        local conditionFormula = condition["条件公式"]
        if conditionFormula and conditionFormula ~= "" then
            -- 使用ActionCosteRewardCal的条件检查逻辑
            local result = ActionCosteRewardCal:_CalculateValue(conditionFormula, playerData, bagData, externalContext)
            if result == false then
                return false, '变量条件不满足: ' .. conditionFormula
            end
        end
    end
    
    return true, '变量条件满足'
end

return SceneNodeType 