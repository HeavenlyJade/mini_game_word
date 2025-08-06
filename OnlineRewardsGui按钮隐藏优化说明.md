# OnlineRewardsGui 按钮隐藏优化说明

## 优化目标
对已领取的奖励对应的领取按钮进行隐藏，提升用户体验，避免玩家点击已领取的奖励。

## 主要修改内容

### 1. 新增按钮隐藏/显示方法

#### HideClaimButton(index) - 隐藏领取按钮
```lua
--- 隐藏领取按钮
---@param index number 奖励索引
function OnlineRewardsGui:HideClaimButton(index)
    -- 隐藏UI按钮
    local claimButton = backgroundNode:FindFirstChild("领取")
    if claimButton then
        claimButton.Visible = false
    end
    
    -- 禁用ViewButton
    local slotButton = self.rewardButtons[index]
    if slotButton then
        slotButton:SetGray(true)
        slotButton:SetTouchEnable(false, nil)
    end
end
```

#### ShowClaimButton(index) - 显示领取按钮
```lua
--- 显示领取按钮（用于恢复状态）
---@param index number 奖励索引
function OnlineRewardsGui:ShowClaimButton(index)
    -- 显示UI按钮
    local claimButton = backgroundNode:FindFirstChild("领取")
    if claimButton then
        claimButton.Visible = true
    end
    
    -- 根据状态启用ViewButton
    local canClaim = rewardStatus.status == 1
    slotButton:SetGray(not canClaim)
    slotButton:SetTouchEnable(canClaim, nil)
end
```

### 2. 优化状态更新逻辑

#### UpdateSingleRewardStatus 方法增强
```lua
function OnlineRewardsGui:UpdateSingleRewardStatus(index, status)
    -- 更新本地数据
    -- 更新UI显示
    
    -- 特殊处理：已领取的奖励隐藏按钮
    if status == 2 then
        self:HideClaimButton(index)
    end
end
```

#### UpdateRewardSlotStatus 方法增强
```lua
function OnlineRewardsGui:UpdateRewardSlotStatus(slotNode, rewardStatus, index)
    -- 更新状态显示
    -- 更新按钮状态
    
    -- 特殊处理：已领取的奖励隐藏按钮，其他状态显示按钮
    if rewardStatus.status == 2 then
        self:HideClaimButton(index)
    else
        self:ShowClaimButton(index)
    end
end
```

## 优化效果

### 用户体验提升
- **已领取奖励**：按钮完全隐藏，避免误点击
- **可领取奖励**：按钮正常显示，可点击
- **不可领取奖励**：按钮显示但灰色，不可点击

### 视觉反馈改进
- 状态为2（已领取）时：按钮完全隐藏
- 状态为1（可领取）时：按钮正常显示且可点击
- 状态为0（不可领取）时：按钮显示但灰色且不可点击

### 错误处理增强
- 添加了详细的日志输出
- 增加了节点查找失败的错误提示
- 确保UI状态与数据状态同步

## 状态定义
- `0`: 不可领取（未达成）- 按钮显示但灰色，不可点击
- `1`: 可领取 - 按钮正常显示，可点击
- `2`: 已领取 - 按钮完全隐藏

## 使用示例
```lua
-- 当奖励状态变为已领取时
self:UpdateSingleRewardStatus(index, 2)  -- 自动隐藏按钮

-- 当奖励状态变为可领取时
self:UpdateSingleRewardStatus(index, 1)  -- 显示按钮并启用

-- 当奖励状态变为不可领取时
self:UpdateSingleRewardStatus(index, 0)  -- 显示按钮但禁用
```

## 技术细节

### 按钮隐藏机制
1. **UI层面**：设置`claimButton.Visible = false`
2. **逻辑层面**：设置`slotButton:SetTouchEnable(false, nil)`
3. **视觉层面**：设置`slotButton:SetGray(true)`

### 状态同步
- 本地数据状态与UI显示状态完全同步
- 支持批量状态更新
- 实时响应服务端状态变化

### 错误处理
- 节点不存在时的警告日志
- 按钮查找失败时的错误提示
- 确保操作的安全性
