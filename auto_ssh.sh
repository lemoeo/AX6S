#!/bin/sh

auto_ssh_dir="/data/auto_ssh"
host_key="/etc/dropbear/dropbear_rsa_host_key"
host_key_bk="${auto_ssh_dir}/dropbear_rsa_host_key"

unlock() {
    # Restore the host key.
    [ -f $host_key_bk ] && ln -sf $host_key_bk $host_key

    # Enable telnet, ssh, uart and boot_wait.
    [ "$(nvram get telnet_en)" = 0 ] && nvram set telnet_en=1 && nvram commit
    [ "$(nvram get ssh_en)" = 0 ] && nvram set ssh_en=1 && nvram commit
    [ "$(nvram get uart_en)" = 0 ] && nvram set uart_en=1 && nvram commit
    [ "$(nvram get boot_wait)" = "off" ]  && nvram set boot_wait=on && nvram commit

    [ "`uci -c /usr/share/xiaoqiang get xiaoqiang_version.version.CHANNEL`" != 'stable' ] && {
        uci -c /usr/share/xiaoqiang set xiaoqiang_version.version.CHANNEL='stable' 
        uci -c /usr/share/xiaoqiang commit xiaoqiang_version.version 2>/dev/null
    }

    channel=`/sbin/uci get /usr/share/xiaoqiang/xiaoqiang_version.version.CHANNEL`
    if [ "$channel" = "release" ]; then
        sed -i 's/channel=.*/channel="debug"/g' /etc/init.d/dropbear
    fi

    if [ -z "$(pidof dropbear)" -o -z "$(netstat -ntul | grep :22)" ]; then
        /etc/init.d/dropbear restart 2>/dev/null
        /etc/init.d/dropbear enable
    fi
}

install() {
    # unlock SSH.
    unlock

    # host key is empty, restart dropbear to generate the host key.
    [ -s $host_key ] || /etc/init.d/dropbear restart 2>/dev/null

    # Backup the host key.
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

    # Add script to system autostart
    uci set firewall.auto_ssh=include
    uci set firewall.auto_ssh.type='script'
    uci set firewall.auto_ssh.path="${auto_ssh_dir}/auto_ssh.sh"
    uci set firewall.auto_ssh.enabled='1'
    uci commit firewall
    echo -e "\033[32m SSH unlock complete. \033[0m"
}

uninstall() {
    # Remove scripts from system autostart
    uci delete firewall.auto_ssh
    uci commit firewall
    echo -e "\033[33m SSH unlock has been removed. \033[0m"
}

main() {
    [ -z "$1" ] && unlock && return
    case "$1" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        echo -e "\033[31m Unknown parameter: $1 \033[0m"
        return 1
        ;;
    esac
}

main "$@"