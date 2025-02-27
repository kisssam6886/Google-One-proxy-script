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

    echo "你设置的 Socks5 端口：$socks_port 和 Http 端口：$http_port"
    echo "注意：当前配置无用户名和密码认证"
    sleep 2

    # 生成无认证的config.yaml，去掉空的metadata
    echo 'services:' > config.yaml
    echo '  - name: service-socks5' >> config.yaml
    echo "    addr: \":$socks_port\"" >> config.yaml
    echo '    resolver: resolver-0' >> config.yaml
    echo '    handler:' >> config.yaml
    echo '      type: socks5' >> config.yaml
    echo '    listener:' >> config.yaml
    echo '      type: tcp' >> config.yaml
    echo '  - name: service-http' >> config.yaml
    echo "    addr: \":$http_port\"" >> config.yaml
    echo '    resolver: resolver-0' >> config.yaml
    echo '    handler:' >> config.yaml
    echo '      type: http' >> config.yaml
    echo '    listener:' >> config.yaml
    echo '      type: tcp' >> config.yaml
    echo 'resolvers:' >> config.yaml
    echo '  - name: resolver-0' >> config.yaml
    echo '    nameservers:' >> config.yaml
    echo '      - addr: tls://1.1.1.1:853' >> config.yaml
    echo '        prefer: ipv4' >> config.yaml
    echo '        ttl: 5m0s' >> config.yaml
    echo '        async: true' >> config.yaml
    echo '      - addr: tls://1.0.0.1:853' >> config.yaml
    echo '        prefer: ipv4' >> config.yaml
    echo '        ttl: 5m0s' >> config.yaml
    echo '        async: true' >> config.yaml

    # 确保gost和config.yaml在主目录
    mv gost config.yaml "$HOME/" 2>/dev/null
    cd "$HOME" || { echo "无法切换到主目录"; exit 1; }
    echo '#!/bin/bash' > gost.sh
    echo "cd $HOME" >> gost.sh
    echo "./gost -C config.yaml &" >> gost.sh
    chmod +x gost.sh || { echo "权限设置失败"; exit 1; }

    echo "启动代理服务..."
    pkill gost  # 清除旧进程
    ./gost.sh
    sleep 2  # 等待启动

    public_ip=$(curl -4 -s ifconfig.me || curl -4 -s icanhazip.com || curl -4 -s ipinfo.io/ip || echo "无法获取IPv4公网IP，可能您的网络仅支持IPv6")
    local_ip=$(ip addr show | grep -E "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1 | head -n 1 || echo "无法获取本地IP")

    echo "安装完毕"
    echo "快捷方式：bash gv.sh  可查看Socks5端口与Http端口"
    echo "退出脚本运行：exit"
    echo "------------------------------------------------"
    echo "您的公网IPv4：$public_ip"
    echo "您的本地IP：$local_ip"
    if [ "$public_ip" = "无法获取IPv4公网IP，可能您的网络仅支持IPv6" ]; then
        echo "警告：未检测到IPv4地址，外部访问可能需要IPv6支持。"
    else
        echo "Socks5代理：$public_ip:$socks_port（无认证）"
        echo "HTTP代理：$public_ip:$http_port（无认证）"
    fi
    echo "------------------------------------------------"
    echo "提示："
    echo "1. 若使用VPN（如Google VPN One），代理已通过$public_ip可从外部访问，无需端口映射。"
    echo "2. 若未使用VPN且使用家庭宽带，需在路由器上将$socks_port和$http_port转发到$local_ip。"
    echo "3. 当前无认证，建议仅测试使用，正式部署请添加用户名密码。"
    echo "4. 若无法外部访问，检查VPN是否允许传入连接或端口是否被防火墙阻挡。"
    if command -v lsof >/dev/null && lsof -i :"$socks_port" >/dev/null; then
        echo "Socks5代理正在运行：$public_ip:$socks_port"
    else
        echo "警告：Socks5代理未启动，尝试手动运行 './gost -C config.yaml' 检查错误。"
        echo "当前目录：$(pwd)"
        echo "Gost是否存在：$(ls -l gost 2>/dev/null || echo '未找到gost')"
        echo "Config是否存在：$(ls -l config.yaml 2>/dev/null || echo '未找到config.yaml')"
    fi
    if command -v lsof >/dev/null && lsof -i :"$http_port" >/dev/null; then
        echo "HTTP代理正在运行：$public_ip:$http_port"
    else
        echo "警告：HTTP代理未启动，尝试手动运行 './gost -C config.yaml' 检查错误。"
    fi
    echo "警告：暴露代理到互联网有风险，建议添加认证保护。"
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
    echo "支持外部网络访问，无用户认证（测试版）"
    echo "快捷方式：bash gv.sh"
    echo "退出脚本运行：exit"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
    echo " 1. 重置安装"
    echo " 2. 删除卸载"
    echo " 0. 退出"
    echo "------------------------------------------------"
    if [[ -e config.yaml ]]; then
        echo "当前使用的Socks5端口：$(cat config.yaml 2>/dev/null | grep 'service-socks5' -A 2 | grep 'addr' | awk -F':' '{print $3}' | tr -d '\"')" 
        echo "当前使用的Http端口：$(cat config.yaml 2>/dev/null | grep 'service-http' -A 2 | grep 'addr' | awk -F':' '{print $3}' | tr -d '\"')"
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
