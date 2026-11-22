#!/usr/bin/env bash
# ハンズオン用 VM のセットアップ。chapter_setup の「VM のセットアップ」以降に当たる
# VM の中で sudo で実行する（何度実行してもよい）
# 使い方: sudo ./setup.sh
set -euo pipefail

USER_NAME=ubuntu
REPO_URL=https://github.com/n-tanaka-idcf/cnd-handson.git
REPO_BRANCH=hands-on

if [ "$(id -u)" -ne 0 ]; then
  echo "sudo で実行する" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# chapter_setup のパッケージ。qemu-guest-agent は Proxmox から IP を見たりバックアップで fs-freeze したりするのに使う
apt-get update -q
apt-get install -y -q curl vim git unzip gnupg lsb-release ca-certificates dstat jq qemu-guest-agent
# udev から起動される unit なので enable はできない。起動だけする
systemctl start qemu-guest-agent

# Docker CE を公式の apt リポジトリから入れる
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -q
apt-get install -y -q docker-ce docker-ce-cli containerd.io
# chapter_cluster-create の install-tools.sh でも入れるが、先に入れておく（入れたあとログインし直す必要がある）
usermod -aG docker "$USER_NAME"

# kind で inotify が足りなくなる（chapter_cluster-create）。/etc/sysctl.conf は上書きせず、sysctl.d に置く
cat > /etc/sysctl.d/90-kind-inotify.conf <<'EOF'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF
# --system は Ubuntu 既定の設定（promote_secondaries）でエラーを出すので、このファイルだけ反映する
sysctl -q -p /etc/sysctl.d/90-kind-inotify.conf

# VM の中から curl で叩く名前。80 番は Envoy Gateway、8080 番は Cilium の Ingress が待ち受ける
for host in app.example.com app-cilium.example.com troubleshoot.example.com cnd-web.example.com; do
  grep -qE "^127\.0\.0\.1[[:space:]]+$host\$" /etc/hosts || printf '127.0.0.1    %s\n' "$host" >> /etc/hosts
done

# ハンズオンのリポジトリ。すでにあれば触らない（作業中の変更を消さない）
if [ ! -d "/home/$USER_NAME/cnd-handson" ]; then
  sudo -u "$USER_NAME" git clone -b "$REPO_BRANCH" "$REPO_URL" "/home/$USER_NAME/cnd-handson"
fi

echo "--- installed"
docker --version
sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances
