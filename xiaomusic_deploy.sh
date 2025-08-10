#!/bin/bash

# xiaomusic OpenWrt Docker 部署脚本
# 基于您现有的SSH密钥设置框架

OPENWRT_IP="192.168.31.2"
OPENWRT_USER="root"
CONTAINER_NAME="xiaomusic"
IMAGE_NAME="hanxi/xiaomusic"
# 国内镜像源（如果需要）
IMAGE_NAME_CN="docker.hanxi.cc/hanxi/xiaomusic"
WEB_PORT="58090"
CONTAINER_PORT="8090"

echo "=================================="
echo "🎵 xiaomusic OpenWrt Docker 部署"
echo "=================================="
echo "目标: ${OPENWRT_USER}@${OPENWRT_IP}"
echo "容器: ${CONTAINER_NAME}"
echo "端口: ${WEB_PORT}:${CONTAINER_PORT}"
echo "=================================="

# 检查SSH连接
echo "🔍 检查SSH连接..."
if ! ssh -o ConnectTimeout=5 ${OPENWRT_USER}@${OPENWRT_IP} "echo 'SSH连接正常'" 2>/dev/null; then
    echo "❌ SSH连接失败，请确保："
    echo "   1. OpenWrt设备已启动并连接网络"
    echo "   2. IP地址 ${OPENWRT_IP} 正确"
    echo "   3. 已运行 ./setup-ssh-key.sh 配置免密登录"
    exit 1
fi

echo "✅ SSH连接成功"

# 检查Docker是否安装
echo "🐳 检查Docker环境..."
if ! ssh ${OPENWRT_USER}@${OPENWRT_IP} "which docker" >/dev/null 2>&1; then
    echo "❌ Docker未安装，正在安装..."
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'EOF'
# 更新包列表
opkg update

# 安装Docker
opkg install docker dockerd docker-compose

# 启动Docker服务
/etc/init.d/dockerd enable
/etc/init.d/dockerd start

# 等待Docker启动
sleep 10
EOF
    
    if ! ssh ${OPENWRT_USER}@${OPENWRT_IP} "docker --version" >/dev/null 2>&1; then
        echo "❌ Docker安装失败"
        exit 1
    fi
fi

echo "✅ Docker环境检查完成"

# 创建必要的目录和配置
echo "📁 创建目录结构..."
ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
# 创建数据目录
mkdir -p /opt/xiaomusic/{music,conf}

# 设置权限
chmod 755 /opt/xiaomusic
chmod 755 /opt/xiaomusic/music
chmod 755 /opt/xiaomusic/conf

echo "✅ 目录创建完成："
echo "   音乐目录: /opt/xiaomusic/music"
echo "   配置目录: /opt/xiaomusic/conf"
EOF

# 检查是否已有运行的容器
echo "🔍 检查现有容器..."
if ssh ${OPENWRT_USER}@${OPENWRT_IP} "docker ps -a | grep ${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "⚠️  发现现有容器，正在停止并删除..."
    ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true
EOF
fi

# 拉取Docker镜像
echo "📥 拉取Docker镜像..."
echo "💡 提示: 如果拉取速度慢，将自动切换到国内镜像源"

ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
# 尝试拉取官方镜像
if ! timeout 60 docker pull ${IMAGE_NAME}; then
    echo "⚠️  官方镜像拉取失败，尝试国内镜像源..."
    docker pull ${IMAGE_NAME_CN}
    docker tag ${IMAGE_NAME_CN} ${IMAGE_NAME}
fi
EOF

if [ $? -ne 0 ]; then
    echo "❌ Docker镜像拉取失败"
    exit 1
fi

echo "✅ Docker镜像拉取成功"

# 创建并启动容器
echo "🚀 创建并启动容器..."
ssh ${OPENWRT_USER}@${OPENWRT_IP} << EOF
docker run -d \\
    --name ${CONTAINER_NAME} \\
    --restart unless-stopped \\
    -p ${WEB_PORT}:${CONTAINER_PORT} \\
    -e XIAOMUSIC_PUBLIC_PORT=${WEB_PORT} \\
    -v /opt/xiaomusic/music:/app/music \\
    -v /opt/xiaomusic/conf:/app/conf \\
    ${IMAGE_NAME}
EOF

if [ $? -ne 0 ]; then
    echo "❌ 容器启动失败"
    exit 1
fi

# 等待容器启动
echo "⏳ 等待容器启动..."
sleep 10

# 检查容器状态
echo "🔍 检查容器状态..."
if ssh ${OPENWRT_USER}@${OPENWRT_IP} "docker ps | grep ${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "✅ 容器启动成功！"
else
    echo "❌ 容器启动失败，查看日志："
    ssh ${OPENWRT_USER}@${OPENWRT_IP} "docker logs ${CONTAINER_NAME}"
    exit 1
fi

# 显示部署信息
echo ""
echo "🎉 xiaomusic 部署成功！"
echo "=================================="
echo "📱 Web控制台: http://${OPENWRT_IP}:${WEB_PORT}"
echo "🎵 音乐目录: /opt/xiaomusic/music"
echo "⚙️  配置目录: /opt/xiaomusic/conf"
echo "🐳 容器名称: ${CONTAINER_NAME}"
echo "=================================="
echo ""
echo "📋 使用说明："
echo "1. 打开 http://${OPENWRT_IP}:${WEB_PORT} 进行初始配置"
echo "2. 输入小米账号和密码获取设备列表"
echo "3. 配置完成后即可通过小爱音箱语音控制播放音乐"
echo ""
echo "🎵 语音指令示例："
echo "   - '播放歌曲周杰伦晴天'"
echo "   - '上一首' / '下一首'"
echo "   - '单曲循环' / '随机播放'"
echo "   - '停止播放'"
echo ""
echo "📁 管理音乐文件："
echo "   scp 音乐文件.mp3 ${OPENWRT_USER}@${OPENWRT_IP}:/opt/xiaomusic/music/"
echo ""
echo "🔧 管理容器："
echo "   查看日志: ssh ${OPENWRT_USER}@${OPENWRT_IP} 'docker logs ${CONTAINER_NAME}'"
echo "   重启容器: ssh ${OPENWRT_USER}@${OPENWRT_IP} 'docker restart ${CONTAINER_NAME}'"
echo "   停止容器: ssh ${OPENWRT_USER}@${OPENWRT_IP} 'docker stop ${CONTAINER_NAME}'"

# 可选：创建docker-compose文件
echo ""
echo "📝 创建docker-compose配置文件..."
ssh ${OPENWRT_USER}@${OPENWRT_IP} << 'EOF'
cat > /opt/xiaomusic/docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  xiaomusic:
    image: hanxi/xiaomusic
    container_name: xiaomusic
    restart: unless-stopped
    ports:
      - "58090:8090"
    environment:
      - XIAOMUSIC_PUBLIC_PORT=58090
    volumes:
      - /opt/xiaomusic/music:/app/music
      - /opt/xiaomusic/conf:/app/conf
COMPOSE_EOF

echo "✅ docker-compose.yml 已创建在 /opt/xiaomusic/docker-compose.yml"
EOF

echo ""
echo "💡 提示: 也可以使用docker-compose管理："
echo "   cd /opt/xiaomusic && docker-compose up -d"
echo ""
echo "🎯 下一步: 访问 http://${OPENWRT_IP}:${WEB_PORT} 开始配置！"