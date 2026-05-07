# easy-cloudflared
Cloudflared Tunnel 交互式一键脚本（Token版）  
无脑快速搭建安全隧道，无需公网端口，适合：NAT VPS / 无公网IP / 反代服务    
适用于Debian / Ubuntu  等标准 systemd Linux  
交互式输入 Token / 本地端口 / 域名   
自动生成 systemd 服务，守护 Cloudflared，开机自启  
覆盖安装 / 卸载 / 重新部署 功能   
支持多架构（x86_64 / ARM64）  
小白可直接使用，一键完成部署  
```bash
bash <(curl -fSL https://raw.githubusercontent.com/nngt886/easy-cloudflared/refs/heads/main/install.sh)
