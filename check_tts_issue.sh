#!/bin/bash

# TTS问题排查脚本
# 用于排查"只有文字没有语音"的问题

LOG_FILE="$HOME/projects/xiaozhi-esp32-server-java/logs/backend.log"
DEVICE_ID="${1:-10:20:ba:70:f4:fc}"  # 默认设备ID，可通过参数传入

echo "============================================"
echo "TTS问题排查 - 设备ID: $DEVICE_ID"
echo "============================================"
echo ""

# 1. 检查最近的TTS相关日志
echo "【1】检查最近的TTS生成日志..."
echo "--------------------------------------------"
grep -i "句子音频生成完成\|向设备发送音频消息\|TTS任务失败\|TTS生成失败" "$LOG_FILE" | tail -20
echo ""

# 2. 检查是否有audioPath为null的情况
echo "【2】检查audioPath为null的情况（只发送文本，没有音频）..."
echo "--------------------------------------------"
grep "向设备发送音频消息.*音频路径: null" "$LOG_FILE" | tail -10
echo ""

# 3. 检查TTS失败的情况
echo "【3】检查TTS生成失败的情况..."
echo "--------------------------------------------"
grep -i "TTS任务失败\|TTS生成失败\|已达最大重试次数" "$LOG_FILE" | tail -10
echo ""

# 4. 检查设备连接和角色配置
echo "【4】检查设备连接和角色配置..."
echo "--------------------------------------------"
grep -i "设备信息\|roleId\|ttsId\|开始查询设备信息" "$LOG_FILE" | grep -i "$DEVICE_ID" | tail -10
echo ""

# 5. 检查音频文件生成情况
echo "【5】检查音频文件目录..."
echo "--------------------------------------------"
AUDIO_DIR="$HOME/projects/xiaozhi-esp32-server-java/audio"
if [ -d "$AUDIO_DIR" ]; then
    echo "音频目录存在: $AUDIO_DIR"
    echo "最近生成的音频文件（按时间排序，最新10个）："
    find "$AUDIO_DIR" -type f -name "*.mp3" -o -name "*.wav" -o -name "*.opus" 2>/dev/null | \
        xargs ls -lt 2>/dev/null | head -10
    echo ""
    echo "音频目录文件总数："
    find "$AUDIO_DIR" -type f 2>/dev/null | wc -l
else
    echo "⚠️  音频目录不存在: $AUDIO_DIR"
fi
echo ""

# 6. 检查最近的错误日志
echo "【6】检查最近的错误日志..."
echo "--------------------------------------------"
grep -i "error\|exception\|failed" "$LOG_FILE" | tail -10
echo ""

# 7. 检查特定设备的会话信息
echo "【7】检查设备会话信息..."
echo "--------------------------------------------"
grep -i "SessionId.*$DEVICE_ID\|device.*$DEVICE_ID" "$LOG_FILE" | tail -5
echo ""

echo "============================================"
echo "排查完成"
echo "============================================"
echo ""
echo "关键检查点："
echo "1. 如果看到'音频路径: null'，说明TTS生成失败"
echo "2. 如果看到'TTS任务失败'，需要检查TTS配置"
echo "3. 检查设备角色是否配置了TTS服务（ttsId不为空）"
echo "4. 检查音频目录是否有新文件生成"
echo ""

