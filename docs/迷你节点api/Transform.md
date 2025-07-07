# Transform 节点 API 文档

**继承自：** `SandboxNode`

**描述：**
提供位移、旋转、缩放等空间操作的基类节点，是场景中所有具有3D坐标物体的基础。

---

## 属性 (Properties)

| 属性名 | 类型 | 描述 |
| :--- | :--- | :--- |
| `Position` | `Vector3` | 节点在世界空间中的坐标。 |
| `Rotation` | `Quaternion`| 节点在世界空间中的旋转（四元数）。 |
| `Euler` | `Vector3` | 节点在世界空间中的旋转（欧拉角）。 |
| `LocalPosition`| `Vector3` | 相对于父节点的局部坐标。 |
| `LocalRotation`| `Quaternion`| 相对于父节点的局部旋转（四元数）。 |
| `LocalEuler` | `Vector3` | 相对于父节点的局部旋转（欧拉角）。 |
| `LocalScale` | `Vector3` | 相对于父节点的局部缩放。 |
| `Visible` | `bool` | 节点是否可见。设置为 `false` 会隐藏自身及其所有子节点。 |
| `CubeBorderEnable`| `bool` | 是否启用立方体边框显示。 |
| `CubeBorderColor`| `ColorQuad` | 立方体边框的颜色。 |
| `Layer` | `LayerIndexDesc` | 节点所在的灯光层级。 |
| `LayerCoverChild`| `bool` | 是否将自身的灯光层级设置强制覆盖所有子节点。 |
| `ForwardDir` | `Vector3` | **[只读]** 节点当前的"前方"方向向量。 |
| `Locked` | `bool` | 在编辑器中，该节点是否被锁定，无法通过鼠标点选操作。 |

---

## 函数 (Functions)

| 函数名 | 返回值 | 描述 |
| :--- | :--- | :--- |
| `GetRenderPosition()`| `Vector3` | 获取最终渲染时，该节点在世界空间中的位置。 |
| `GetRenderRotation()`| `Quaternion`| 获取最终渲染时，该节点在世界空间中的旋转（四元数）。 |
| `GetRenderEuler()` | `Vector3` | 获取最终渲染时，该节点在世界空间中的旋转（欧拉角）。 |
| `SetLocalPosition(x, y, z)` | `void` | 设置相对于父节点的局部坐标。 |
| `SetLocalScale(x, y, z)` | `void` | 设置相对于父节点的局部缩放。 |
| `SetLocalEuler(x, y, z)` | `void` | 设置相对于父节点的局部旋转（欧拉角）。 |
| `SetWorldPosition(x, y, z)` | `void` | 设置节点在世界空间中的坐标。 |
| `SetWorldScale(x, y, z)` | `void` | 设置节点在世界空间中的缩放。 |
| `SetWorldEuler(x, y, z)` | `void` | 设置节点在世界空间中的旋转（欧拉角）。 |
| `LookAt(targetPos, useY)` | `void` | 使节点的Z轴（前方）朝向一个世界空间坐标点。`useY`决定是否在Y轴上旋转。 |
| `LookAtObject(targetNode, useY)`| `void` | 使节点的Z轴（前方）朝向另一个节点。 |

---

## 代码示例

```lua
-- 创建一个空的 Transform 节点作为容器
local trans = SandboxNode.new('Transform')

-- 获取工作区
local workSpace = game.WorkSpace

-- 设置其父节点为工作区，使其成为场景根目录下的一个节点
trans:SetParent(workSpace)

-- 设置其在世界空间中的位置
trans.Position = Vector3.new(100, 100, 100)

-- 设置其相对于自身原始大小的缩放
-- 这里表示在X轴方向上放大20倍，Y和Z轴保持不变
trans.LocalScale = Vector3.new(20, 1, 1)

-- 让它朝向世界原点
trans:LookAt(Vector3.new(0, 0, 0), true)
``` 