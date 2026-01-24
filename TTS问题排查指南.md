# TTS问题排查指南 - "只有文字没有语音"

## 问题现象
硬件设备能正常对话，但服务端只返回文字，没有语音数据。

## 排查步骤

### 1. 检查服务器日志

在服务器上执行排查脚本：
```bash
cd ~/projects/xiaozhi-esp32-server-java
chmod +x check_tts_issue.sh
./check_tts_issue.sh [设备ID]
# 例如：./check_tts_issue.sh 10:20:ba:70:f4:fc
```

或者手动检查日志：
```bash
# 查看最近的TTS相关日志
tail -100 ~/projects/xiaozhi-esp32-server-java/logs/backend.log | grep -i "TTS\|音频\|audio"

# 检查是否有"音频路径: null"的日志（说明TTS生成失败）
grep "向设备发送音频消息.*音频路径: null" ~/projects/xiaozhi-esp32-server-java/logs/backend.log | tail -10

# 检查TTS失败日志
grep -i "TTS任务失败\|TTS生成失败" ~/projects/xiaozhi-esp32-server-java/logs/backend.log | tail -10
```

### 2. 检查设备角色配置

**问题原因1：设备角色没有配置TTS服务**

检查步骤：
1. 登录前端管理页面：`http://192.168.0.113:8084`
2. 进入"角色管理"页面
3. 找到设备绑定的角色
4. 检查"语音配置"部分：
   - **TTS配置**：必须选择一个TTS服务（如Edge TTS、阿里云TTS等）
   - **语音名称**：必须选择一个语音（如`zh-CN-XiaoyiNeural`）

**如果TTS配置为空**：
- 选择任意一个TTS服务（推荐使用Edge TTS，无需额外配置）
- 选择一个语音名称
- 保存配置
- 重启后端服务

### 3. 检查TTS服务是否正常工作

**问题原因2：TTS服务生成失败**

检查日志中的关键信息：
```bash
# 查看TTS生成成功的日志（应该看到"句子音频生成完成"）
grep "句子音频生成完成" ~/projects/xiaozhi-esp32-server-java/logs/backend.log | tail -5

# 查看TTS失败的日志
grep "TTS任务失败\|已达最大重试次数" ~/projects/xiaozhi-esp32-server-java/logs/backend.log | tail -5
```

**如果看到TTS失败日志**：
- 检查TTS服务配置是否正确（API密钥、端点地址等）
- 检查网络连接是否正常
- 如果使用Edge TTS，检查服务器是否能访问互联网

### 4. 检查音频文件是否生成

**问题原因3：音频文件生成失败或路径错误**

```bash
# 检查音频目录
ls -lh ~/projects/xiaozhi-esp32-server-java/audio/

# 查看最近生成的音频文件
find ~/projects/xiaozhi-esp32-server-java/audio -type f -name "*.mp3" -o -name "*.wav" | \
    xargs ls -lt | head -10

# 检查目录权限
ls -ld ~/projects/xiaozhi-esp32-server-java/audio
```

**如果音频目录不存在或没有文件**：
- 检查目录权限：`chmod 755 ~/projects/xiaozhi-esp32-server-java/audio`
- 检查磁盘空间：`df -h`
- 检查日志中的错误信息

### 5. 检查代码逻辑

**关键日志点**：

1. **TTS生成开始**：
   ```
   处理LLM返回的句子: seq=1, text=xxx, isFirst=true, isLast=false
   ```

2. **TTS生成成功**：
   ```
   句子音频生成完成 - 序号: 1, 对话ID: xxx, 模型响应: x秒, 语音生成: x秒, 内容: "xxx"
   ```

3. **发送音频消息**：
   ```
   向设备发送音频消息（sendAudioMessage） - SessionId: xxx, 文本: xxx, 音频路径: /path/to/audio.mp3
   ```

4. **如果audioPath为null**：
   ```
   向设备发送音频消息（sendAudioMessage） - SessionId: xxx, 文本: xxx, 音频路径: null
   ```
   这说明TTS生成失败，只会发送文本消息。

### 6. 常见问题及解决方案

#### 问题1：角色没有配置TTS
**症状**：日志中看到`ttsConfig = null`或`ttsId = null`
**解决**：在角色管理中配置TTS服务

#### 问题2：Edge TTS无法访问
**症状**：TTS生成超时或失败
**解决**：
- 检查服务器网络连接
- 检查防火墙设置
- 考虑使用其他TTS服务（如阿里云、讯飞等）

#### 问题3：音频目录权限问题
**症状**：日志中看到文件写入失败
**解决**：
```bash
mkdir -p ~/projects/xiaozhi-esp32-server-java/audio
chmod 755 ~/projects/xiaozhi-esp32-server-java/audio
```

#### 问题4：TTS服务配置错误
**症状**：TTS生成失败，日志中有API错误
**解决**：
- 检查TTS配置中的API密钥是否正确
- 检查端点地址是否正确
- 检查服务配额是否用完

### 7. 快速修复步骤

如果确认是配置问题，按以下步骤修复：

```bash
# 1. 停止服务
cd ~/projects/xiaozhi-esp32-server-java
./scripts/stop.sh

# 2. 检查并修复配置（在前端管理页面）

# 3. 确保音频目录存在且有权限
mkdir -p audio
chmod 755 audio

# 4. 重启服务
./scripts/start.sh

# 5. 查看日志确认
tail -f logs/backend.log | grep -i "TTS\|音频"
```

### 8. 验证修复

修复后，进行以下验证：

1. **发送一条消息给设备**
2. **检查日志**：
   ```bash
   tail -f ~/projects/xiaozhi-esp32-server-java/logs/backend.log | grep -i "音频"
   ```
   应该看到：
   - `句子音频生成完成`
   - `向设备发送音频消息（sendAudioMessage） - SessionId: xxx, 文本: xxx, 音频路径: /path/to/audio.mp3`
   - 音频路径**不应该**是`null`

3. **检查音频文件**：
   ```bash
   ls -lt ~/projects/xiaozhi-esp32-server-java/audio/ | head -5
   ```
   应该看到新生成的音频文件

4. **设备端验证**：设备应该能播放语音

## 联系支持

如果以上步骤都无法解决问题，请提供以下信息：
1. 完整的错误日志（`grep -i "error\|exception\|failed" logs/backend.log | tail -50`）
2. 设备角色配置截图
3. TTS配置详情
4. 音频目录文件列表

