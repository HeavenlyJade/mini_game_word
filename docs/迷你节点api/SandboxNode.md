# SandboxNode 节点 API 文档

**描述：**
沙盒节点，是场景中所有对象的基础节点，构成了整个场景树的骨架。

---

## 属性 (Properties)

| 属性名 | 类型 | 描述 |
| :--- | :--- | :--- |
| `ClassType` | `string` | **[只读]** 节点的类名 (e.g., "Model", "Actor", "Transform")。 |
| `Name` | `string` | 节点名，可通过 `FindFirstChild` 等方法进行查找。 |
| `Tag` | `int` | 节点标签，可用于自定义分类。 |
| `Parent` / `parent`| `SandboxNode` | **[只读]** 获取该节点的父节点。 |
| `Children` | `table` | **[只读] [仅脚本]** 获取一个包含所有直接子节点的表。 |
| `Enabled` | `bool` | 节点是否启用。禁用后，节点的逻辑、事件、通知等将不生效。 |
| `Attributes` | `AttributeContainer`| **[只读] [仅脚本]** 获取节点的属性容器。 |
| `SyncMode` | `NodeSyncMode` | **[仅主机]** 设置节点的同步模式。 |
| `LocalSyncFlag` | `NodeSyncLocalFlag`| 本地同步标识，此处的属性变更不需要同步给其他客户端。 |
| `OwnerUin` | `int` | **[仅主机]** 设置该节点的所有者玩家UIN。 |
| `IgnoreSafeMode` | `bool` | 是否忽略安全模式。 |
| `ResourceLoadMode`| `ResourceLoadMode` | 资源的加载模式。`Manual`: 手动加载, `Dynamic`: 动态加载。 |
| `FlagDebug` | `int` | 调试标志位。 |
| ~~`ResourceDynamicLoad`~~ | `bool` | **[已废弃]** 请使用 `ResourceLoadMode` 替代。 |

---

## 函数 (Functions)

| 函数名 | 返回值 | 描述 |
| :--- | :--- | :--- |
| `Destroy()` | `void` | 销毁此节点及其所有子节点。 |
| `ClearAllChildren()`| `void` | 清除（销毁）所有子节点，但保留本节点。 |
| `SetParent(parent)` | `void` | 设置该节点的父节点。 |
| `Clone()` | `SandboxNode` | 克隆一个与当前节点完全相同的新节点，包括其属性和子节点。 |
| `FindFirstChild(name)`| `SandboxNode` | 通过节点名递归查找并返回第一个匹配的子节点对象。 |
| `GetNodeid()` | `SandboxNodeID`| 获取节点的唯一ID。 |
| `IsA(className)` | `bool` | 判断该节点的 `ClassType` 是否为指定的类或其子类。 |
| `AddAttribute(name, type)`| `void` | 添加一个自定义的反射属性。 |
| `DeleteAttribute(name)`| `void` | 通过属性名删除一个自定义的反射属性。 |
| `GetAttribute(name)`| `ReflexVariant`| 获取指定的自定义或内置反射属性的值。 |
| `SetAttribute(name, value)`| `bool` | 设置指定的自定义或内置反射属性的值。 |
| `SetReflexSyncMode(mode)`| `void` | **[仅主机]** 设置反射属性的同步模式。 |
| `SetReflexLocalSyncFlag(flag)`| `void` | 设置反射属性的本地同步标记。 |
| `GetReflexSyncMode()`| `SYNCMODE` | 获取反射属性的同步模式。 |
| `GetReflexLocalSyncFlag()`|`SYNCLOCALFLAG`| 获取反射属性的本地同步标记。 |
| `ManualLoad()` | `void` | 当 `ResourceLoadMode` 为 `Manual` 时，手动加载该节点资源。 |
| `ManualLoadAsync()` | `void` | 异步地手动加载节点资源。 |
| `ManualUnLoad()` | `void` | 主动卸载节点资源。 |

---

## 事件 (Events)

| 事件名 | 参数 | 描述 |
| :--- | :--- | :--- |
| `AncestryChanged` | `(SandboxNode ancestry)` | 当节点的任何一个祖先节点发生变化时触发。 |
| `ParentChanged` | `(SandboxNode parent)` | 当节点的直接父节点发生变化时触发。 |
| `AttributeChanged`| `(string attrName)` | 当一个内置的反射属性值发生变化时触发。 |
| `CustomAttrChanged`| `(string attrName)` | 当一个自定义的反射属性值发生变化时触发。 |
| `ChildAdded` | `(SandboxNode child)` | 当一个子节点被添加到该节点下时触发。 |
| `ChildRemoved` | `(SandboxNode child)` | 当一个子节点从该节点移除时触发。 |

---

## 代码示例

```lua
--[[
  假设我们有一个节点 `node`，
  并且已经在编辑器或通过代码为它添加了一个名为 "test_k" 的自定义属性，类型为布尔值(bool)。
]]

-- 获取名为 "test_k" 的自定义属性的当前值
local currentValue = node:GetAttribute("test_k")
print("test_k 的当前值是:", currentValue)

-- 设置 "test_k" 的值为 true
node:SetAttribute("test_k", true)

-- 监听该自定义属性的变化
node.CustomAttrChanged:Connect(function(changedAttrName)
    if changedAttrName == "test_k" then
        local newValue = node:GetAttribute("test_k")
        print("属性 'test_k' 的值已变更为:", newValue)
    end
end)

-- 再次修改属性值，将会触发上面的监听函数
node:SetAttribute("test_k", false)
``` 