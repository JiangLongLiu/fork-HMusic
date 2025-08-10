#!/bin/bash

# xiaomusic 管理脚本
# 用于管理OpenWrt上的xiaomusic容器

OPENWRT_IP="192.168.31.2"
OPENWRT_USER="root"
CONTAINER_NAME="xiaomusic"
WEB_PORT="58090"

show_help() {
    echo "xiaomusic 管理脚本"
    echo "=================="
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  status      - 查看容器状态"
    echo "  logs        - 查看容器日志"
    echo "  restart     - 重启容器"
    echo "  stop        - 停止容器"
    echo "  start       - 启动容器"
    echo "  update      - 更新镜像并重启容器"
    echo "  config      - 打开配置页面"
    echo "  upload      - 上传音乐文件"
    echo "  backup      - 备份配置和音乐"
    echo "  restore     - 恢复配置和音乐"
    echo "  remove      - 完全删除容器和数据"
    echo "  info        - 显示详细信息"
    echo ""
    echo "示例:"
    echo "  $0 status           # 查看状态"
    echo "  $0 logs -f          # 实时查看日志"
    echo "  $0 upload song.mp3  # 上传音乐文件"
}

check_connection() {
    if ! ssh -o ConnectTimeout=5 ${OPENWRT_USER}@${OPENWRT_IP} "echo 'connected'" >/dev/null 2>&1; then
        echo "❌ 无法连接到 ${OPENWRT_IP}"
        echo "请检查网络连接和SSH配置"
        exit 1
    fi
}

container_status() {
    echo "🔍 检查容器状态..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'EOF'
if docker ps | grep xiaomusic >/dev/null; then
    echo "✅ 容器正在运행"
    docker ps | grep xiaomusic
elif docker ps -a | grep xiaomusic >/dev/null; then
    echo "⚠️  容器已停止"
    docker ps -a | grep xiaomusic
else
    echo "❌ 容器不存在"
fi
EOF
}

container_logs() {
    echo "📄 查看容器日志..."
    check_connection
    
    local args="$@"
    ssh ${OPENWRT_USER}@${OPENWRT_IP} "docker logs ${args} ${CONTAINER_NAME}"
}

container_restart() {
    echo "🔄 重启容器..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
docker restart ${CONTAINER_NAME}
if [ \$? -eq 0 ]; then
    echo "✅ 容器重启成功"
    sleep 3
    docker ps | grep ${CONTAINER_NAME}
else
    echo "❌ 容器重启失败"
fi
EOF
}

container_stop() {
    echo "⏹️  停止容器..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
docker stop ${CONTAINER_NAME}
if [ \$? -eq 0 ]; then
    echo "✅ 容器已停止"
else
    echo "❌ 停止容器失败"
fi
EOF
}

container_start() {
    echo "▶️  启动容器..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
docker start ${CONTAINER_NAME}
if [ \$? -eq 0 ]; then
    echo "✅ 容器已启动"
    sleep 3
    docker ps | grep ${CONTAINER_NAME}
else
    echo "❌ 启动容器失败"
fi
EOF
}

container_update() {
    echo "🔄 更新镜像..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'EOF'
echo "📥 拉取最新镜像..."
docker pull hanxi/xiaomusic

echo "⏹️  停止当前容器..."
docker stop xiaomusic

echo "🗑️  删除旧容器..."
docker rm xiaomusic

echo "🚀 创建新容器..."
docker run -d \
    --name xiaomusic \
    --restart unless-stopped \
    -p 58090:8090 \
    -e XIAOMUSIC_PUBLIC_PORT=58090 \
    -v /opt/xiaomusic/music:/app/music \
    -v /opt/xiaomusic/conf:/app/conf \
    hanxi/xiaomusic

if [ $? -eq 0 ]; then
    echo "✅ 更新完成"
    sleep 3
    docker ps | grep xiaomusic
else
    echo "❌ 更新失败"
fi
EOF
}

open_config() {
    echo "🌐 打开配置页面..."
    echo "配置地址: http://${OPENWRT_IP}:${WEB_PORT}"
    
    # 尝试在不同系统中打开浏览器
    if command -v xdg-open >/dev/null; then
        xdg-open "http://${OPENWRT_IP}:${WEB_PORT}"
    elif command -v open >/dev/null; then
        open "http://${OPENWRT_IP}:${WEB_PORT}"
    elif command -v start >/dev/null; then
        start "http://${OPENWRT_IP}:${WEB_PORT}"
    else
        echo "请手动在浏览器中打开上述地址"
    fi
}

