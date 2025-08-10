
--------------------------------------------------

--- Description：客户端代码入口
--- 客户端启动的时候，会自动加载此代码并执行，再加载其他代码模块 (v109)
--------------------------------------------------

local MainClient = require(game:GetService("MainStorage"):WaitForChild('Code').Client.ClientMain).New()
MainClient.start_client()

-- 导入并初始化赛道系统
local RaceTrack = require(game:GetService("MainStorage"):WaitForChild('Code').Client.SceneNode.RaceTrack) ---@type RaceTrack
RaceTrack.InitializeRaceTrack()

