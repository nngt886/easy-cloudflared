#!/bin/bash

# ======================================
# 🚀 Cloudflared Tunnel 一键部署脚本（终极稳定版）
# 💡 特点：
# - 多源下载（GitHub + CDN fallback）
# - 自动重试 + 防卡死
# - 小白注释
# - 交互输入 Token / 端口 / 域名
# - systemd 守护 + 开机自启
# ======================================

set -e

echo "======================================"
echo "🚀 Cloudflared Tunnel 一键部署（稳定终极版）"
echo "======================================"

# ======================================
# [1] 下载并安装 cloudflared
# ======================================

echo ""
echo "[1/4] 安装 cloudflared..."

ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    FILE="cloudflared-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    FILE="cloudflared-linux-arm64"
else
    echo "❌ 不支持的架构: $ARCH"
    exit 1
fi

echo "📦 目标文件: $FILE"

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

# 👉 多源下载（防止 GitHub 卡死）
if ! download_file "https://github.com/cloudflare/cloudflared/releases/latest/download/${FILE}"; then
    echo "⚠️ GitHub 失败，尝试 CDN 源..."

    if ! download_file "https://cloudflared.b-cdn.net/${FILE}"; then
        echo "❌ 所有下载源失败，请检查网络"
        exit 1
    fi
fi

echo "📦 下载完成"

chmod +x cloudflared
mv cloudflared /usr/local/bin/cloudflared

echo "✅ cloudflared 安装成功"


# ======================================
# [2] 用户输入配置
# ======================================

echo ""
echo "[2/4] 请输入配置"

read -p "🔑 请输入 Tunnel Token: " TOKEN
read -p "⚙️ 请输入本地端口 (例如 8000): " PORT
read -p "🌐 请输入域名 (例如 komari.example.com): " HOSTNAME

echo ""
echo "📌 配置确认："
echo "👉 端口: $PORT"
echo "👉 域名: $HOSTNAME"
echo "👉 Token: 已隐藏"


# ======================================
# [3] systemd 服务
# ======================================

echo ""
echo "[3/4] 创建 systemd 服务..."

cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

# 👉 Tunnel 启动命令
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

echo ""
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
