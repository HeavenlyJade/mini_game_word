
--------------------------------------------------

--- Description：客户端代码入口
--- 客户端启动的时候，会自动加载此代码并执行，再加载其他代码模块 (v109)
--------------------------------------------------

print("客户端开始初始化")

local MainClient = require(game:GetService("MainStorage"):WaitForChild('Code').Client.ClientMain).New()
MainClient.start_client()

print("客户端代码启动完毕")