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
# 检查服务是否已运行
# ============================================================
check_running() {
    local pid_file=$1
    local service_name=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}$service_name 已在运行 (PID: $pid)${NC}"
            return 0
        fi
    fi
    return 1
}

# ============================================================
# 启动后端
# ============================================================
start_backend() {
    echo -e "${GREEN}========== 启动后端服务 ==========${NC}"
    
    if check_running "$BACKEND_PID" "后端"; then
        return
    fi
    
    # 日志轮转
    rotate_logs "$BACKEND_LOG"
    
    cd "$PROJECT_DIR"
    
    # 设置 JAVA_HOME
    export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
    export PATH=$JAVA_HOME/bin:$PATH
    
    # 启动后端
    nohup java -jar target/xiaozhi.server-*.jar >> "$BACKEND_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$BACKEND_PID"
    
    echo -e "${GREEN}后端服务已启动 (PID: $pid)${NC}"
    echo -e "${GREEN}日志文件: $BACKEND_LOG${NC}"
}

# ============================================================
# 启动前端
# ============================================================
start_frontend() {
    echo -e "${GREEN}========== 启动前端服务 ==========${NC}"
    
    if check_running "$FRONTEND_PID" "前端"; then
        return
    fi
    
    # 日志轮转
    rotate_logs "$FRONTEND_LOG"
    
    cd "$PROJECT_DIR/web"
    
    # 启动前端
    nohup npm run dev -- --host 0.0.0.0 >> "$FRONTEND_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$FRONTEND_PID"
    
    echo -e "${GREEN}前端服务已启动 (PID: $pid)${NC}"
    echo -e "${GREEN}日志文件: $FRONTEND_LOG${NC}"
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

