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
MS.NetworkChannel = game:GetService("NetworkChannel") -- 网络通道服务

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
MS.MConst = require(MS.MainStorage.Code.Common.GameConfig.MConst)
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

-- 智能模块加载系统 - 使用路径字符串配置
-- 支持路径形式：如 "Common/Config/ItemTypeConfig"

-- 定义模块加载列表 - 使用路径/模块名的格式
local moduleLoadList = {
    -- MainStorage根目录下的直接模块
    -- "ObjectPool",                           -- 对象池管理器
    -- "SceneManager",                         -- 场景管理器  
    -- "WeatherManager",                       -- 天气管理器
    -- "EffectManager",                        -- 特效管理器
    -- "SoundManager",                         -- 音效管理器
    -- "TimerMgr",                            -- 定时器管理器
    -- "NetworkManager",                       -- 网络管理器
    -- "UIManager",                           -- UI管理器
    -- "ResourceManager",                      -- 资源管理器
    
    -- 通用配置模块 (MainStorage/Code/...)
    -- "Common/Config/ItemTypeConfig",         -- 物品类型配置（已在上面加载）
    -- "Common/Config/SkillConfig",            -- 技能配置
    -- "Common/Config/MapConfig",              -- 地图配置
    -- "Common/GameConfig/ModuleScript",       -- 模块脚本配置
    -- "Common/TypeConfig/SkillType",          -- 技能类型
    -- "Common/TypeConfig/EntityType",         -- 实体类型
    -- "Common/Icon/ui_icon",                  -- UI图标
    
    -- 事件系统模块
    -- "Event/EventBattle",                    -- 战斗事件
    -- "Event/EventPlayer",                    -- 玩家事件
    -- "Event/EventShop",                      -- 商店事件
    
    -- 工具类模块
    -- "Untils/CustomUtils",                   -- 自定义工具
    -- "Untils/DataUtils",                     -- 数据工具
    -- "Untils/StringUtils",                   -- 字符串工具
    
    -- 客户端模块（只在客户端加载）
    -- "Client/UI/CustomView",                 -- 自定义视图
    -- "Client/Camera/CameraEffect",           -- 相机特效
    -- "Client/Event/LocalClientEvents",       -- 本地客户端事件
    
    -- 服务器模块（只在服务器端加载）
    -- "MServer/EntityTypes/CustomEntity",     -- 自定义实体
    -- "MServer/Systems/CustomSystem",         -- 自定义系统
    -- "MServer/Event/LocalServerEvents",      -- 本地服务器事件
    
    -- 场景系统模块
    -- "Scene/CustomScene",                    -- 自定义场景
    -- "Scene/CustomLevel",                    -- 自定义关卡
}

