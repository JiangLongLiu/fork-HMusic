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
    if command -v xdg-open >/dev/null; then
        xdg-open "http://${OPENWRT_IP}:58090" 2>/dev/null &
    elif command -v open >/dev/null; then
        open "http://${OPENWRT_IP}:58090" 2>/dev/null &
    fi
    
else
    echo "❌ 部署失败"
    echo "请查看上面的错误信息并重试"
fi