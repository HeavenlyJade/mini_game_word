# RunService 节点 API 文档

**继承自：** `Service`

**描述：**
一个服务！管理游戏的脚本以及事件。此类是一个服务，它是顶级单例，可以使用`GetService`函数获取。包含了用于时间管理的方法和事件，以及管理游戏或脚本所处于的内容。`IsClient`、`IsServer`、`IsStudio`等方法可以帮助你确定Lua代码在哪里运行。这些方法对于客户端和服务器都需要的`ModuleScript`是很有帮助的。

---

## 属性 (Properties)

| 属性名 | 类型 | 描述 |
| :--- | :--- | :--- |
| `LogicFPS` | `int` | 逻辑帧数。 |
| `UpdateFPS` | `int` | 上传帧。 |

---

## 函数 (Functions)

| 函数名 | 返回值 | 描述 |
| :--- | :--- | :--- |
| `Pause()` | `void` | 如果游戏在运行则暂停游戏的模拟，暂停物理运算和脚本。 |
| `BindToRenderStep()` | `void` | 绑定RenderStep事件的Lua函数。`RenderPriority`为当前游戏内渲染层级，可根据需要进行插入。 |
| `UnbindFromRenderStep()`| `void` | 解除绑定RenderStep事件的Lua函数。 |
| `SetAutoTick()` | `void` | 设置自动tick间隙。 |
| `DriveTick()` | `void` | 驱动tick。 |
| `SetFramePerSecond()` | `void` | 设置每秒帧数值。 |
| `IsClient()` | `bool` | 当前的环境是否运行在客户端上。 |
| `IsServer()` | `bool` | 当前的环境是否运行在服务器上。 |
| `IsStudio()` | `bool` | 当前的环境是否运行在studio上。 |
| `IsMobile()` | `bool` | 当前的环境是否运行在手机端上。 |
| `IsPC()` | `bool` | 当前的环境是否运行在电脑端上。 |
| `IsRemote()` | `bool` | 当前的环境是否远程环境。 |
| `IsEdit()` | `bool` | 当前运行环境是否为Edit（编辑)模式。 |
| `IsRunMode()` | `bool` | 当前运行环境是否为Running模式。 |
| `CurrentSteadyTimeStampMS()`| `double` | 获取当前时间戳，精确到毫秒。不随本地时间修改而改变。9位。 |
| `IsAutoTick()` | `bool` | 是否自动tick。 |
| `GetFramePerSecond()` | `int` | 每秒获取帧数。 |
| `GetMiniGameVersion()` | `string` | 获取游戏端版本号。 |
| `GetAppPlatformName()` | `string` | 获取游戏平台名称。 |
| `BindToTickRegister(szKey, priority, func)` | `void` | 绑定Tick事件的Lua函数。 |
| `UnBindFromTickRegister(szKey)` | `void` | 解除绑定Tick事件的Lua函数。 |
| `BindToRenderRegister(szKey, priority, func)`| `void` | 绑定Render事件的Lua函数。`priority`为调用顺序,此方法不建议里面带有wait函数。 |
| `UnBindFromRenderRegister(szKey)` | `void` | 解除绑定Render事件的Lua函数。 |

---

## 事件 (Events)

| 事件名 | 参数 | 描述 |
| :--- | :--- | :--- |
| `HeartBeat` | `(double time)` | 心跳事件。 |
| `RenderStepped` | `(double step)` | 渲染步幅事件，每次Update触发RenderStepped事件。 |
| `Stepped` | `()` | 步幅事件，每次Tick触发Stepped事件。 |
| `SystemStepped` | `()` | 步幅事件，每次系统Tick触发SystemStepped事件。 |

---

## 代码示例

```lua
local runService = game:GetService("RunService")

-- 获取沙盒游戏版本号
local versionStr = runService:GetMiniGameVersion() 
print("Sandbox version ="..versionStr)
``` 