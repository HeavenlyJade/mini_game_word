# RewardEventManager.NotifyNewAvailable 优化说明

## 优化目标
修改`RewardEventManager.NotifyNewAvailable(player)`方法，向客户端发送更详细的状态信息，包括：
- 可以领取的索引
- 已经领取的索引  
- 不可领取的索引

这样便于客户端的OnlineRewardsGui在OnNewAvailable事件中更好地显示和更新UI状态。

## 主要修改内容

### 1. 新增Reward类方法
在`Reward.lua`中添加了`GetAllRewardStatusIndices()`方法：
```lua
--- 获取所有奖励的状态分类
---@return table 包含可领取、已领取、不可领取索引的分类表
function Reward:GetAllRewardStatusIndices()
    local availableIndices = {}  -- 可领取的索引
    local claimedIndices = {}    -- 已领取的索引
    local unavailableIndices = {} -- 不可领取的索引
    
    -- 遍历所有奖励，根据状态分类
    for index, reward in ipairs(self.onlineConfig.rewardList) do
        local status = self:GetRewardStatus(index)
        
        if status == 1 then
            table.insert(availableIndices, index)      -- 可领取
        elseif status == 2 then
            table.insert(claimedIndices, index)        -- 已领取
        else
            table.insert(unavailableIndices, index)    -- 不可领取
        end
    end
    
    return {
        available = availableIndices,
        claimed = claimedIndices,
        unavailable = unavailableIndices
    }
end
```

### 2. 优化RewardEventManager.NotifyNewAvailable方法
修改后的方法现在发送更详细的数据：
```lua
-- 发送给客户端的数据结构
{
    cmd = RewardEvent.NOTIFY.NEW_AVAILABLE,
    hasAvailable = true/false,
    availableIndices = {1, 2, 3},      -- 可领取的索引数组
    claimedIndices = {4, 5},           -- 已领取的索引数组
    unavailableIndices = {6, 7, 8},    -- 不可领取的索引数组
    onlineTime = 600                   -- 当前在线时长
}
```

### 3. 优化客户端OnNewAvailable事件处理
修改了`OnlineRewardsGui:OnNewAvailable(data)`方法：
- 处理可领取索引：更新状态为1（可领取）
- 处理已领取索引：更新状态为2（已领取）
- 处理不可领取索引：更新状态为0（不可领取）
- 使用数组格式，更简洁高效

## 优化效果

### 数据完整性
- 客户端能收到所有奖励的完整状态信息
- 不再需要猜测或重新请求数据
- 支持批量状态更新

### 性能提升
- 减少不必要的数据请求
- 一次性更新所有奖励状态
- 提高UI响应速度

### 用户体验
- 界面状态立即更新
- 所有奖励状态同步显示
- 更准确的视觉反馈

## 状态定义
- `0`: 不可领取（未达成）- 按钮灰色，不可点击
- `1`: 可领取 - 按钮正常，可点击
- `2`: 已领取 - 按钮灰色，不可点击

## 使用示例
```lua
-- 服务端发送详细状态
RewardEventManager.NotifyNewAvailable(player)

-- 客户端接收并处理
function OnlineRewardsGui:OnNewAvailable(data)
    -- 更新可领取奖励
    for _, index in ipairs(data.availableIndices) do
        self:UpdateSingleRewardStatus(index, 1)
    end
    
    -- 更新已领取奖励
    for _, index in ipairs(data.claimedIndices) do
        self:UpdateSingleRewardStatus(index, 2)
    end
    
    -- 更新不可领取奖励
    for _, index in ipairs(data.unavailableIndices) do
        self:UpdateSingleRewardStatus(index, 0)
    end
end
```
