#!/bin/bash

gvinstall(){
    pkg install -y screen curl iproute2 || { echo "依赖安装失败，请检查网络或包名"; exit 1; }
    if [ ! -e gost ]; then
        echo "下载中……"
        curl -L -o gost_3.0.0_linux_arm64.tar.gz --retry 3 --retry-delay 5 --max-time 60 https://raw.githubusercontent.com/yonggekkk/google_vpn_proxy/main/gost_3.0.0_linux_arm64.tar.gz || {
            echo "切换中转下载"
            curl -L -o gost_3.0.0_linux_arm64.tar.gz --retry 3 --retry-delay 5 --max-time 60 https://gh-proxy.com/https://raw.githubusercontent.com/yonggekkk/google_vpn_proxy/main/gost_3.0.0_linux_arm64.tar.gz || {
                echo "下载失败，请检查网络"; exit 1;
            }
        }
        tar zxvf gost_3.0.0_linux_arm64.tar.gz || { echo "解压失败"; exit 1; }
    fi
    rm -f gost_3.0.0_linux_arm64.tar.gz README* LICENSE*

    read -p "设置 Socks5 端口（回车跳过为10000-65535之间的随机端口）：" socks_port
    if [ -z "$socks_port" ]; then
        socks_port=$(shuf -i 10000-65535 -n 1)
    fi
    read -p "设置 Http 端口（回车跳过为10000-65535之间的随机端口）：" http_port
    if [ -z "$http_port" ]; then
        http_port=$(shuf -i 10000-65535 -n 1)
    fi

    # 添加用户认证
    read -p "设置代理认证用户名（回车跳过为随机生成）： " username
    if [ -z "$username" ]; then
        username=$(openssl rand -hex 4 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
    fi
    read -p "设置代理认证密码（回车跳过为随机生成）： " password
    if [ -z "$password" ]; then
        password=$(openssl rand -hex 6 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
    fi

    echo "你设置的 Socks5 端口：$socks_port 和 Http 端口：$http_port"
    echo "认证信息 - 用户名：$username，密码：$password"
    sleep 2

    echo 'services:' > config.yaml
    echo '  - name: service-socks5' >> config.yaml
    echo "    addr: \"0.0.0.0:$socks_port\"" >> config.yaml
    echo '    resolver: resolver-0' >> config.yaml
    echo '    handler:' >> config.yaml
    echo '      type: socks5' >> config.yaml
    echo '      metadata:' >> config.yaml
    echo '        auth:' >> config.yaml
    echo '          type: userpass' >> config.yaml
    echo '          users:' >> config.yaml
    echo "            - username: $username" >> config.yaml
    echo "              password: $password" >> config.yaml
    echo '        udp: true' >> config.yaml
    echo '        udpbuffersize: 4096' >> config.yaml
    echo '    listener:' >> config.yaml
    echo '      type: tcp' >> config.yaml
    echo '  - name: service-http' >> config.yaml
    echo "    addr: \"0.0.0.0:$http_port\"" >> config.yaml
    echo '    resolver: resolver-0' >> config.yaml
    echo '    handler:' >> config.yaml
    echo '      type: http' >> config.yaml
    echo '      metadata:' >> config.yaml
    echo '        basic_auth:' >> config.yaml
    echo '          users:' >> config.yaml
    echo "            - username: $username" >> config.yaml
    echo "              password: $password" >> config.yaml
    echo '        udp: true' >> config.yaml
    echo '        udpbuffersize: 4096' >> config.yaml
    echo '    listener:' >> config.yaml
    echo '      type: tcp' >> config.yaml
    echo 'resolvers:' >> config.yaml
    echo '  - name: resolver-0' >> config.yaml
    echo '    nameservers:' >> config.yaml
    echo '      - addr: dns://8.8.8.8' >> config.yaml
    echo '        prefer: ipv4' >> config.yaml
    echo '        ttl: 5m0s' >> config.yaml
    echo '        async: true' >> config.yaml
    echo '      - addr: dns://8.8.4.4' >> config.yaml
    echo '        prefer: ipv4' >> config.yaml
    echo '        ttl: 5m0s' >> config.yaml
    echo '        async: true' >> config.yaml

    # 修正路径
    if [ -d "/data/data/com.termux/files/usr" ]; then
        PROFILE_DIR="/data/data/com.termux/files/usr/etc/profile.d"
    else
        PROFILE_DIR="$HOME/.profile.d"
        mkdir -p "$PROFILE_DIR"
    fi
    cd "$PROFILE_DIR" || { echo "无法切换目录"; exit 1; }

    echo '#!/data/data/com.termux/files/usr/bin/bash' > gost.sh
    echo "cd $HOME" >> gost.sh
    echo "./gost -C config.yaml &" >> gost.sh
    chmod +x gost.sh || { echo "权限设置失败"; exit 1; }

    echo "启动代理服务..."
    pkill gost
    sleep 1
    ./gost.sh
    sleep 2  # 等待启动

    public_ip=$(curl -4 -s ifconfig.me || curl -s ifconfig.me/ipv6 || curl -4 -s icanhazip.com || curl -s icanhazip.com/ipv6 || echo "无法获取公网IP")
    local_ip=$(ip addr show | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | head -n 1 || echo "无法获取本地IP")

    echo "安装完毕"
    echo "快捷方式：bash gv.sh  可查看Socks5端口与Http端口"
    echo "退出脚本运行：exit"
    echo "------------------------------------------------"
    echo "您的公网IP：$public_ip"
    echo "您的本地IP：$local_ip"
    echo "Socks5代理：$public_ip:$socks_port（用户名：$username，密码：$password）"
    echo "HTTP代理：$public_ip:$http_port（用户名：$username，密码：$password）"
    echo "------------------------------------------------"
    echo "提示："
    echo "1. 若使用VPN（如Google VPN One），需确认其是否支持传入连接，通常不支持，建议关闭VPN。"
    echo "2. 若未使用VPN，使用家庭宽带，需在路由器上将$socks_port和$http_port转发到$local_ip。"
    echo "3. HTTP认证不安全，建议优先使用Socks5。"
    echo "4. 若无法外部访问，检查端口是否被防火墙阻挡或联系网络提供商。"
    echo "警告：暴露代理到互联网有风险，请确保密码安全。"
    sleep 2
    exit
}

uninstall(){
    pkill gost
    rm -f gost config.yaml
    echo "卸载完毕"
}

show_menu(){
    curl -sSL https://raw.githubusercontent.com/yonggekkk/google_vpn_proxy/main/gv.sh -o gv.sh && chmod +x gv.sh
    clear
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
    echo "甬哥Github项目  ：github.com/yonggekkk"
    echo "甬哥Blogger博客 ：ygkkk.blogspot.com"
    echo "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
    echo "Google_VPN局域网共享代理：Socks5+Http双代理一键脚本"
    echo "支持外部网络访问，已添加用户认证"
    echo "快捷方式：bash gv.sh"
    echo "退出脚本运行：exit"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
    echo " 1. 重置安装"
    echo " 2. 删除卸载"
    echo " 0. 退出"
    echo "------------------------------------------------"
    if [[ -e config.yaml ]]; then
        echo "当前使用的Socks5端口：$(cat config.yaml 2>/dev/null | grep 'service-socks5' -A 2 | grep 'addr' | awk -F':' '{print $3}' | tr -d '\"' | cut -d':' -f2)" 
        echo "当前使用的Http端口：$(cat config.yaml 2>/dev/null | grep 'service-http' -A 2 | grep 'addr' | awk -F':' '{print $3}' | tr -d '\"' | cut -d':' -f2)"
    else
        echo "未安装，请选择 1 进行安装"
    fi
    echo "------------------------------------------------"
    read -p "请输入数字:" Input
    case "$Input" in     
        1 ) gvinstall;;
        2 ) uninstall;;
        * ) exit 
    esac
}

show_menu
