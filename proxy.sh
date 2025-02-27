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

    # 生成无认证的config.yaml
    echo 'services:' > config.yaml
    echo '  - name: service-socks5' >> config.yaml
    echo "    addr: \":$socks_port\"" >> config.yaml
    echo '    resolver: resolver-0' >> config.yaml
    echo '    handler:' >> config.yaml
    echo '      type: socks5' >> config.yaml
    echo '      metadata:' >> config.yaml
    echo '        udp: true' >> config.yaml
    echo '        udpbuffersize: 4096' >> config.yaml
    echo '    listener:' >> config.yaml
    echo '      type: tcp' >> config.yaml
    echo '  - name: service-http' >> config.yaml
    echo "    addr: \":$http_port\"" >> config.yaml
    echo '    resolver: resolver-0' >> config.yaml
    echo '    handler:' >> config.yaml
    echo '      type: http' >> config.yaml
    echo '      metadata:' >> config.yaml
    echo '        udp: true' >> config.yaml
    echo '        udpbuffersize: 4096' >> config.yaml
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
    echo '        async: true
