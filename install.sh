#!/bin/bash

# 开启严格模式：任何一步失败，脚本立即停止
set -e

echo "======================================"
echo "🚀 Cloudflared 一键部署（小白可读版）"
echo "💡 特点：有进度 / 有注释 / 不会假死 / 可排错"
echo "======================================"

# ==============================
# [1] 安装 cloudflared
# ==============================

echo ""
echo "[1/4] 正在安装 cloudflared..."

# 👉 判断 VPS CPU 架构（不同机器下载不同版本）
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

# 👉 告诉用户正在下载什么
echo "📥 下载 cloudflared: $FILE"
echo "🌐 来源: GitHub Releases"

# 👉 下载（带进度条 + 超时，避免卡死）
curl -L --progress-bar \
--connect-timeout 10 \
--max-time 60 \
-o cloudflared \
https://github.com/cloudflare/cloudflared/releases/latest/download/${FILE}

# 👉 下载完成提示
echo "📦 下载完成"

# 👉 添加执行权限（允许运行）
chmod +x cloudflared

# 👉 移动到系统路径（全局可用）
mv cloudflared /usr/local/bin/cloudflared

echo "✅ cloudflared 安装完成"


# ==============================
# [2] 输入用户配置
# ==============================

echo ""
echo "[2/4] 请输入你的配置信息"

# 👉 Token（Cloudflare 给你的隧道密钥）
read -p "🔑 请输入 Tunnel Token: " TOKEN

# 👉 本地服务端口（Komari / 面板 / xray）
read -p "⚙️ 请输入本地端口 (例如 8000): " PORT

# 👉 域名（Cloudflare 已配置的 hostname）
read -p "🌐 请输入域名 (例如 komari.example.com): " HOSTNAME

echo ""
echo "📌 你的配置如下："
echo "👉 端口: $PORT"
echo "👉 域名: $HOSTNAME"
echo "👉 Token: 已隐藏（安全）"


# ==============================
# [3] 创建 systemd 服务
# ==============================

echo ""
echo "[3/4] 创建系统服务（开机自启 + 掉线自动重启）"

# 👉 写入 systemd 服务文件
cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
# 服务名称说明
Description=Cloudflare Tunnel Service

# 网络起来后再启动服务（避免网络未就绪）
After=network-online.target
Wants=network-online.target

[Service]
# 普通进程方式运行
Type=simple

# 👉 核心启动命令（使用 Token 模式）
ExecStart=/usr/local/bin/cloudflared tunnel run --token ${TOKEN}

# 👉 崩溃自动重启
Restart=always

# 👉 重启间隔 5 秒（避免疯狂重启）
RestartSec=5s

# 👉 提高文件句柄限制（稳定长连接）
LimitNOFILE=1048576

[Install]
# 开机自动启动
WantedBy=multi-user.target
EOF

echo "✅ systemd 服务创建完成"

# 👉 让 systemd 重新加载配置
systemctl daemon-reexec

# 👉 设置开机自启
systemctl enable cloudflared


# ==============================
# [4] 启动服务
# ==============================

echo ""
echo "[4/4] 启动 cloudflared..."

# 👉 启动服务
systemctl restart cloudflared

echo "======================================"
echo "🎉 部署完成！"
echo ""

echo "📌 你还需要在 Cloudflare 面板做这一步："
echo ""
echo "1️⃣ 进入 Cloudflare Dashboard"
echo "2️⃣ Tunnel → Public Hostname → Add"
echo "3️⃣ 填写："
echo "   Hostname → $HOSTNAME"
echo "   Service  → http://127.0.0.1:$PORT"
echo ""

echo "📌 常用命令："
echo "👉 查看状态: systemctl status cloudflared"
echo "👉 查看日志: journalctl -u cloudflared -f"
echo "👉 重启服务: systemctl restart cloudflared"

echo "======================================"
