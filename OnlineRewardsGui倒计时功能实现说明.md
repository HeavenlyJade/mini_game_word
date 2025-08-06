# OnlineRewardsGui 倒计时功能实现说明

## 功能概述

为在线奖励界面添加了客户端倒计时功能，实现实时显示剩余时间，当时间到达时自动更新奖励状态为可领取。

## 主要功能

### 1. 倒计时定时器管理
- **启动定时器**: `StartCountdownTimer()` - 创建每秒执行的定时器
- **停止定时器**: `StopCountdownTimer()` - 清理定时器资源
- **定时器生命周期**: 界面显示时启动，隐藏时停止

### 2. 在线时长同步
- **服务端同步**: 通过 `OnNewAvailable` 事件接收服务端的在线时长
- **初始化同步**: 通过 `OnRewardDataResponse` 获取初始在线时长
- **本地计时**: 客户端每秒增加在线时长，实现实时倒计时

### 3. 时间显示逻辑
- **已领取**: 显示"已领取"
- **可领取**: 显示"可领取"  
- **未达成**: 显示倒计时格式（HH:MM:SS 或 MM:SS）

### 4. 自动状态更新
- **时间到达检测**: 当剩余时间为0时，自动将奖励状态更新为可领取
- **按钮状态同步**: 根据奖励状态自动显示/隐藏领取按钮

## 核心方法

### 倒计时更新
```lua
function OnlineRewardsGui:UpdateCountdown()
    -- 增加在线时长
    self.onlineTime = self.onlineTime + 1
    
    -- 更新所有奖励槽位的时间显示
    self:UpdateAllRewardTimeDisplays()
    
    -- 检查是否有新的奖励变为可领取
    self:CheckForNewAvailableRewards()
end
```

### 时间显示更新
```lua
function OnlineRewardsGui:UpdateAllRewardTimeDisplays()
    -- 根据奖励状态显示不同的时间格式
    local currentStatus = self:GetRewardStatus(index)
    if currentStatus == 2 then
        timeNode.Title = "已领取"
    elseif currentStatus == 1 then
        timeNode.Title = "可领取"
    else
        -- 显示倒计时
        timeNode.Title = self:FormatTime(remainingTime)
    end
end
```

### 新奖励检测
```lua
function OnlineRewardsGui:CheckForNewAvailableRewards()
    -- 检查是否有奖励时间到达
    if reward.timeNode and self.onlineTime >= reward.timeNode then
        if currentStatus == 0 then  -- 如果当前是未达成状态
            self:UpdateRewardButtonState(index, 1)  -- 更新为可领取
        end
    end
end
```

## 数据流程

1. **初始化**: 界面显示时启动定时器，从服务端获取初始在线时长
2. **实时更新**: 客户端每秒增加在线时长，更新所有奖励的倒计时显示
3. **状态同步**: 当时间到达时，自动更新奖励状态为可领取
4. **服务端同步**: 定期接收服务端的在线时长更新，保持数据一致性

## 优势

- **实时性**: 客户端每秒更新，提供流畅的倒计时体验
- **准确性**: 定期与服务端同步，确保数据准确性
- **用户体验**: 直观显示剩余时间，增强用户参与感
- **性能优化**: 只在界面显示时运行定时器，避免资源浪费

## 注意事项

- 定时器在界面隐藏时会自动停止，避免不必要的资源消耗
- 客户端和服务端的在线时长会定期同步，确保数据一致性
- 倒计时显示会根据奖励状态动态调整，提供清晰的视觉反馈
