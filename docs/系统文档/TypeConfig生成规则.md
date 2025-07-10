# TypeConfig 文件生成规则

## 1. 概述

`TypeConfig` 目录中的 Lua 文件旨在为 `Config` 目录中由工具（如`ConfigExporter`）生成的原始配置数据提供一个结构化、面向对象的编程接口。

这个机制的核心目标是将**游戏策划维护的配置数据**（通常使用易于理解的中文键）与**程序员在游戏逻辑中使用的代码**（使用标准化的英文属性名）进行解耦，从而提高代码的可读性、可维护性和健壮性。

## 2. 核心原则

- **数据源**: `Config` 目录下的文件 (例如 `ItemTypeConfig.lua`) 是原始数据源，通常由外部工具从表格（如 Excel）导出，使用**中文键**。
- **数据封装**: `TypeConfig` 目录下的文件 (例如 `ItemType.lua`) 定义了一个 Lua 类，它封装了原始数据，将中文键映射为**英文属性**，供游戏逻辑调用。

## 3. 生成规则

所有新的 `TypeConfig` 文件都应严格遵循以下规则进行创建。

### 3.1 文件用途与命名

- **用途**: `Type` 文件的唯一作用是定义一个 Lua 类，用于解析和包装来自相应 `Config` 文件中的数据。
- **命名**: 文件名应清晰地反映其所代表的数据类型，通常采用"类型名+Type"的格式（如 `ItemType.lua`）或复数形式（如 `SkillTypes.lua`）。

### 3.2 类的定义

- **创建类**: 文件内部必须使用 `ClassMgr.Class("ClassName")` 来定义一个类。类名应为该类型的单数形式（例如 `ItemType.lua` 中定义 `ItemType` 类）。
- **EmmyLua/Luanotations 注解**: **必须**为类及其所有字段添加注解。这可以极大地提升代码的可读性和开发效率（提供自动补全和类型检查）。
- **字段注解规范**: 每个字段的注解 (`---@field`) 都应包含三个部分：**英文属性名**、**Lua 数据类型** (`string`, `number`, `table` 等) 和与 `Config` 文件中键名一致的**中文描述**。

  ```lua
  ---@class ItemType:Class
  ---@field name string 物品名称
  ---@field icon string 物品图标
  ---@field quality string 物品品质
  ---@field power number 战力
  ---@field tags table 标签
  ```

### 3.3 构造函数 (`OnInit` 方法)

- **方法定义**: 类中必须包含一个 `OnInit(data)` 方法，作为类的构造函数。
- **`data` 参数**: 该方法接收一个 `data` 参数，这个参数是从对应 `Config` 文件的数据表中传入的单个条目（例如 `ItemTypeConfig.Data['加速卡']`）。
- **数据映射**: 在 `OnInit` 方法内部，核心任务是将 `data` 表中以**中文为键**的值，赋给 `self` 对象下以**英文为键**的属性。
- **提供默认值**: **必须**为每个属性提供一个合理的默认值，以防止因策划漏填配置而导致程序在运行时出现 `nil` 错误。推荐使用 `or` 操作符来优雅地处理。

  ```lua
  function ItemType:OnInit(data)
      -- 使用 or 为每个属性提供默认值
      self.name = data["名字"] or "Unknown Item"
      self.icon = data["图标"] or ""
      self.quality = data["品级"] or "普通"
      self.power = data["战力"] or 0
      self.tags = data["标签"] or {}
  end
  ```

### 3.4 必需的依赖

文件头部必须通过 `require` 引入 `ClassMgr` 模块来支持类的创建。

```lua
local MainStorage  = game:GetService('MainStorage')
local ClassMgr    = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
```

---

## 4. 示例：创建新的 `MonsterType.lua`

假设需要为一种新的"怪物"(Monster) 添加配置，流程如下：

### 步骤 1: 生成 `MonsterConfig.lua`

首先，由配置导出工具生成 `MonsterConfig.lua`，其中包含 `MonsterConfig.Data` 表。

