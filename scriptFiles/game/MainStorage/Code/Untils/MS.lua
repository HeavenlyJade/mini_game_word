---@class MS
MS = {}

-- 官方游戏服务 API
MS.RunService = game:GetService("RunService")
MS.Players = game:GetService("Players")
MS.TweenService = game:GetService("TweenService")
MS.WorkSpace = game:GetService("WorkSpace")
MS.Environment = MS.WorkSpace.Environment
MS.MainStorage = game:GetService("MainStorage")
MS.ServerStorage = game:GetService("ServerStorage")
MS.ContextActionService = game:GetService("ContextActionService")
MS.UserInputService = game:GetService("UserInputService")
MS.WorldService = game:GetService("WorldService")
MS.DeveloperStoreService = game:GetService("DeveloperStoreService") -- 迷你币商品服务
MS.CoreUI = game:GetService("CoreUI") -- 游戏核心界面信息
MS.PhysXService = game:GetService("PhysXService")
MS.FriendInviteService = game:GetService("FriendInviteService") -- 好友拉新
MS.StarterGui = game:GetService("StarterGui")
MS.TeleportService = game:GetService("TeleportService") -- 传送服务
MS.AnalyticsService = game:GetService("AnalyticsService") -- 数据埋点服务
MS.UtilService = game:GetService("UtilService")
MS.MouseService = game:GetService("MouseService") -- 鼠标服务
MS.CloudServerConfigService = game:GetService("CloudServerConfigService")
MS.SceneMgr = game:GetService("SceneMgr") -- 副本服务
MS.CustomConfigService = game:GetService("CustomConfigService")
MS.NetworkChannel = game:GetService("NetworkChannel")
-- 尝试获取 NetworkChannel 服务

print("游戏服务初始化完成")

-- 核心工具类
MS.ClassMgr = require(MS.MainStorage.Code.Untils.ClassMgr)
MS.MGlobal = require(MS.MainStorage.Code.Untils.MGlobal)
MS.Json = require(MS.MainStorage.Code.Untils.json)
MS.TimeUtils = require(MS.MainStorage.Code.Untils.TimeUntils)

print("核心工具类加载完成")

-- 数学工具类
MS.MathDefines = require(MS.MainStorage.Code.Untils.Math.MathDefines)
MS.Vec2 = require(MS.MainStorage.Code.Untils.Math.Vec2)
MS.Vec3 = require(MS.MainStorage.Code.Untils.Math.Vec3)
MS.Vec4 = require(MS.MainStorage.Code.Untils.Math.Vec4)
MS.Matrix3x3 = require(MS.MainStorage.Code.Untils.Math.Matrix3x3)
MS.Matrix3x4 = require(MS.MainStorage.Code.Untils.Math.Matrix3x4)
MS.Matrix4x4 = require(MS.MainStorage.Code.Untils.Math.Matrix4x4)
MS.Quat = require(MS.MainStorage.Code.Untils.Math.Quat)
MS.PerlinNoise = require(MS.MainStorage.Code.Untils.Math.PerlinNoise)

print("数学工具类加载完成")

-- 通用配置和常量
MS.MConst = require(MS.MainStorage.Code.Common.GameConfig.Mconst)
MS.MConfig = require(MS.MainStorage.Code.Common.GameConfig.MConfig)
MS.ItemType = require(MS.MainStorage.Code.Common.TypeConfig.ItemType)
MS.ItemTypeConfig = require(MS.MainStorage.Code.Common.Config.ItemTypeConfig)
MS.WeightedRandomSelector = require(MS.MainStorage.Code.Common.WeightedRandomSelector)

print("配置系统加载完成")

-- 事件系统
MS.EventBag = require(MS.MainStorage.Code.Event.event_bag)
MS.EventSkill = require(MS.MainStorage.Code.Event.event_sklii)
MS.EventMail = require(MS.MainStorage.Code.Event.EventMail)

print("事件系统加载完成")



return MS