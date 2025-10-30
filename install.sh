#!/bin/bash
# =====================================================
# Hysteria2 对接 XBoard 自动安装脚本（自签证书版）
# 版本：2025-10-30
# 作者：Nuro-Hia 项目专用
# 功能：
#   ✅ 自动生成自签证书（有效期 10 年）
#   ✅ 自动随机端口（20000–60000）
#   ✅ 自动生成配置 + 注册 systemd 服务
#   ✅ 无 Docker，纯二进制运行
#   ✅ 自动输出客户端配置
# =====================================================

set -e
HY_DIR="/etc/hysteria"
HY_BIN="/usr/local/bin/hysteria"
HY_CONF="${HY_DIR}/server.yaml"
HY_SERVICE="/etc/systemd/system/hysteria.service"

# ---------- 函数 ----------
pause() { echo ""; read -rp "按回车返回菜单..." _; menu; }

header() {
  clear
  echo "=============================="
  echo " Hysteria2 对接 XBoard 管理脚本"
  echo "=============================="
  echo "1 安装并启动 Hysteria2"
  echo "2 查看运行状态"
  echo "3 查看运行日志"
  echo "4 停止服务"
  echo "5 卸载 Hysteria2"
  echo "6 退出"
  echo "=============================="
}

# ---------- 自动随机端口 ----------
random_port() {
  while true; do
    PORT=$(( (RANDOM % 40000) + 20000 ))
    if ! ss -tuln | grep -q ":$PORT "; then
      echo "$PORT"
      return
    fi
  done
}

# ---------- 安装依赖 ----------
install_deps() {
  echo "🧩 检查依赖..."
  apt update -y >/dev/null 2>&1
  apt install -y curl wget openssl >/dev/null 2>&1
}

# ---------- 安装 hysteria2 ----------
install_hy2() {
  install_deps
  mkdir -p "$HY_DIR"

  echo ""
  read -rp "🌐 面板地址(XBoard): " API_HOST
  read -rp "🔑 通讯密钥(apiKey): " API_KEY
  read -rp "🆔 节点 ID(nodeID): " NODE_ID
  read -rp "🏷️ 节点域名(证书 CN): " DOMAIN
  PORT=$(random_port)
  echo "📡 自动检测可用端口: ${PORT}"

  echo "⬇️ 下载 Hysteria2 二进制..."
  wget -qO "$HY_BIN" https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
  chmod +x "$HY_BIN"

  echo "📜 生成自签证书..."
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "${HY_DIR}/tls.key" -out "${HY_DIR}/tls.crt" \
    -subj "/CN=${DOMAIN}" >/dev/null 2>&1
  echo "✅ 证书生成成功：${HY_DIR}/tls.crt"

  echo "⚙️ 生成配置文件：${HY_CONF}"
  cat >"$HY_CONF" <<EOF
listen: :${PORT}
acme:
  disabled: true
tls:
  cert: ${HY_DIR}/tls.crt
  key: ${HY_DIR}/tls.key
auth:
  mode: api
  api:
    url: ${API_HOST}/api/v1/server/UniProxy
    key: "${API_KEY}"
    node: ${NODE_ID}
EOF

  echo "🔧 注册 systemd 服务..."
  cat >"$HY_SERVICE" <<EOF
[Unit]
Description=Hysteria2 Service
After=network.target

[Service]
ExecStart=${HY_BIN} server -c ${HY_CONF}
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now hysteria >/dev/null 2>&1

  echo ""
  echo "✅ Hysteria2 已安装并启动"
  echo "--------------------------------------"
  echo "🌐 面板地址: ${API_HOST}"
  echo "🔑 通讯密钥: ${API_KEY}"
  echo "🆔 节点 ID: ${NODE_ID}"
  echo "🏷️ 域名: ${DOMAIN}"
  echo "📡 实际监听端口: ${PORT}"
  echo "📜 配置文件路径: ${HY_CONF}"
  echo "🐧 服务名: hysteria"
  echo "--------------------------------------"
  echo "💡 客户端配置示例："
  echo "--------------------------------------"
  cat <<CLIENT
server: ${DOMAIN}:${PORT}
auth: ${API_KEY}
tls:
  insecure: true
  sni: ${DOMAIN}
CLIENT
  echo "--------------------------------------"
  pause
}

# ---------- 查看状态 ----------
status_hy2() {
  systemctl status hysteria --no-pager
  pause
}

# ---------- 查看日志 ----------
logs_hy2() {
  journalctl -u hysteria -e --no-pager
  pause
}

# ---------- 停止服务 ----------
stop_hy2() {
  systemctl stop hysteria
  echo "🛑 已停止 Hysteria2 服务"
  pause
}

# ---------- 卸载 ----------
uninstall_hy2() {
  echo "⚠️ 确认卸载 Hysteria2？(y/n)"
  read -r c
  [[ $c =~ ^[Yy]$ ]] || { pause; return; }

  systemctl stop hysteria 2>/dev/null || true
  systemctl disable hysteria 2>/dev/null || true
  rm -f "$HY_SERVICE"
  rm -rf "$HY_DIR" "$HY_BIN"

  echo "✅ 已彻底卸载 Hysteria2"
  pause
}

# ---------- 菜单 ----------
menu() {
  header
  read -rp "请选择操作: " opt
  case "$opt" in
    1) install_hy2 ;;
    2) status_hy2 ;;
    3) logs_hy2 ;;
    4) stop_hy2 ;;
    5) uninstall_hy2 ;;
    6) exit 0 ;;
    *) echo "❌ 无效选项"; sleep 1; menu ;;
  esac
}

menu
