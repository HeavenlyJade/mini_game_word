
--------------------------------------------------

--- Description：服务器代码入口
--- 服务器启动的时候，会自动加载此代码并执行，再加载其他代码模块 (v109)
--------------------------------------------------



local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local Code = MainStorage:WaitForChild('Code')

local MainServer = require(ServerStorage.Manager.MServerMain) ---@type MainServer
MainServer.start_server()

