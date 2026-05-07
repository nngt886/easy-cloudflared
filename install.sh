#!/bin/bash

# ======================================
# 🚀 Cloudflared 一键部署脚本
# 💡 特点：
# - 多源下载（GitHub + CDN fallback）
# - 自动重试 + 防卡死
# - 交互输入 Token / 端口 / 域名
# - systemd 守护 + 开机自启
# ======================================

set -e

echo "======================================"
echo "🚀 Cloudflared Tunnel 一键部署）"
echo "======================================"

# 👉 检测是否已安装 cloudflared
if command -v cloudflared >/dev/null 2>&1; then
    echo ""
    echo "⚠️ 检测到已安装 cloudflared"

    VERSION=$(cloudflared --version 2>/dev/null || echo "未知版本")
    echo "📌 当前版本: $VERSION"

    echo ""
    echo "请选择操作："
    echo "1) 继续安装（覆盖）"
    echo "2) 卸载 cloudflared"
    echo "3) 退出"

    read -p "请输入选项: " ACTION

    if [[ "$ACTION" == "2" ]]; then
        echo ""
        echo "🧹 正在卸载 Cloudflared..."

# 停止服务
echo "⏳ 停止 Cloudflared 服务..."
systemctl stop cloudflared 2>/dev/null || true

# 禁用开机自启
echo "⏳ 禁用开机自启..."
systemctl disable cloudflared 2>/dev/null || true

# 删除二进制文件
if [ -f /usr/local/bin/cloudflared ]; then
    echo "⏳ 删除 Cloudflared 二进制文件..."
    rm -v /usr/local/bin/cloudflared
else
    echo "ℹ️ Cloudflared 二进制文件未找到"
fi

# 删除 systemd 服务文件
if [ -f /etc/systemd/system/cloudflared.service ]; then
    echo "⏳ 删除 systemd 服务文件..."
    rm -v /etc/systemd/system/cloudflared.service
else
    echo "ℹ️ systemd 服务文件未找到"
fi

# 重新加载 systemd
echo "⏳ 重新加载 systemd 配置..."
systemctl daemon-reexec

echo "✅ Cloudflared 卸载完成！"
        exit 0
    elif [[ "$ACTION" == "3" ]]; then
        echo "👋 已退出"
        exit 0
    else
        echo "🔄 继续执行安装流程..."
    fi
fi


# ======================================
# [1] 安装 cloudflared
# ======================================

echo ""
echo "[1/4] 正在安装 cloudflared..."

ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    # 普通 Intel / AMD 服务器
    FILE="cloudflared-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    # ARM 架构 VPS
    FILE="cloudflared-linux-arm64"
else
    echo "❌ 不支持的架构: $ARCH"
    exit 1
fi

echo "📦 目标文件: $FILE"

# 👉 多源下载（防止 GitHub 卡死）
download_file() {
    URL=$1
    echo "🌐 尝试下载: $URL"

    curl -L --retry 5 --retry-delay 2 \
    --connect-timeout 10 \
    --max-time 300 \
    --progress-bar \
    -o cloudflared \
    "$URL" && return 0

    return 1
}

# GitHub 下载
if ! download_file "https://github.com/cloudflare/cloudflared/releases/latest/download/${FILE}"; then
    echo "⚠️ GitHub 失败，尝试 CDN..."

    # CDN fallback
    if ! download_file "https://cloudflared.b-cdn.net/${FILE}"; then
        echo "❌ 所有下载源失败"
        exit 1
    fi
fi

echo "📦 下载完成"

chmod +x cloudflared
mv cloudflared /usr/local/bin/cloudflared

echo "✅ cloudflared 安装成功"


# ======================================
# [2] 输入用户配置
# ======================================

echo ""
echo "[2/4] 请输入你的配置信息"

# 👉 Token（Cloudflare 给你的隧道密钥）
read -p "🔑 请输入 Tunnel Token: " TOKEN

# 👉 本地服务端口（Komari / 面板 / xray）
read -p "⚙️ 请输入本地服务端口 (例如 8000): " PORT

# 👉 域名（Cloudflare 已配置的 hostname）
read -p "🌐 请输入域名 (例如 komari.example.com): " HOSTNAME

echo ""
echo "📌 你的配置如下："
echo "👉 端口: $PORT"
echo "👉 域名: $HOSTNAME"
echo "👉 Token: 已隐藏（安全）"


# ======================================
# [3] systemd 服务
# ======================================

echo ""
echo "[3/4] 创建系统服务..."

cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

# 👉 核心启动命令（TOKEN模式）
ExecStart=/usr/local/bin/cloudflared tunnel run --token ${TOKEN}

# 👉 自动重启（防断线）
Restart=always
RestartSec=5s

# 👉 提高连接稳定性
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable cloudflared

echo "✅ systemd 配置完成"


# ======================================
# [4] 启动服务
# ======================================

echo ""
echo "[4/4] 启动 cloudflared..."

systemctl restart cloudflared

echo "======================================"
echo "🎉 部署完成！"
echo ""
echo "📌 Cloudflare 面板还需配置："
echo "Tunnel → Public Hostname → Add"
echo "Hostname: $HOSTNAME"
echo "Service: http://127.0.0.1:$PORT"
echo ""
echo "📌 常用命令："
echo "👉 状态: systemctl status cloudflared"
echo "👉 日志: journalctl -u cloudflared -f"
echo "👉 重启: systemctl restart cloudflared"
echo "======================================"
