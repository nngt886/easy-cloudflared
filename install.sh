#!/bin/bash

set -e

echo "======================================"
echo "🚀 Cloudflared Tunnel 交互式一键部署"
echo "💡 每次运行可输入不同 Token / 域名 / 端口"
echo "======================================"

# =========================
# 1. 安装 cloudflared
# =========================

echo ""
echo "[1/4] 安装 cloudflared..."

ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    FILE="cloudflared-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    FILE="cloudflared-linux-arm64"
else
    echo "❌ 不支持架构: $ARCH"
    exit 1
fi

wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/${FILE}
chmod +x ${FILE}
mv ${FILE} /usr/local/bin/cloudflared

echo "✅ 安装完成"


# =========================
# 2. 交互输入（核心）
# =========================

echo ""
echo "[2/4] 请输入配置信息"

# 👉 Token（Cloudflare Dashboard 复制）
read -p "🔑 请输入 Tunnel Token: " TOKEN

# 👉 本地服务端口（Komari / 面板 / xray）
read -p "⚙️ 请输入本地端口 (例如 8000): " PORT

# 👉 域名（Cloudflare 已配置 hostname）
read -p "🌐 请输入域名 (例如 komari.example.com): " HOSTNAME


echo ""
echo "📌 配置确认："
echo "TOKEN: 已输入"
echo "PORT: $PORT"
echo "HOSTNAME: $HOSTNAME"


# =========================
# 3. systemd 服务
# =========================

echo ""
echo "[3/4] 创建 systemd 服务..."

cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

ExecStart=/usr/local/bin/cloudflared tunnel run --token ${TOKEN}

Restart=always
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable cloudflared


# =========================
# 4. 启动服务
# =========================

echo ""
echo "[4/4] 启动 cloudflared..."

systemctl restart cloudflared


# =========================
# 提示
# =========================

echo ""
echo "======================================"
echo "🎉 部署完成！"
echo ""
echo "⚠️ 你还需要在 Cloudflare 面板配置："
echo ""
echo "Tunnel → Public Hostname → Add"
echo "Hostname: $HOSTNAME"
echo "Service: http://127.0.0.1:$PORT"
echo ""
echo "📌 查看状态：systemctl status cloudflared"
echo "📌 查看日志：journalctl -u cloudflared -f"
echo "======================================"
