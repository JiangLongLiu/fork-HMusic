# 创建 quick-deploy-xiaomusic.sh
cat > quick-deploy-xiaomusic.sh << 'EOF'
#!/bin/bash

# xiaomusic 一键部署脚本
# 适配您现有的setup-ssh-key.sh脚本风格

OPENWRT_IP="192.168.31.2"
OPENWRT_USER="root"

echo "🎵================================🎵"
echo "    xiaomusic 一键部署脚本"
echo "🎵================================🎵"
echo "目标设备: ${OPENWRT_USER}@${OPENWRT_IP}"
echo "项目地址: https://github.com/hanxi/xiaomusic"
echo "=================================="

# 检查SSH连接
echo "🔍 检查SSH连接..."
if ! ssh -o ConnectTimeout=5 ${OPENWRT_USER}@${OPENWRT_IP} "echo '连接成功'" 2>/dev/null; then
    echo "❌ SSH连接失败"
    echo "💡 请先运行 ./setup-ssh-key.sh 配置免密登录"
    exit 1
fi

echo "✅ SSH连接正常"

# 一键部署
echo "🚀 开始一键部署..."
ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'DEPLOY_SCRIPT'
#!/bin/bash

echo "📦 检查Docker环境..."
if ! which docker >/dev/null 2>&1; then
    echo "🔧 安装Docker..."
    opkg update
    opkg install docker dockerd docker-compose
    /etc/init.d/dockerd enable
    /etc/init.d/dockerd start
    sleep 10
fi

echo "📁 创建目录..."
mkdir -p /opt/xiaomusic/{music,conf}

echo "🛑 清理旧容器..."
docker stop xiaomusic 2>/dev/null || true
docker rm xiaomusic 2>/dev/null || true

echo "📥 拉取镜像..."
if ! timeout 60 docker pull hanxi/xiaomusic; then
    echo "🌏 尝试国内镜像源..."
    docker pull docker.hanxi.cc/hanxi/xiaomusic
    docker tag docker.hanxi.cc/hanxi/xiaomusic hanxi/xiaomusic
fi

echo "🚀 启动容器..."
docker run -d \
    --name xiaomusic \
    --restart unless-stopped \
    -p 58090:8090 \
    -e XIAOMUSIC_PUBLIC_PORT=58090 \
    -v /opt/xiaomusic/music:/app/music \
    -v /opt/xiaomusic/conf:/app/conf \
    hanxi/xiaomusic

# 等待启动
sleep 5

if docker ps | grep xiaomusic >/dev/null; then
    echo "✅ 部署成功！"
else
    echo "❌ 部署失败，查看日志："
    docker logs xiaomusic
    exit 1
fi
DEPLOY_SCRIPT

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 xiaomusic 部署完成！"
    echo "=================================="
    echo "🌐 Web界面: http://${OPENWRT_IP}:58090"
    echo "🎵 音乐目录: /opt/xiaomusic/music"
    echo "⚙️  配置目录: /opt/xiaomusic/conf"
    echo "=================================="
    echo ""
    echo "📋 下一步操作："
    echo "1. 访问 http://${OPENWRT_IP}:58090"
    echo "2. 输入小米账号密码进行配置"
    echo "3. 选择小爱音箱设备"
    echo "4. 开始享受语音点歌！"
    echo ""
    echo "🎵 常用语音指令："
    echo "   • 播放歌曲+歌名"
    echo "   • 上一首/下一首"
    echo "   • 单曲循环/随机播放"
    echo "   • 停止播放"
    echo ""
    echo "🔧 管理命令："
    echo "   ./xiaomusic-manager.sh status   # 查看状态"
    echo "   ./xiaomusic-manager.sh logs     # 查看日志"
    echo "   ./xiaomusic-manager.sh upload   # 上传音乐"
    
    # 自动打开配置页面（可选）
    echo ""
    echo "🌐 正在尝试打开配置页面..."
    if command -v open >/dev/null; then
        open "http://${OPENWRT_IP}:58090" 2>/dev/null &
    fi
    
else
    echo "❌ 部署失败"
    echo "请查看上面的错误信息并重试"
fi
EOF

# 创建 xiaomusic-manager.sh
cat > xiaomusic-manager.sh << 'EOF'
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
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'SCRIPT_EOF'
if docker ps | grep xiaomusic >/dev/null; then
    echo "✅ 容器正在运行"
    docker ps | grep xiaomusic
elif docker ps -a | grep xiaomusic >/dev/null; then
    echo "⚠️  容器已停止"
    docker ps -a | grep xiaomusic
else
    echo "❌ 容器不存在"
fi
SCRIPT_EOF
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
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << SCRIPT_EOF
docker restart ${CONTAINER_NAME}
if [ \$? -eq 0 ]; then
    echo "✅ 容器重启成功"
    sleep 3
    docker ps | grep ${CONTAINER_NAME}
else
    echo "❌ 容器重启失败"
fi
SCRIPT_EOF
}

container_stop() {
    echo "⏹️  停止容器..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << SCRIPT_EOF
docker stop ${CONTAINER_NAME}
if [ \$? -eq 0 ]; then
    echo "✅ 容器已停止"
else
    echo "❌ 停止容器失败"
fi
SCRIPT_EOF
}

container_start() {
    echo "▶️  启动容器..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << SCRIPT_EOF
docker start ${CONTAINER_NAME}
if [ \$? -eq 0 ]; then
    echo "✅ 容器已启动"
    sleep 3
    docker ps | grep ${CONTAINER_NAME}
else
    echo "❌ 启动容器失败"
fi
SCRIPT_EOF
}

container_update() {
    echo "🔄 更新镜像..."
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'SCRIPT_EOF'
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
SCRIPT_EOF
}

open_config() {
    echo "🌐 打开配置页面..."
    echo "配置地址: http://${OPENWRT_IP}:${WEB_PORT}"
    
    # 尝试在不同系统中打开浏览器
    if command -v open >/dev/null; then
        open "http://${OPENWRT_IP}:${WEB_PORT}"
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
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << SCRIPT_EOF
cd /opt
tar -czf ${backup_name} xiaomusic/
echo "✅ 备份完成: /opt/${backup_name}"
ls -lh /opt/${backup_name}
SCRIPT_EOF
    
    echo "📥 下载备份文件到本地..."
    scp ${OPENWRT_USER}@${OPENWRT_IP}:/opt/${backup_name} ./
    
    if [ $? -eq 0 ]; then
        echo "✅ 备份已下载到: ./${backup_name}"
    fi
}

show_info() {
    echo "ℹ️  xiaomusic 详细信息"
    echo "======================"
    check_connection
    
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'SCRIPT_EOF'
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
    du -sh /opt/xiaomusic/* 2>/dev/null || echo "目录为空"
    echo ""
    echo "🎵 音乐文件数量:"
    find /opt/xiaomusic/music -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.wav" -o -name "*.ape" -o -name "*.ogg" -o -name "*.m4a" \) 2>/dev/null | wc -l
else
    echo "数据目录不存在"
fi

echo ""
echo "🌐 访问地址: http://$(hostname -I | awk '{print $1}'):58090"
SCRIPT_EOF
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
EOF

# 设置执行权限
chmod +x quick-deploy-xiaomusic.sh
chmod +x xiaomusic-manager.sh

echo "✅ 脚本创建完成！"
echo ""
echo "📁 已创建的文件："
echo "  quick-deploy-xiaomusic.sh  - 一键部署脚本"
echo "  xiaomusic-manager.sh       - 管理脚本"
echo ""
echo "🚀 现在可以运行："
echo "  ./quick-deploy-xiaomusic.sh"