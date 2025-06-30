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

-- 实体系统
MS.Entity = require(MS.MainStorage.Code.MServer.EntityTypes.Entity)
MS.MPlayer = require(MS.MainStorage.Code.MServer.EntityTypes.MPlayer)
MS.MMonster = require(MS.MainStorage.Code.MServer.EntityTypes.MMonster)
MS.MNpc = require(MS.MainStorage.Code.MServer.EntityTypes.MNpc)

print("实体系统加载完成")

-- 服务器系统管理
if MS.RunService:IsServer() then
    MS.SystemManager = require(MS.MainStorage.Code.MServer.Systems.SystemManager)
    MS.BattleSystem = require(MS.MainStorage.Code.MServer.Systems.BattleSystem)
    MS.BuffSystem = require(MS.MainStorage.Code.MServer.Systems.BuffSystem)
    MS.CooldownSystem = require(MS.MainStorage.Code.MServer.Systems.CooldownSystem)
    MS.StatSystem = require(MS.MainStorage.Code.MServer.Systems.StatSystem)
    MS.TagSystem = require(MS.MainStorage.Code.MServer.Systems.TagSystem)
    MS.VariableSystem = require(MS.MainStorage.Code.MServer.Systems.VariableSystem)
    
    print("服务器系统加载完成")
    
    -- 事件管理器
    MS.ServerEventManager = require(MS.MainStorage.Code.MServer.Event.ServerEventManager)
    MS.ServerScheduler = require(MS.MainStorage.Code.MServer.Scheduler.ServerScheduler)
    
    -- 背包系统
    MS.BagMgr = require(MS.ServerStorage.MSystems.Bag.BagMgr)
    MS.Bag = require(MS.ServerStorage.MSystems.Bag.Bag)
    MS.Item = require(MS.ServerStorage.MSystems.Bag.Item)
    MS.ItemUtils = require(MS.ServerStorage.MSystems.Bag.ItemUtils)
    MS.BagEventManager = require(MS.ServerStorage.MSystems.Bag.BagEventManager)
    
    -- 邮件系统
    MS.MailMgr = require(MS.ServerStorage.MSystems.Mail.MailMgr)
    MS.Mail = require(MS.ServerStorage.MSystems.Mail.Mail)
    MS.MailManager = require(MS.ServerStorage.MSystems.Mail.MailManager)
    MS.GlobalMailManager = require(MS.ServerStorage.MSystems.Mail.GlobalMailManager)
    MS.MailEventManager = require(MS.ServerStorage.MSystems.Mail.MailEventManager)
    MS.CloudMailData = require(MS.ServerStorage.MSystems.Mail.cloudMailData)
    
    -- 服务器数据管理
    MS.MServerDataManager = require(MS.ServerStorage.MServerDataManager)
    MS.MCloudDataMgr = require(MS.ServerStorage.MCloudDataMgr)
    MS.MServerInitPlayer = require(MS.ServerStorage.MServerInitPlayer)
    
    print("服务器数据系统加载完成")
end

-- 客户端系统
if MS.RunService:IsClient() then
    MS.ClientEventManager = require(MS.MainStorage.Code.Client.Event.ClientEventManager)
    MS.ClientMain = require(MS.MainStorage.Code.Client.ClientMain)
    MS.CameraController = require(MS.MainStorage.Code.Client.Camera.CameraController)
    MS.MController = require(MS.MainStorage.Code.Client.MController)
    
    -- UI系统
    MS.ViewBase = require(MS.MainStorage.Code.Client.UI.ViewBase)
    MS.ViewButton = require(MS.MainStorage.Code.Client.UI.ViewButton)
    MS.ViewComponent = require(MS.MainStorage.Code.Client.UI.ViewComponent)
    MS.ViewItem = require(MS.MainStorage.Code.Client.UI.ViewItem)
    MS.ViewList = require(MS.MainStorage.Code.Client.UI.ViewList)
    
    print("客户端系统加载完成")
end

-- 场景系统
MS.Scene = require(MS.MainStorage.Code.Scene.Scene)
MS.Level = require(MS.MainStorage.Code.Scene.Level)
print("场景系统加载完成")
-- 事件系统
MS.EventBag = require(MS.MainStorage.Code.Event.event_bag)
MS.EventSkill = require(MS.MainStorage.Code.Event.event_sklii)
MS.EventMail = require(MS.MainStorage.Code.Event.EventMail)

print("事件系统加载完成")



return MS