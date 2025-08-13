-- OpenUICommand.lua
-- UI界面打开指令处理器
-- 负责处理场景节点触发的UI打开请求

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

---@class OpenUICommand
local OpenUICommand = {}

-- 子指令处理器
OpenUICommand.handlers = {}

--- 打开界面处理器
---@param params table 指令参数
---@param player MPlayer 目标玩家
---@return boolean 是否成功
function OpenUICommand.handlers.open(params, player)
    local uiName = params["界面名"]
    local lotteryType = params["抽奖类型"]
    
    if not uiName then
        player:SendHoverText("缺少'界面名'字段")
        return false
    end
    
    -- 根据不同界面类型处理
    if uiName == "LotteryGui" then
        if not lotteryType then
            player:SendHoverText("抽奖界面需要'抽奖类型'字段")
            return false
        end
        
        -- 发送打开抽奖界面事件到客户端
   
        gg.network_channel:fireClient(player.uin, {
            cmd = "OpenLotteryUI",
            operation = "打开界面",
            lotteryType = lotteryType
        })
        
        --gg.log("向玩家", player.name, "发送打开抽奖界面事件，类型:", lotteryType)
        return true
        
    elseif uiName == "WaypointGui" then
        -- 发送打开传送界面事件到客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "OpenWaypointGui",
            uiName = uiName,
            operation = "打开界面",
            params = params,
        })
        --gg.log("向玩家", player.name, "发送打开传送界面事件:", uiName)
        return true

    else
        -- 
        gg.network_channel:fireClient(player.uin, {
            cmd = "OpenUI",
            uiName = uiName,
            params= params,
        })
       
        
        --gg.log("向玩家", player.name, "发送打开界面事件:", uiName)
        return true
    end
end

--- 关闭界面处理器
---@param params table 指令参数
---@param player MPlayer 目标玩家
---@return boolean 是否成功
function OpenUICommand.handlers.close(params, player)
    local uiName = params["界面名"]
    if not uiName then
        player:SendHoverText("缺少'界面名'字段")
        return false
    end

    if uiName == "WaypointGui" then
        gg.network_channel:fireClient(player.uin, {
            cmd = "OpenWaypointGui",
            uiName = uiName,
            operation = "关闭界面",
            params = params,
        })
        --gg.log("向玩家", player.name, "发送关闭传送界面事件:", uiName)
        return true
    elseif uiName == "LotteryGui" then
        gg.network_channel:fireClient(player.uin, {
            cmd = "OpenLotteryUI",
            operation = "关闭界面",
        })
        --gg.log("向玩家", player.name, "发送关闭抽奖界面事件:", uiName)
        return true
    else
        gg.network_channel:fireClient(player.uin, {
            cmd = "CloseUI",
            uiName = uiName,
            params = params,
        })
        --gg.log("向玩家", player.name, "发送关闭界面事件:", uiName)
        return true
    end
end

-- 中文到英文的操作映射
local operationMap = {
    ["打开界面"] = "open",
    ["关闭界面"] = "close",
}

--- UI指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function OpenUICommand.main(params, player)
    local operationType = params["操作类型"]
    
    if not operationType then
        player:SendHoverText("缺少'操作类型'字段。有效类型: '打开界面'")
        return false
    end
    
    -- 将中文指令映射到英文处理器
    local handlerName = operationMap[operationType]
    if not handlerName then
        player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '打开界面'")
        return false
    end
    
    local handler = OpenUICommand.handlers[handlerName]
    if handler then
        --gg.log("UI指令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return OpenUICommand

--[[
使用示例:

1. 打开翅膀抽奖界面:
openui {"操作类型": "打开界面", "界面名": "LotteryGui", "抽奖类型": "翅膀"}

2. 打开宠物抽奖界面:
openui {"操作类型": "打开界面", "界面名": "LotteryGui", "抽奖类型": "宠物"}

3. 打开伙伴抽奖界面:
openui {"操作类型": "打开界面", "界面名": "LotteryGui", "抽奖类型": "伙伴"}

4. 打开其他通用界面:
openui {"操作类型": "打开界面", "界面名": "ShopDetailGui"}
--]]