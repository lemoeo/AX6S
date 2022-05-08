#!/bin/sh

host_key=/etc/dropbear/dropbear_rsa_host_key
host_key_bk=/data/auto_ssh/dropbear_rsa_host_key

# 如果存在备份的SSH密钥，将备份的密钥链接到dropbear使用的密钥
if [ -f $host_key_bk ]; then
    ln -sf $host_key_bk $host_key
fi

# 当前固件为稳定版时，需要执行下面命令开启SSH
channel=`/sbin/uci get /usr/share/xiaoqiang/xiaoqiang_version.version.CHANNEL`
if [ "$channel" = "release" ]; then
    sed -i 's/channel=.*/channel="debug"/g' /etc/init.d/dropbear
    /etc/init.d/dropbear restart
fi

# 备份SSH密钥
if [ ! -s $host_key_bk ]; then
    i=0
    while [ $i -le 30 ]
    do
        if [ -s $host_key ]; then
            cp -f $host_key $host_key_bk 2>/dev/null
            break
        fi
        let i++
        sleep 1s
    done
fi
