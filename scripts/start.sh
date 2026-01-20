#!/bin/bash

# ============================================================
# 小智 ESP32 服务器启动脚本
# 功能：启动后端和前端服务，日志输出到文件，只保留最近1天
# ============================================================

# 项目根目录
PROJECT_DIR="$HOME/projects/xiaozhi-esp32-server-java"

# 日志目录
LOG_DIR="$PROJECT_DIR/logs"

# PID 文件目录
PID_DIR="$PROJECT_DIR/pids"

# 创建目录
mkdir -p "$LOG_DIR" "$PID_DIR"

# 日志文件
BACKEND_LOG="$LOG_DIR/backend.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"

# PID 文件
BACKEND_PID="$PID_DIR/backend.pid"
FRONTEND_PID="$PID_DIR/frontend.pid"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================
# 清理超过1天的日志
# ============================================================
clean_old_logs() {
    echo -e "${YELLOW}清理超过1天的日志...${NC}"
    find "$LOG_DIR" -name "*.log.*" -mtime +1 -delete 2>/dev/null
    echo -e "${GREEN}日志清理完成${NC}"
}

# ============================================================
# 日志轮转（如果日志文件超过1天，重命名备份）
# ============================================================
rotate_logs() {
    local log_file=$1
    if [ -f "$log_file" ]; then
        local file_age=$(( ($(date +%s) - $(stat -c %Y "$log_file")) / 86400 ))
        if [ $file_age -ge 1 ]; then
            mv "$log_file" "${log_file}.$(date +%Y%m%d%H%M%S)"
        fi
    fi
}

# ============================================================
# 确保后端进程已停止
# ============================================================
ensure_backend_stopped() {
    local pids=$(pgrep -f "xiaozhi.server.*\.jar" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "${YELLOW}发现残留的后端进程，正在清理...${NC}"
        for pid in $pids; do
            echo -e "  停止进程 PID: $pid"
            kill "$pid" 2>/dev/null
        done
        sleep 2
        # 强制杀掉
        pids=$(pgrep -f "xiaozhi.server.*\.jar" 2>/dev/null)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                kill -9 "$pid" 2>/dev/null
            done
        fi
        rm -f "$BACKEND_PID"
    fi
}

# ============================================================
# 启动后端
# ============================================================
start_backend() {
    echo -e "${GREEN}========== 启动后端服务 ==========${NC}"
    
    # 确保旧进程已停止
    ensure_backend_stopped
    
    # 日志轮转
    rotate_logs "$BACKEND_LOG"
    
    cd "$PROJECT_DIR"
    
    # 设置 JAVA_HOME
    export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
    export PATH=$JAVA_HOME/bin:$PATH
    
    # 设置服务器内网 IP（用于返回给设备的 WebSocket 地址）
    export HOST_IP=192.168.0.113
    
    # 检查 jar 文件是否存在
    local jar_file=$(ls -1 target/xiaozhi.server-*.jar 2>/dev/null | head -1)
    if [ -z "$jar_file" ]; then
        echo -e "${RED}错误: 找不到 jar 文件，请先运行 mvn package${NC}"
        return 1
    fi
    
    # 启动后端（添加 websocket 协议参数）
    echo -e "  启动: java -jar $jar_file --xiaozhi.communication.protocol=websocket"
    nohup java -jar "$jar_file" --xiaozhi.communication.protocol=websocket >> "$BACKEND_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$BACKEND_PID"
    
    # 等待启动
    sleep 3
    
    # 确认启动成功
    if ps -p $pid > /dev/null 2>&1; then
        echo -e "${GREEN}后端服务已启动 (PID: $pid)${NC}"
        echo -e "${GREEN}日志文件: $BACKEND_LOG${NC}"
    else
        echo -e "${RED}后端服务启动失败，请查看日志: $BACKEND_LOG${NC}"
        tail -20 "$BACKEND_LOG"
        return 1
    fi
}

# ============================================================
# 确保前端进程已停止
# ============================================================
ensure_frontend_stopped() {
    local pids=$(pgrep -f "vite.*--host" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "${YELLOW}发现残留的前端进程，正在清理...${NC}"
        for pid in $pids; do
            kill "$pid" 2>/dev/null
        done
        sleep 1
        rm -f "$FRONTEND_PID"
    fi
}

# ============================================================
# 启动前端
# ============================================================
start_frontend() {
    echo -e "${GREEN}========== 启动前端服务 ==========${NC}"
    
    # 确保旧进程已停止
    ensure_frontend_stopped
    
    # 日志轮转
    rotate_logs "$FRONTEND_LOG"
    
    cd "$PROJECT_DIR/web"
    
    # 启动前端
    nohup npm run dev -- --host 0.0.0.0 >> "$FRONTEND_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$FRONTEND_PID"
    
    sleep 2
    
    if ps -p $pid > /dev/null 2>&1; then
        echo -e "${GREEN}前端服务已启动 (PID: $pid)${NC}"
        echo -e "${GREEN}日志文件: $FRONTEND_LOG${NC}"
    else
        echo -e "${RED}前端服务启动失败，请查看日志: $FRONTEND_LOG${NC}"
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo ""
    echo "============================================"
    echo "  小智 ESP32 服务器启动脚本"
    echo "============================================"
    echo ""
    
    # 清理旧日志
    clean_old_logs
    
    # 启动服务
    start_backend
    echo ""
    start_frontend
    
    echo ""
    echo "============================================"
    echo -e "${GREEN}所有服务启动完成！${NC}"
    echo "============================================"
    echo ""
    echo "访问地址:"
    echo "  后端 API: http://$(hostname -I | awk '{print $1}'):8091"
    echo "  前端页面: http://$(hostname -I | awk '{print $1}'):8084"
    echo "  默认账号: admin / 123456"
    echo ""
    echo "查看日志:"
    echo "  后端日志: tail -f $BACKEND_LOG"
    echo "  前端日志: tail -f $FRONTEND_LOG"
    echo ""
}

main
