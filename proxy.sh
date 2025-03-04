#!/bin/bash

gvinstall(){
    # 安装依赖，添加错误检查
    pkg install -y screen curl iproute2 lsof || { echo "依赖安装失败，请检查网络或包名"; exit 1; }

    # 下载Gost，增加超时和重试机制
    if [ ! -e gost ]; then
        echo "下载中……"
        curl -L -o gost_3.0.0_linux_arm64.tar.gz --retry 3 --retry-delay 5 --max-time 120 --progress-bar https://raw.githubusercontent.com/yonggekkk/google_vpn_proxy/main/gost_3.0.0_linux_arm64.tar.gz || {
            echo "当前网络无法链接Github，切换中转下载"
            curl -L -o gost_3.0.0_linux_arm64.tar.gz --retry 3 --retry-delay 5 --max-time 120 --progress-bar https://gh-proxy.com/https://raw.githubusercontent.com/yonggekkk/google_vpn_proxy/main/gost_3.0.0_linux_arm64.tar.gz || {
                echo "下载失败，请检查网络或使用代理"; exit 1;
            }
        }
        tar zxvf gost_3.0.0_linux_arm64.tar.gz || { echo "解压失败"; exit 1; }
    fi
    rm -f gost_3.0.0_linux_arm64.tar.gz README* LICENSE*

    # 设置常用端口（固定为1080和8080）
    socks_port=1080
    http_port=8080

    echo "你设置的 Socks5 端口：$socks_port 和 Http 端口：$http_port"
    echo "注意：当前配置无用户名和密码认证（测试版）"
    sleep 2

    # 生成无认证的config.yaml，确保监听0.0.0.0以支持外部访问
    echo 'services:' > config.yaml
    echo '  - name: service-socks5' >> config.yaml
    echo "    addr: \"0.0.0.0:$socks_port\"" >> config.yaml
    echo '    resolver: resolver-0' >> config.yaml
    echo '    handler:' >> config.yaml
    echo '      type: socks5' >> config.yaml
    echo '    listener:' >> config.yaml
    echo '      type: tcp' >> config.yaml
    echo '  - name: service-http' >> config.yaml
    echo "    addr: \"0.0.0.0:$http_port\"" >> config.yaml
    echo '    resolver: resolver-0' >> config.yaml
    echo '    handler:' >> config.yaml
    echo '      type: http' >> config.yaml
    echo '    listener:' >> config.yaml
    echo '      type: tcp' >> config.yaml
    echo 'resolvers:' >> config.yaml
    echo '  - name: resolver-0' >> config.yaml
    echo '    nameservers:' >> config.yaml
    echo '      - addr: tls://8.8.8.8:853' >> config.yaml
    echo '        prefer: ipv4' >> config.yaml
    echo '        ttl: 5m0s' >> config.yaml
    echo '        async: true' >> config.yaml
    echo '      - addr: tls://8.8.4.4:853' >> config.yaml
    echo '        prefer: ipv4' >> config.yaml
    echo '        ttl: 5m0s' >> config.yaml
    echo '        async: true' >> config.yaml
    echo '      - addr: tls://[2001:4860:4860::8888]:853' >> config.yaml
    echo '        prefer: ipv6' >> config.yaml
    echo '        ttl: 5m0s' >> config.yaml
    echo '        async: true' >> config.yaml
    echo '      - addr: tls://[2001:4860:4860::8844]:853' >> config.yaml
    echo '        prefer: ipv6' >> config.yaml
    echo '        ttl: 5m0s' >> config.yaml
    echo '        async: true' >> config.yaml

    # 修正路径，适配Termux或其他环境
    if [ -d "/data/data/com.termux/files/usr" ]; then
        PROFILE_DIR="/data/data/com.termux/files/usr/etc/profile.d"
    else
        PROFILE_DIR="$HOME/.profile.d"
        mkdir -p "$PROFILE_DIR"
    fi
    cd "$PROFILE_DIR" || { echo "无法切换目录"; exit 1; }

    # 生成启动脚本，确保路径正确并清理旧进程
    echo '#!/data/data/com.termux/files/usr/bin/bash' > gost.sh
    echo "cd $HOME" >> gost.sh
    echo "pkill -9 gost" >> gost.sh
    echo "screen -wipe" >> gost.sh
    echo "screen -ls | grep -E '[0-9]+\.myscreen' | awk '{print \$1}' | xargs -r screen -X -S quit" >> gost.sh
    echo "screen -dmS myscreen bash -c './gost -C config.yaml'" >> gost.sh
    chmod +x gost.sh || { echo "权限设置失败"; exit 1; }

    # 启动代理服务，清理旧进程并尝试两种后台运行方式
    echo "启动代理服务..."
    pkill -9 gost
    sleep 1
    screen -wipe
    screen -ls | grep -E '[0-9]+\.myscreen' | awk '{print $1}' | xargs -r screen -X -S quit

    # 优先使用 screen 启动（推荐）
    ./gost.sh
    sleep 2  # 等待 screen 启动

    # 备用：使用 & 后台运行（如果 screen 失败）
    if ! lsof -i :"$socks_port" >/dev/null 2>/dev/null; then
        echo "Screen 启动失败，尝试使用 & 后台运行..."
        cd $HOME && ./gost -C config.yaml &
        sleep 2
    fi

    sleep 3  # 确保启动完成

    # 获取Google VPN提供的公网IP，优先IPv4
    echo "获取Google VPN公网IP..."
    public_ip=$(curl -4 -s ifconfig.me || curl -4 -s icanhazip.com || curl -4 -s ipinfo.io/ip || curl -6 -s ifconfig.me || echo "无法获取Google VPN公网IP，请确保VPN已启用")
    local_ip=$(ip addr show 2>/dev/null | grep -E "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1 | head -n 1 || echo "无法获取本地IP")

    echo "安装完毕"
    echo "快捷方式：bash gv.sh  可查看Socks5端口与Http端口"
    echo "退出脚本运行：exit"
    echo "------------------------------------------------"
    echo "您的Google VPN公网IP：$public_ip"
    echo "您的本地IP：$local_ip"
    echo "Socks5代理：$public_ip:$socks_port（无认证）"
    echo "HTTP代理：$public_ip:$http_port（无认证）"
    echo "------------------------------------------------"
    echo "提示："
    echo "1. 确保Google VPN（Google Fi或Google One）已启用，获取公网IP。"
    echo "2. Google VPN通常不支持传入连接，无法直接外部访问，请关闭VPN，使用家庭宽带并在路由器上将$socks_port和$http_port转发到$local_ip。"
    echo "3. 局域网设备可通过$local_ip:$socks_port或$local_ip:$http_port访问，无需VPN。"
    echo "4. 当前无认证，建议仅测试使用，正式部署请添加用户名密码。"
    echo "5. 若无法获取公网IP，检查VPN连接或网络状态。"
    echo "6. 若公网IP为IPv6，客户端需支持IPv6连接。"
    echo "警告：暴露代理到互联网有风险，建议添加认证保护。"
    if command -v lsof >/dev/null && lsof -i :"$socks_port" >/dev/null 2>/dev/null; then
        echo "Socks5代理正在运行：$public_ip:$socks_port"
    else
        echo "警告：Socks5代理未启动，尝试手动运行 './gost -C config.yaml' 检查错误。"
        echo "当前目录：$(pwd)"
        echo "Gost是否存在：$(ls -l gost 2>/dev/null || echo '未找到gost')"
        echo "Config是否存在：$(ls -l config.yaml 2>/dev/null || echo '未找到config.yaml')"
    fi
    if command -v lsof >/dev/null && lsof -i :"$http_port" >/dev/null 2>/dev/null; then
        echo "HTTP代理正在运行：$public_ip:$http_port"
    else
        echo "警告：HTTP代理未启动，尝试手动运行 './gost -C config.yaml' 检查错误。"
    fi
    sleep 2
    exit
}

uninstall(){
    pkill -9 gost
    screen -ls | grep -E '[0-9]+\.myscreen' | awk '{print $1}' | xargs -r screen -X -S quit
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
    echo "支持Google VPN公网IP显示（测试版，无认证）"
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