upload_music() {
    if [ -z "$2" ]; then
        echo "❌ 请指定要上传的音乐文件"
        echo "用法: $0 upload <音乐文件>"
        return 1
    fi
    
    local music_file="$2"
    
    if [ ! -f "$music_file" ]; then
        echo "❌ 文件不存在: $music_file"
        return 1
    fi
    
    echo "📤 上传音乐文件: $music_file"
    scp "$music_file" ${OPENWRT_USER}@${OPENWRT_IP}:/opt/xiaomusic/music/
    
    if [ $? -eq 0 ]; then
        echo "✅ 文件上传成功"
        echo "💡 提示: 对小爱音箱说'刷新列表'来识别新歌曲"
    else
        echo "❌ 文件上传失败"
    fi
}

backup_data() {
    echo "📦 备份配置和音乐数据..."
    local backup_name="xiaomusic_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
cd /opt
tar -czf ${backup_name} xiaomusic/
echo "✅ 备份完成: /opt/${backup_name}"
ls -lh /opt/${backup_name}
EOF
    
    echo "📥 下载备份文件到本地..."
    scp ${OPENWRT_USER}@${OPENWRT_IP}:/opt/${backup_name} ./
    
    if [ $? -eq 0 ]; then
        echo "✅ 备份已下载到: ./${backup_name}"
    fi
}

restore_data() {
    if [ -z "$2" ]; then
        echo "❌ 请指定备份文件"
        echo "用法: $0 restore <备份文件.tar.gz>"
        return 1
    fi
    
    local backup_file="$2"
    
    if [ ! -f "$backup_file" ]; then
        echo "❌ 备份文件不存在: $backup_file"
        return 1
    fi
    
    echo "📤 上传备份文件..."
    scp "$backup_file" ${OPENWRT_USER}@${OPENWRT_IP}:/tmp/
    
    echo "🔄 停止容器..."
    ssh ${OPENWRT_USER}@${OPENWRT_IP} "docker stop ${CONTAINER_NAME}"
    
    echo "📦 恢复数据..."
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
cd /opt
rm -rf xiaomusic
tar -xzf /tmp/$(basename $backup_file)
echo "✅ 数据恢复完成"
EOF
    
    echo "▶️  启动容器..."
    ssh ${OPENWRT_USER}@${OPENWRT_IP} "docker start ${CONTAINER_NAME}"
    
    echo "✅ 恢复完成"
}

remove_all() {
    echo "⚠️  这将完全删除xiaomusic容器和所有数据"
    read -p "确认删除吗？(y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "操作已取消"
        return 0
    fi
    
    echo "🗑️  删除容器和数据..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'EOF'
# 停止并删除容器
docker stop xiaomusic 2>/dev/null || true
docker rm xiaomusic 2>/dev/null || true

# 删除镜像
docker rmi hanxi/xiaomusic 2>/dev/null || true

# 删除数据目录
rm -rf /opt/xiaomusic

echo "✅ 删除完成"
EOF
}

show_info() {
    echo "ℹ️  xiaomusic 详细信息"
    echo "======================"
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'EOF'
echo "🐳 Docker版本:"
docker --version

echo ""
echo "📦 容器信息:"
if docker ps -a | grep xiaomusic >/dev/null; then
    docker ps -a | grep xiaomusic
    echo ""
    echo "🖼️  镜像信息:"
    docker images | grep xiaomusic
    echo ""
    echo "📊 容器资源使用:"
    docker stats --no-stream xiaomusic 2>/dev/null || echo "容器未运行"
else
    echo "容器不存在"
fi

echo ""
echo "📁 数据目录:"
if [ -d /opt/xiaomusic ]; then
    du -sh /opt/xiaomusic/*
    echo ""
    echo "🎵 音乐文件数量:"
    find /opt/xiaomusic/music -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.wav" -o -name "*.ape" -o -name "*.ogg" -o -name "*.m4a" \) | wc -l
else
    echo "数据目录不存在"
fi

echo ""
echo "🌐 访问地址: http://$(hostname -I | awk '{print $1}'):58090"
EOF
}

# 主逻辑
case "$1" in
    "status")
        container_status
        ;;
    "logs")
        shift
        container_logs "$@"
        ;;
    "restart")
        container_restart
        ;;
    "stop")
        container_stop
        ;;
    "start")
        container_start
        ;;
    "update")
        container_update
        ;;
    "config")
        open_config
        ;;
    "upload")
        upload_music "$@"
        ;;
    "backup")
        backup_data
        ;;
    "restore")
        restore_data "$@"  
        ;;
    "remove")
        remove_all
        ;;
    "info")
        show_info
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        echo "❌ 未知命令: $1"
        echo ""
        show_help
        exit 1
        ;;
esac