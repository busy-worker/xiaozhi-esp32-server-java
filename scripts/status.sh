#!/bin/bash

# ============================================================
# 小智 ESP32 服务器状态查看脚本
# ============================================================

# 项目根目录
PROJECT_DIR="$HOME/projects/xiaozhi-esp32-server-java"

# PID 文件目录
PID_DIR="$PROJECT_DIR/pids"

# 日志目录
LOG_DIR="$PROJECT_DIR/logs"

# PID 文件
BACKEND_PID="$PID_DIR/backend.pid"
FRONTEND_PID="$PID_DIR/frontend.pid"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================
# 检查服务状态
# ============================================================
check_status() {
    local pid_file=$1
    local service_name=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $service_name: 运行中 (PID: $pid)${NC}"
            return 0
        else
            echo -e "${RED}❌ $service_name: 已停止 (PID 文件存在但进程不存在)${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ $service_name: 未运行${NC}"
        return 1
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo ""
    echo "============================================"
    echo "  小智 ESP32 服务器状态"
    echo "============================================"
    echo ""
    
    check_status "$BACKEND_PID" "后端服务"
    check_status "$FRONTEND_PID" "前端服务"
    
    echo ""
    echo "============================================"
    echo "  系统服务状态"
    echo "============================================"
    echo ""
    
    # MySQL 状态
    if systemctl is-active --quiet mysql; then
        echo -e "${GREEN}✅ MySQL: 运行中${NC}"
    else
        echo -e "${RED}❌ MySQL: 未运行${NC}"
    fi
    
    # Redis 状态
    if redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis: 运行中${NC}"
    else
        echo -e "${RED}❌ Redis: 未运行${NC}"
    fi
    
    echo ""
    echo "============================================"
    echo "  日志文件"
    echo "============================================"
    echo ""
    echo "后端日志: $LOG_DIR/backend.log"
    echo "前端日志: $LOG_DIR/frontend.log"
    echo ""
    echo "查看后端日志: tail -f $LOG_DIR/backend.log"
    echo "查看前端日志: tail -f $LOG_DIR/frontend.log"
    echo ""
}

main

