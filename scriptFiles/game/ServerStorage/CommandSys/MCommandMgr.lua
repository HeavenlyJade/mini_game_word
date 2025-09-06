local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg
local serverDataMgr     = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

local MailCommand = require(ServerStorage.CommandSys.Commands.MmailCom) ---@type MailCommand
local BagCommand = require(ServerStorage.CommandSys.Commands.MbagCom) ---@type BagCommand
local PetCommand = require(ServerStorage.CommandSys.Commands.MPetCom) ---@type PetCommand
local PartnerCommand = require(ServerStorage.CommandSys.Commands.MPartnerCom) ---@type PartnerCommand
local WingCommand = require(ServerStorage.CommandSys.Commands.MWingCom) ---@type WingCommand
local VariableCommand = require(ServerStorage.CommandSys.Commands.MVariableCom) ---@type VariableCommand
local StatCommand = require(ServerStorage.CommandSys.Commands.MStatCom) ---@type StatCommand
local ClearDataCommand = require(ServerStorage.CommandSys.Commands.MClearDataCom) ---@type ClearDataCommand
-- local SkillCommands = require(ServerStorage.CommandSys.Commands.MskillCom)     ---@type SkillCommands
local json = require(MainStorage.Code.Untils.json) ---@type json
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local TrailCommand = require(ServerStorage.CommandSys.Commands.MTrailCom) ---@type TrailCommand
local RewardCommand = require(ServerStorage.CommandSys.Commands.RewardCommand) ---@type RewardCommand
local OpenUICommand = require(ServerStorage.CommandSys.Commands.OpenUICommand) ---@type OpenUICommand
local AnimationCommand = require(ServerStorage.CommandSys.Commands.MAnimationCom) ---@type AnimationCommand
local ActorNodeCommand = require(ServerStorage.CommandSys.Commands.MActorNodeCom) ---@type ActorNodeCommand
local ShopCommand = require(ServerStorage.CommandSys.Commands.MShopCom) ---@type ShopCommand
local AchievementCommand = require(ServerStorage.CommandSys.Commands.MAchievementCom) ---@type AchievementCommand
local CloudDataCommand = require(ServerStorage.CommandSys.Commands.MCloudDataCom) ---@type CloudDataCommand
local RankingCommand = require(ServerStorage.CommandSys.Commands.MRankingCom) ---@type RankingCommand


---@class CommandManager
local CommandManager = {}

-- 所有指令处理器 (使用多级嵌套结构)
CommandManager.handlers = {
    -- 物品相关
    ["PlayerItem"] = BagCommand.main,
       -- 邮件相关命令
    ["mail"] = MailCommand.main,
    -- 宠物相关命令
    ["pet"] = PetCommand.main,
    -- 伙伴相关命令
    ["partner"] = PartnerCommand.main,
    -- 翅膀相关命令
    ["wing"] = WingCommand.main,
    -- 装载默认的配置技能
    -- ["skillConf"] = SkillCommands.main,
    ["variable"] = VariableCommand.main,
    ["attribute"] = StatCommand.main,
    ["clearPlayerData"] = ClearDataCommand.main,
    ["trail"] = TrailCommand.main,
    ["reward"] = RewardCommand.main,
	["openui"] = OpenUICommand.main,
    ["animation"] = AnimationCommand.main,
    ["actornode"] = ActorNodeCommand.main,
    ["shop"] = ShopCommand.main,
    ["achievement"] = AchievementCommand.main,
    ["clouddata"] = CloudDataCommand.main,
    ["ranking"] = RankingCommand.main,




}

ServerEventManager.Subscribe("ClientExecuteCommand", function(evt)
    if not gg.opUin[evt.player.uin] then
        evt.player:SendChatText("你没有执行指令的权限")
        return
    end
    CommandManager.ExecuteCommand(evt.command, evt.player)
end)

function CommandManager.ExecuteCommand(commandStr, player, silent)
    if not commandStr or commandStr == "" then return false end

    -- 1. 清理命令字符串前后的空白字符
    commandStr = commandStr:match("^%s*(.-)%s*$")

    -- 2. 分割命令和参数
    local command, jsonStr = commandStr:match("^(%S+)%s+(.+)$")
    if not command then
        gg.log("命令格式错误: " .. commandStr)
        return false
    end

    -- 3. 查找命令处理器
    local handler = CommandManager.handlers[command]
    if not handler then
        gg.log("未知命令: " .. command)
        return false
    end

    -- 4. 解析JSON参数
    local success, params = pcall(json.decode, jsonStr)
    if not success then
        gg.log("JSON解析错误: " .. tostring(params) .. ", 原始字符串: " .. jsonStr)
        return false
    end
    if params["在线"] == "不在线" then
        --- 用来处理玩家不在线的情况
        --- 获取玩家

    elseif params["玩家"] then
        player = serverDataMgr.getLivingByName(params["玩家"])
        if not player then
            gg.log("玩家不存在: " .. params["玩家"])
            return false
        end
    elseif params["玩家UID"] then
        local targetUin = tonumber(params["玩家UID"])
        if not targetUin then
            gg.log("玩家UID格式错误: " .. params["玩家UID"])
            return false
        end
        player = serverDataMgr.getPlayerByUin(targetUin)
        if not player then
            gg.log("玩家不存在: " .. targetUin)
            return false
        end
    end
    if not silent then
        gg.log("执行指令", player, command, params)
    end
    -- 6. 调用处理器
    local success, result = pcall(handler, params, player)
    if not success then
        gg.log("命令执行错误: " .. command .. ", " .. tostring(result))
        return false
    end

    return result
end



return CommandManager
