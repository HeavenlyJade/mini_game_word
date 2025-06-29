# MS智能模块加载系统使用指南

## 🚀 系统特性

### 1. **基于路径字符串的智能加载**
- 使用简洁的路径字符串配置：`"Common/Config/ItemTypeConfig"`
- 自动识别服务器端和客户端环境，按需加载
- 智能错误处理，模块加载失败不会崩溃系统

### 2. **路径分类**
```
路径格式说明：
├── "ModuleName"                          # MainStorage根目录模块
├── "Common/Config/ItemTypeConfig"        # MainStorage/Code/Common/Config/
├── "Event/EventBattle"                   # MainStorage/Code/Event/
├── "Client/UI/CustomView"                # MainStorage/Code/Client/UI/
├── "MServer/Systems/CustomSystem"        # MainStorage/Code/MServer/Systems/
└── "MSystems/Bag/CustomBagComponent"     # ServerStorage/MSystems/Bag/
```

## 📝 使用方法

### 1. **启用模块加载**
在`MS.lua`中找到对应的模块列表，取消注释需要的模块：

```lua
-- 主模块列表 (MainStorage)
local moduleLoadList = {
    "ObjectPool",                           -- ✓ 取消注释来启用
    -- "SceneManager",                      -- ✗ 保持注释表示不加载
    "Common/Config/ItemTypeConfig",         -- ✓ 启用配置模块
    "Event/EventBattle",                    -- ✓ 启用事件模块
}

-- 服务器模块列表 (ServerStorage) 
local serverStorageModules = {
    "CustomServerManager",                  -- ✓ 启用服务器管理器
    "MSystems/Shop/ShopManager",            -- ✓ 启用商店系统
}

-- 客户端模块列表
local clientModules = {
    "ClientUIManager",                      -- ✓ 启用客户端UI管理器
    "Client/Graphics/EffectRenderer",       -- ✓ 启用特效渲染器
}
```

### 2. **路径规则**
- **单级路径**：`"ModuleName"` → MainStorage根目录或ServerStorage根目录
- **多级路径**：`"Dir1/Dir2/ModuleName"` → 自动导航到对应目录

### 3. **访问加载的模块**
两种方式都可以：

```lua
-- 方式1：全局变量访问（兼容传统用法）
local config = ItemTypeConfig.GetConfig(itemId)

-- 方式2：MS命名空间访问（推荐）
local config = MS.ItemTypeConfig.GetConfig(itemId)
```

### 4. **添加自定义模块**
在对应的模块列表中添加你的路径：

```lua
local moduleLoadList = {
    "Common/Config/ItemTypeConfig",         -- 现有模块
    "Common/Config/MyCustomConfig",         -- 你的自定义模块
    "Event/MyCustomEvent",                  -- 你的自定义事件
    "MyRootModule",                         -- 根目录自定义模块
}
```

## 🎯 配置示例

### 启用常用模块
```lua
-- 主模块列表
local moduleLoadList = {
    -- 根目录模块
    "ObjectPool",                           -- 对象池管理器
    "SceneManager",                         -- 场景管理器
    
    -- 配置模块
    "Common/Config/ItemTypeConfig",         -- 物品类型配置
    "Common/Config/SkillConfig",            -- 技能配置
    "Common/Icon/ui_icon",                  -- UI图标
    
    -- 事件模块
    "Event/EventBattle",                    -- 战斗事件
    "Event/EventPlayer",                    -- 玩家事件
    
    -- 自定义模块
    "Untils/CustomUtils",                   -- 自定义工具
    "MServer/Systems/CustomSystem",         -- 自定义系统
}

-- 服务器模块列表
local serverStorageModules = {
    "CustomServerManager",                  -- 自定义服务器管理器
    "MSystems/Shop/ShopManager",            -- 商店管理器
    "MSystems/Battle/BattleManager",        -- 战斗管理器
}

-- 客户端模块列表
local clientModules = {
    "ClientUIManager",                      -- 客户端UI管理器
    "Client/Graphics/EffectRenderer",       -- 特效渲染器
    "Client/Audio/SoundController",         -- 音效控制器
}
```

## 🔧 路径解析规则

### MainStorage模块路径解析
- `"ModuleName"` → `MainStorage:WaitForChild("ModuleName")`
- `"Dir1/ModuleName"` → `MainStorage.Code.Dir1:WaitForChild("ModuleName")`
- `"Dir1/Dir2/ModuleName"` → `MainStorage.Code.Dir1.Dir2:WaitForChild("ModuleName")`

### ServerStorage模块路径解析
- `"ModuleName"` → `ServerStorage:WaitForChild("ModuleName")`
- `"MSystems/ModuleName"` → `ServerStorage.MSystems:WaitForChild("ModuleName")`
- `"MSystems/Dir/ModuleName"` → `ServerStorage.MSystems.Dir:WaitForChild("ModuleName")`

## 🚨 注意事项

1. **路径使用正斜杠**：`"Common/Config/ItemType"` ✓（正确）
2. **模块名与文件名一致**：路径最后部分必须与lua文件名完全一致
3. **路径区分大小写**：`"Common"` ≠ `"common"`
4. **避免重复加载**：已在其他地方加载的模块建议注释掉
5. **环境自动识别**：服务器和客户端模块会自动分离加载

## 📊 日志输出

系统启动时会显示详细的加载信息：
```
开始智能模块加载...
✓ 加载根目录模块: ObjectPool
✓ 加载模块: ItemTypeConfig (路径: Common/Config/ItemTypeConfig)
✓ 加载模块: EventBattle (路径: Event/EventBattle)
开始加载服务器端模块...
✓ 加载服务器模块: ShopManager (路径: MSystems/Shop/ShopManager)
开始加载客户端专用模块...
✓ 加载模块: EffectRenderer (路径: Client/Graphics/EffectRenderer)
智能模块加载系统加载完成
🎉 MS模块系统初始化完成 - 所有管理器已就绪
```

## 🎯 与旧版本对比

### 旧版本（字典嵌套）
```lua
["Common"] = {
    ["Config"] = {
        "ItemTypeConfig",
        "SkillConfig",
    }
}
```

### 新版本（路径字符串）
```lua
"Common/Config/ItemTypeConfig",
"Common/Config/SkillConfig",
```

**优势**：
- ✅ 更简洁直观
- ✅ 易于添加和管理
- ✅ 路径清晰明了
- ✅ 减少嵌套层次 