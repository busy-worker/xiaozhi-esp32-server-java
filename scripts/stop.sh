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
# 停止后端服务
# ============================================================
stop_backend() {
    echo -e "${YELLOW}正在停止后端服务...${NC}"
    
    # 方法1: 通过 PID 文件停止
    if [ -f "$BACKEND_PID" ]; then
        local pid=$(cat "$BACKEND_PID")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "  通过 PID 文件停止 (PID: $pid)"
            kill "$pid" 2>/dev/null
            sleep 2
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null
            fi
        fi
        rm -f "$BACKEND_PID"
    fi
    
    # 方法2: 通过进程名查找并停止（备用方案）
    local pids=$(pgrep -f "xiaozhi.server.*\.jar" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "  发现残留进程，正在清理: $pids"
        for pid in $pids; do
            kill "$pid" 2>/dev/null
        done
        sleep 2
        # 强制杀掉还在运行的
        pids=$(pgrep -f "xiaozhi.server.*\.jar" 2>/dev/null)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                kill -9 "$pid" 2>/dev/null
            done
        fi
    fi
    
    # 最终确认
    if pgrep -f "xiaozhi.server.*\.jar" > /dev/null 2>&1; then
        echo -e "${RED}警告: 仍有后端进程在运行！${NC}"
        pgrep -af "xiaozhi.server.*\.jar"
    else
        echo -e "${GREEN}后端服务已停止${NC}"
    fi
}

# ============================================================
# 停止前端服务
# ============================================================
stop_frontend() {
    echo -e "${YELLOW}正在停止前端服务...${NC}"
    
    # 方法1: 通过 PID 文件停止
    if [ -f "$FRONTEND_PID" ]; then
        local pid=$(cat "$FRONTEND_PID")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "  通过 PID 文件停止 (PID: $pid)"
            kill "$pid" 2>/dev/null
            sleep 1
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null
            fi
        fi
        rm -f "$FRONTEND_PID"
    fi
    
    # 方法2: 通过进程名查找并停止（备用方案）
    local pids=$(pgrep -f "vite.*--host" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "  发现残留进程，正在清理: $pids"
        for pid in $pids; do
            kill "$pid" 2>/dev/null
        done
        sleep 1
    fi
    
    echo -e "${GREEN}前端服务已停止${NC}"
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
    
    stop_backend
    stop_frontend
    
    echo ""
    echo -e "${GREEN}所有服务已停止${NC}"
    echo ""
}

main