```lua
-- /Config/MonsterConfig.lua (由工具自动生成)
MonsterConfig.Data = {
    ['野猪'] = { ['怪物名'] = '野猪', ['生命值'] = 100, ['攻击力'] = 10 },
    ['哥布林'] = { ['怪物名'] = '哥布林', ['生命值'] = 50, ['攻击力'] = 5, ['特殊能力'] = {'偷窃'} }
}
return MonsterConfig
```

### 步骤 2: 手动创建 `MonsterType.lua`

在 `scriptFiles/game/MainStorage/Code/Common/TypeConfig/` 目录下创建 `MonsterType.lua` 文件，并遵循上述规则编写代码：

```lua
-- /TypeConfig/MonsterType.lua (手动创建)

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr

---@class MonsterType:Class
---@field name string 怪物名
---@field hp number 生命值
---@field attack number 攻击力
---@field abilities table 特殊能力
---@field New fun(data:table):MonsterType
local MonsterType = ClassMgr.Class("MonsterType")

function MonsterType:OnInit(data)
    self.name = data["怪物名"] or "Unknown Monster"
    self.hp = data["生命值"] or 0
    self.attack = data["攻击力"] or 0
    self.abilities = data["特殊能力"] or {}
end

return MonsterType
```

遵循这套规则，可以确保项目配置代码的**统一性**、**可读性**和**可维护性**。

---

## 5. 集成到配置加载器 (`ConfigLoader.lua`)

创建完 `Type.lua` 文件后，必须将其集成到位于 `scriptFiles/game/MainStorage/Code/Common/ConfigLoader.lua` 的中央配置加载器中。只有这样，配置才能在游戏启动时被正确加载、实例化，并供其他模块使用。

集成过程包含以下**四个关键步骤**：

### 步骤 1: 引入 Type 和 Config 文件

在 `ConfigLoader.lua` 的顶部，添加对新的 `Type` 文件和其对应的 `Config` 文件的 `require` 语句。

```lua
-- /Common/ConfigLoader.lua

-- ... 其他 require ...
local LevelType = require(MainStorage.Code.Common.TypeConfig.LevelType)
-- vvv 添加新的 Type 文件 vvv
local SceneNodeType = require(MainStorage.Code.Common.TypeConfig.SceneNodeType)

-- ... 其他 Config ...
local LevelConfig = require(MainStorage.Code.Common.Config.LevelConfig)
-- vvv 添加新的 Config 文件 vvv
local SceneNodeConfig = require(MainStorage.Code.Common.Config.SceneNodeConfig)
```

### 步骤 2: 创建数据缓存表

在 `ConfigLoader` 对象内部，为新类型的数据添加一个用于缓存实例化对象的表。

```lua
-- /Common/ConfigLoader.lua

-- ... 其他缓存表 ...
ConfigLoader.Levels = {}
-- vvv 添加新的缓存表 vvv
ConfigLoader.SceneNodes = {}
```

### 步骤 3: 调用加载函数

在文件下方，添加对 `ConfigLoader.LoadConfig` 的调用，传入新的配置、类型和缓存表。

```lua
-- /Common/ConfigLoader.lua

-- ... 其他加载调用 ...
ConfigLoader.LoadConfig(LevelConfig, LevelType, ConfigLoader.Levels, "Level")
-- vvv 添加新的加载调用 vvv
ConfigLoader.LoadConfig(SceneNodeConfig, SceneNodeType, ConfigLoader.SceneNodes, "SceneNode")
```

### 步骤 4: 提供外部访问接口

最后，在文件末尾为新的配置类型添加一个 `Get` 函数，并添加清晰的类型注解，方便其他系统安全、便捷地访问数据。

```lua
-- /Common/ConfigLoader.lua

-- ... 其他 Get 函数 ...
function ConfigLoader.GetLevel(id)
    return ConfigLoader.Levels[id]
end

-- vvv 添加新的 Get 函数 vvv
---@param id string
---@return SceneNodeType
function ConfigLoader.GetSceneNode(id)
    return ConfigLoader.SceneNodes[id]
end
```

只有完成了这四步，新的 `TypeConfig` 才算**完全集成**到项目中。 