#!/bin/bash

# ============================================================
# 小智 ESP32 服务器停止脚本
# ============================================================

# 项目根目录
PROJECT_DIR="$HOME/projects/xiaozhi-esp32-server-java"

# PID 文件目录
PID_DIR="$PROJECT_DIR/pids"

# PID 文件
BACKEND_PID="$PID_DIR/backend.pid"
FRONTEND_PID="$PID_DIR/frontend.pid"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================
# 停止服务
# ============================================================
stop_service() {
    local pid_file=$1
    local service_name=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}正在停止 $service_name (PID: $pid)...${NC}"
            kill "$pid" 2>/dev/null
            sleep 2
            
            # 如果还在运行，强制杀掉
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null
            fi
            
            echo -e "${GREEN}$service_name 已停止${NC}"
        else
            echo -e "${YELLOW}$service_name 未运行${NC}"
        fi
        rm -f "$pid_file"
    else
        echo -e "${YELLOW}$service_name PID 文件不存在${NC}"
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo ""
    echo "============================================"
    echo "  小智 ESP32 服务器停止脚本"
    echo "============================================"
    echo ""
    
    stop_service "$BACKEND_PID" "后端"
    stop_service "$FRONTEND_PID" "前端"
    
    echo ""
    echo -e "${GREEN}所有服务已停止${NC}"
    echo ""
}

main

