
--------------------------------------------------

--- Description：服务器代码入口
--- 服务器启动的时候，会自动加载此代码并执行，再加载其他代码模块 (v109)
--------------------------------------------------

print("服务端初始化")

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local Code = MainStorage:WaitForChild('Code')
local Untils = Code:WaitForChild('Untils')
Untils:WaitForChild('ClassMgr')

local MainServer = require(ServerStorage.MServerMain) ---@type MainServer
MainServer.start_server()
print("服务器加载完成")