-- 模块加载函数
local function loadModuleFromPath(pathString)
    local parts = {}
    -- 分割路径
    for part in pathString:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then return false end
    
    local moduleName = parts[#parts] -- 最后一部分是模块名
    local success, module
    
    if #parts == 1 then
        -- 根目录模块 (MainStorage直接子级)
        success, module = pcall(function()
            return require(MS.MainStorage:WaitForChild(moduleName))
        end)
        
        if success then
            _G[moduleName] = module
            MS[moduleName] = module
            print(string.format("✓ 加载根目录模块: %s", moduleName))
        else
            print(string.format("✗ 加载根目录模块失败: %s - %s", moduleName, tostring(module)))
        end
    else
        -- Code目录下的模块 (MainStorage/Code/...)
        success, module = pcall(function()
            local currentPath = MS.MainStorage.Code
            -- 逐级导航到目标目录
            for i = 1, #parts - 1 do
                currentPath = currentPath:WaitForChild(parts[i])
            end
            return require(currentPath:WaitForChild(moduleName))
        end)
        
        if success then
            _G[moduleName] = module
            MS[moduleName] = module
            print(string.format("✓ 加载模块: %s (路径: %s)", moduleName, pathString))
        else
            print(string.format("✗ 加载模块失败: %s (路径: %s) - %s", moduleName, pathString, tostring(module)))
        end
    end
    
    return success
end

-- 主加载逻辑
print("开始智能模块加载...")

-- 遍历模块列表进行加载
for _, pathString in ipairs(moduleLoadList) do
    loadModuleFromPath(pathString)
end

-- ServerStorage模块加载列表 - 使用路径字符串
local serverStorageModules = {
    -- ServerStorage根目录模块
    -- "MServerMain",                          -- 服务器主入口（已在别处加载）
    -- "MServerInitPlayer",                    -- 服务器玩家初始化（已在上面加载）
    -- "MServerDataManager",                   -- 服务器数据管理器（已在上面加载）
    -- "MCloudDataMgr",                        -- 云数据管理器（已在上面加载）
    -- "CustomServerManager",                  -- 自定义服务器管理器
    
    -- MSystems系统模块 (ServerStorage/MSystems/...)
    -- "MSystems/Bag/CustomBagComponent",      -- 自定义背包组件
    -- "MSystems/Mail/CustomMailComponent",    -- 自定义邮件组件
    -- "MSystems/spells/SpellManager",         -- 技能管理器
    -- "MSystems/spells/CustomSpell",          -- 自定义技能
    -- "MSystems/spells/spell_types/CustomSpellType", -- 自定义技能类型
    -- "MSystems/Shop/ShopManager",            -- 商店管理器
    -- "MSystems/Shop/ShopItem",               -- 商店物品
    -- "MSystems/Battle/BattleManager",        -- 战斗管理器
    -- "MSystems/Battle/BattleRoom",           -- 战斗房间
}

-- ServerStorage模块加载函数
local function loadServerStorageModule(pathString)
    local parts = {}
    -- 分割路径
    for part in pathString:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then return false end
    
    local moduleName = parts[#parts] -- 最后一部分是模块名
    local success, module
    
    if #parts == 1 then
        -- ServerStorage根目录模块
        success, module = pcall(function()
            return require(MS.ServerStorage:WaitForChild(moduleName))
        end)
        
        if success then
            _G[moduleName] = module
            MS[moduleName] = module
            print(string.format("✓ 加载服务器根模块: %s", moduleName))
        else
            print(string.format("✗ 加载服务器根模块失败: %s - %s", moduleName, tostring(module)))
        end
    else
        -- ServerStorage子目录模块
        success, module = pcall(function()
            local currentPath = MS.ServerStorage
            -- 逐级导航到目标目录
            for i = 1, #parts - 1 do
                currentPath = currentPath:WaitForChild(parts[i])
            end
            return require(currentPath:WaitForChild(moduleName))
        end)
        
        if success then
            _G[moduleName] = module
            MS[moduleName] = module
            print(string.format("✓ 加载服务器模块: %s (路径: %s)", moduleName, pathString))
        else
            print(string.format("✗ 加载服务器模块失败: %s (路径: %s) - %s", moduleName, pathString, tostring(module)))
        end
    end
    
    return success
end

-- 服务器端专用模块加载
if MS.RunService:IsServer() then
    print("开始加载服务器端模块...")
    
    -- 遍历服务器模块列表进行加载
    for _, pathString in ipairs(serverStorageModules) do
        loadServerStorageModule(pathString)
    end
end

-- 客户端专用模块加载列表 - 使用路径字符串
local clientModules = {
    -- MainStorage根目录的客户端专用模块
    -- "ClientUIManager",                      -- 客户端UI管理器
    -- "ClientEffectManager",                  -- 客户端特效管理器
    -- "ClientSoundManager",                   -- 客户端音效管理器
    -- "ClientInputManager",                   -- 客户端输入管理器
    -- "ClientCameraManager",                  -- 客户端相机管理器
    -- "ClientResourceManager",                -- 客户端资源管理器
    
    -- Code目录下的客户端专用模块
    -- "Client/Graphics/EffectRenderer",       -- 特效渲染器
    -- "Client/Audio/SoundController",         -- 音效控制器
    -- "Client/Input/InputHandler",            -- 输入处理器
    -- "Client/UI/UIAnimationManager",         -- UI动画管理器
}

-- 客户端专用模块加载
if MS.RunService:IsClient() then
    print("开始加载客户端专用模块...")
    
    -- 遍历客户端模块列表进行加载
    for _, pathString in ipairs(clientModules) do
        loadModuleFromPath(pathString)
    end
end

print("智能模块加载系统加载完成")

-- 全局引用（兼容旧代码）
gg = MS.MGlobal
ClassMgr = MS.ClassMgr

print("🎉 MS模块系统初始化完成 - 所有管理器已就绪")

return MS