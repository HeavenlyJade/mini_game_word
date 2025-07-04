local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

local MailCommand = require(ServerStorage.CommandSys.Commands.MmailCom) ---@type MailCommand
-- local SkillCommands = require(ServerStorage.CommandSys.Commands.MskillCom)     ---@type SkillCommands
local json = require(MainStorage.Code.Untils.json) ---@type json
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager


---@class CommandManager
local CommandManager = {}

-- 所有指令处理器 (使用多级嵌套结构)
CommandManager.handlers = {
    -- 物品相关
       -- 邮件相关命令
    ["mail"] = MailCommand.main,
    -- 装载默认的配置技能
    -- ["skillConf"] = SkillCommands.main,



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
    local params = json.decode(jsonStr)
    if params["在线"] == "不在线" then
        --- 用来处理玩家不在线的情况
        --- 获取玩家

    elseif params["玩家"] then
        player = gg.getLivingByName(params["玩家"])
        if not player then
            gg.log("玩家不存在: " .. params["玩家"])
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
