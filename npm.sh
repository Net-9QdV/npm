#!/bin/bash

export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ $EUID -ne 0 ]] && red "注意: 请在root用户下运行脚本" && exit 1

if [[ $SYSTEM == "CentOS" ]]; then
    ${PACKAGE_UPDATE[int]}
fi

if [[ -z $(type -P curl) ]]; then
    ${PACKAGE_INSTALL[int]} curl
fi

if [[ -z $(type -P docker) ]]; then
    curl -fsSL https://get.docker.com | bash -s docker
fi
if [[ -z $(type -P docker-compose) ]]; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

if [[ ! -d npm ]]; then
    rm -rf npm
fi
mkdir npm && cd npm

read -rp "请设置面板访问端口 [默认随机端口]: " config_port
[[ -z $config_port ]] && config_port=$(shuf -i 1000-65535 -n 1)
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$config_port") ]]; do
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w  "$config_port") ]]; then
        yellow "你设置的端口目前已被其他程序占用，请重新设置端口"
        read -rp "请设置面板访问端口 [默认随机端口]: " config_port
        [[ -z $config_port ]] && config_port=$(shuf -i 1000-65535 -n 1)
    fi
done

cat <<EOF > ~/docker-compose.yml
version: "3"
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80' # Public HTTP Port
      - '443:443' # Public HTTPS Port
      - '${config_port}:81' # Admin Web Port
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

docker-compose up -d


echo "====================================================="
echo "这是Nginx Proxy Manager的登录信息："
echo "Email: admin@example.com"
echo "Password: changeme"
echo "请登陆后尽快修改初始密码！"
echo "====================================================="
