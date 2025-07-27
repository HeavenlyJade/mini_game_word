
# 客户端UI开发规范

本文档旨在为项目建立一套标准化的客户端UI开发流程和规范，以提高开发效率和代码可维护性。

## 1. 核心设计理念

项目UI系统采用基于面向对象和事件驱动的设计模式，其核心思想是将 **UI表现（View）** 与 **业务逻辑（Logic）** 分离。

- **表现层:** 由UI编辑器创建的节点（`SandboxNode`）和一组Lua封装类（`ViewComponent`, `ViewButton`, `ViewList`）组成。
- **逻辑层:** 由具体的UI逻辑脚本（如 `MailGui.lua`, `TalentGui.lua`）负责，它们继承自`ViewBase`，扮演控制器的角色，处理用户输入、与服务端通信以及更新UI表现。

## 2. 核心组件

所有UI都基于以下几个核心封装类来构建：

- **`ViewBase`:** UI界面的基类，管理界面的完整生命周期 (`OnInit`, `OnOpen`, `OnClose`)。
- **`ViewComponent`:** 通用UI节点封装，提供基础的节点操作API。
- **`ViewButton`:** 按钮组件。它通过读取节点上的 **自定义属性** 自动处理点击、悬浮等状态的视觉和音效，实现了“配置优于编码”。
    - **关键属性:**
        - `图片-点击` / `图片-悬浮`: 设置不同状态下的图标。
        - `点击颜色` / `悬浮颜色`: 设置不同状态下的填充色。
        - `音效-点击` / `音效-悬浮`: 设置交互音效。
        - `继承按钮`: 若一个节点的子节点也需要响应点击，则为其勾选此属性。
- **`ViewList`:** 动态列表管理器。它采用 **模板克隆** 模式来高效地生成和管理列表内容。

## 3. 开发流程

创建一个新的UI界面，请遵循以下标准流程：

1.  **创建UI节点:** 在UI编辑器中搭建好界面的所有节点，并为需要动态生成内容的列表创建一个“模板”节点。
2.  **创建逻辑脚本:** 在 `ClientUiMain` 目录下创建一个新的Lua脚本（如 `NewFeatureGui.lua`），使其继承自 `ViewBase`。
3.  **初始化 (`OnInit`):**
    - 在 `OnInit` 方法中，使用 `self:Get("节点路径", WrapperClass)` 获取所有需要交互的UI节点，并用对应的`View*`类进行包装。
    - 注册所有需要监听的服务端事件 (`ClientEventManager.Subscribe`)。
    - 注册所有按钮的点击回调 (`button.clickCb = ...`)。
4.  **请求初始数据 (`OnOpen`):**
    - 在 `OnOpen` 方法中，调用 `gg.network_channel:FireServer({...})` 向服务器请求该界面所需的初始数据。
5.  **处理服务端数据:**
    - 在 `ClientEventManager` 注册的回调函数中，处理服务端返回的数据（`RESPONSE`）或推送的通知（`NOTIFY`）。
    - 收到数据后，更新本地缓存，并调用UI刷新函数。
6.  **实现UI刷新:**
    - 编写独立的UI刷新函数（如 `RefreshDisplay`）。
    - 对于列表，遍历数据，克隆模板节点，填充内容，并添加到`ViewList`中。
    - 对于单个组件，直接更新其属性（如 `node.Title`、`node.Icon`）。
7.  **处理用户操作:**
    - 在按钮的 `clickCb` 回调中，准备好需要发送给服务器的数据，并调用 `gg.network_channel:FireServer({...})` 发送请求。

## 4. 与服务端通信

- **C2S (Client to Server):** 统一使用 `gg.network_channel:FireServer(payload)` 发送请求。`payload` 必须包含一个 `cmd` 字段，其值在 `MainStorage/Code/Event/` 目录下的对应事件配置文件中定义。
- **S2C (Server to Client):** 统一使用 `ClientEventManager.Subscribe(eventName, callback)` 监听事件。事件同样在事件配置文件中定义，分为 `RESPONSE` 和 `NOTIFY` 两类。

遵循以上规范，可以确保客户端UI代码风格统一，结构清晰，易于扩展和维护。 