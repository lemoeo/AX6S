# Redmi AX6S 解锁 SSH、刷入 OpenWRT 教程

## 解锁 Telnet & SSH
1. 更新系统 ROM 版本到开发版，开发版默认已开启 Telnet  
使用浏览器进入小米路由器管理后台，进入 `常用设置 -> 系统状态`，点击 `手动升级`，选择下载好的开发版固件点击开始升级。  
    > Redmi AX6S 开发版固件下载地址：[miwifi_rb03_firmware_stable_1.2.7.bin](https://raw.githubusercontent.com/lemoeo/AX6S/main/miwifi_rb03_firmware_stable_1.2.7.bin)

2. 获取 Telnet & SSH 登录路由器的 root 用户密码  
打开 https://miwifi.dev/ssh ，输入小米路由器管理后台首页显示的序列号（SN），点击 Calc 即可计算出密码。

3. 开启 SSH 服务  
使用 Telnet 协议连接路由器，执行下面 `开启 SSH 服务` 的命令，命令执行成功后就可以使用 SSH 协议连接路由器了。  
    ```shell
    # Telnet 连接信息
    IP 地址：192.168.31.1
    端口号：23
    用户名：root
    密码：上一步获取的密码

    # SSH 连接信息
    IP 地址：192.168.31.1
    端口号：22
    用户名：root
    密码：上一步获取的密码

    # 开启 SSH 服务
    nvram set telnet_en=1 && nvram set ssh_en=1 && nvram set uart_en=1 && nvram set boot_wait=on && nvram commit
    /etc/init.d/dropbear enable & /etc/init.d/dropbear start
    ```

4. 自动开启 SSH 服务  
经过上面的步骤，已经成功在小米路由器上解锁 SSH 服务，但是由于小米路由器是 Snapshot 系统，重启会重置为最初状态，导致解锁 SSH 失效。  
解决办法：添加一个开机自动执行的脚本，来实现自动开启 SSH 服务：  
    ```shell
    # 创建一个目录用于放置脚本文件
    mkdir /data/auto_ssh && cd /data/auto_ssh

    # 下载脚本文件，使用 GitHub 地址下载失败可以使用 jsDelivr CDN 地址进行下载
    # GitHub 地址
    curl -O https://raw.githubusercontent.com/lemoeo/AX6S/main/auto_ssh.sh
    # jsDelivr CDN 地址
    curl -O https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/auto_ssh.sh

    # 为脚本增加可执行权限
    chmod +x auto_ssh.sh

    # 添加开机自动执行 auto_ssh.sh 脚本
    uci set firewall.auto_ssh=include
    uci set firewall.auto_ssh.type='script'
    uci set firewall.auto_ssh.path='/data/auto_ssh/auto_ssh.sh'
    uci set firewall.auto_ssh.enabled='1'
    uci commit firewall
    ```

    如果不需要自动开启 SSH 服务，使用下面命令移除即可：  
    ```shell
    # 移除开机自动执行 auto_ssh.sh 脚本
    uci delete firewall.auto_ssh
    uci commit firewall
    ```

5. 如何切换回稳定版系统  
小米路由器是双系统分区，系统更新会刷写到另一个分区然后从另一个分区启动，所以更新开发版之后，之前的稳定版系统还存在于原来的分区。可以通过修改引导分区切换回升级前的系统。

    首先查看当前引导分区：  
    ```shell
    nvram get flag_last_success
    ```

    如果查看当前引导分区返回结果为 `0`，说明当前开发版系统在 `0` 分区，更新之前的稳定版系统就在 `1` 分区。执行命令修改引导分区为 `1` 分区并重启路由器：  
    ```shell
    nvram set flag_last_success=1
    nvram set flag_boot_rootfs=1
    nvram commit
    reboot
    ```

    同理，如果查看当前引导分区返回结果为 `1`，那么更新之前的稳定版系统就在 `0` 分区。执行命令修改引导分区为 `0` 分区并重启路由器：
    ```shell
    nvram set flag_last_success=0
    nvram set flag_boot_rootfs=0
    nvram commit
    reboot
    ```

    因为我们已经添加了 `自动开启 SSH 服务` 的脚本，理论上只要不恢复出厂设置或者重新刷机，切换回稳定版系统或者系统升级都不会影响自动开启 SSH 服务。

> 如果恢复出厂设置或者进行了刷机，需要重新刷入开发版固件进行解锁 SSH 的操作。  
> 想要恢复出厂设置或者刷机后不用再刷入开发版固件，可以参考下面的 `固化 Telnet & SSH` 教程。


## 固化 Telnet & SSH
1. 首先使用 SSH 协议连接路由器

2. 备份 Bdata 和 crash 分区
    1. 执行命令 `cat /proc/mtd`，查看 name 为 Bdata 和 crash 对应的 dev 信息。  
    例如：Bdata 和 crash 对应的 dev 分别为 mtd5 和 mtd7。

    2. 执行下面命令备份 Bdata 和 crash，如果你的 Bdata 和 crash 不是 mtd5 和 mtd7，将 mtd5 和 mtd7 替换为对应的值即可：
        ```shell
        nanddump -f /tmp/Bdata_mtd5.img /dev/mtd5
        nanddump -f /tmp/crash_mtd7.img /dev/mtd7
        ```

    3. 打开 WinSCP ，使用 SCP 协议连接路由器，将备份的 Bdata_mtd5.img 和 crash_mtd7.img 下载保存。

3. 修改 Bdata 和 crash 实现固化 Telnet / SSH
    1. 使用 HxD.exe 打开 crash_mtd7.img，将开头修改为 `A5 5A 00 00`，然后保存即可，如图所示：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/1.png)

    2. 使用 HxD.exe 打开 Bdata_mtd5.img，将 `telnet_en、ssh_en、uart_en` 的值修改为 `1`，如图所示：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/2.png)

        复制 `boot_wait=on`，以覆盖方式粘贴到图中位置：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/3.png)

        此时修改后的结果如图所示：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/4.png)

        计算校验和，首先点击 `编辑 -> 选择块`：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/5.png)

        起始偏移输入 `4`，结束偏移输入 `FFFF`，点击 `确定`：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/6.png)

        点击 `分析 -> 校验码`：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/7.png)

        选择 `CRC-32`，点击 `确定`：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/8.png)

        将开头四个字节修改为计算出的校验和的逆序的方式：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/9.png)

        修改完成，点击 `保存`：

        ![image](https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/doc/10.png)

4. 刷入修改过的 Bdata_mtd5.img 和 crash_mtd7.img
    1. 首先使用 WinSCP，将修改后的 crash_mtd7.img 上传到路由器的 /tmp 目录下，执行下面命令刷入然后重启路由器：
        ```shell
        mtd -r write /tmp/crash_mtd7.img crash
        ```

    2. 上传修改后的 Bdata_mtd5.img，执行命令刷入然后重启路由器：
        ```shell
        mtd -r write /tmp/Bdata_mtd5.img Bdata
        ```

    3. 清除解锁（修复 WIFI 客户端数量显示、Internet 灯不亮等一些奇怪的问题）
        ```shell
        mtd erase crash
        reboot
        ```

> 固化完成，以后不管是恢复出厂设置还是用官方修复工具刷机，Telnet 默认都是开启的状态。  

> 完成固化的路由器，恢复出厂设置或者刷机后只需要以下步骤解锁 SSH 服务（因为官方固件中默认限制了稳定版不能打开 SSH 服务）  
> 具体步骤参考：`固化后如何解锁 SSH 服务`

## 固化后如何解锁 SSH 服务
因为官方固件中默认限制了稳定版不能打开 SSH 服务，所以即便进行了固化操作，在恢复出厂设置或者刷机之后，SSH 服务默认也是关闭状态，但是 Telnet 默认是开启状态。此时可以通过 Telnet 连接路由器，进行如下操作解锁 SSH 服务。
- 临时解锁 SSH 服务（路由器重启会失效）  
使用 Telnet 协议连接路由器，执行下面命令即可：
    ```shell
    sed -i 's/channel=.*/channel=\"debug\"/g' /etc/init.d/dropbear
    /etc/init.d/dropbear restart
    ```

- 自动解锁 SSH 服务  
由于小米路由器 Snapshot 系统的特性，重启会恢复系统文件导致解锁 SSH 失效，可以添加一个开机自动运行的脚本来实现路由器重启后自动解锁 SSH 服务：
    ```shell
    # 创建一个目录用于放置脚本文件
    mkdir /data/auto_ssh && cd /data/auto_ssh

    # 下载脚本文件，使用 GitHub 地址下载失败可以使用 jsDelivr CDN 地址进行下载
    # GitHub 地址
    curl -O https://raw.githubusercontent.com/lemoeo/AX6S/main/auto_ssh.sh
    # jsDelivr CDN 地址
    curl -O https://cdn.jsdelivr.net/gh/lemoeo/AX6S@main/auto_ssh.sh

    # 为脚本增加可执行权限
    chmod +x auto_ssh.sh

    # 添加开机自动执行解锁 SSH 脚本
    uci set firewall.auto_ssh=include
    uci set firewall.auto_ssh.type='script'
    uci set firewall.auto_ssh.path='/data/auto_ssh/auto_ssh.sh'
    uci set firewall.auto_ssh.enabled='1'
    uci commit firewall
    ```

- 移除开机自动执行解锁 SSH 脚本：
    ```shell
    uci delete firewall.auto_ssh
    uci commit firewall
    ```

> 参考教程：  
> https://www.right.com.cn/forum/thread-8206757-1-1.html  
> https://www.wutaijie.cn/?p=254


## 刷入 OpenWRT 固件
### 下载固件
[【20220427】AX6S 开源/闭源无线驱动Openwrt 刷机教程/固件下载](https://www.right.com.cn/forum/thread-8187405-1-1.html)  
[[更新v3][20220417]红米AX6S LEDE R22.4.1定制化多功能OpenWrt固件](https://www.right.com.cn/forum/thread-8219050-1-1.html)  
[[更新][220423]红米AX6S OpenWrt官方master分支自用养老固件](https://www.right.com.cn/forum/thread-8214026-1-1.html)  
[OpenWrt 官方固件](https://openwrt.org/toh/xiaomi/ax3200)

### 刷入下载的固件
1. 使用 WinSCP 将下载的固件中的 factory.bin 上传到路由器的 /tmp 目录下。

2. 使用 SSH 链接路由器，执行命令：
    ```shell
    # 设置启动第一个系统分区
    nvram set flag_last_success=0 & nvram set flag_boot_rootfs=0
    # 保存设置
    nvram commit
    # 刷入过度固件 factory.bin 到第一个系统分区 firmware 并重启路由器
    mtd -r write /tmp/factory.bin firmware
    ```

3. 路由器重启完成之后，打开 http://192.168.6.1 进入 OpenWRT 后台管理界面  
用户名：root  
密码：password  
登录之后依次点击进入 `系统 -> 备份/升级 -> 刷写新的固件`  
去掉勾选 `保留配置`，选择下载的固件 mt76.bin 或 open2.4g.bin 或者你下载的其它固件，点击 `刷写固件 -> 处理`  
等待固件刷入完成即可。


## 桥接模式下访问光猫后台
### 小米路由器官方系统
1. SSH 连接路由器  

2. 编辑网络接口配置文件 `vim /etc/config/network`，找到 `wan` 相关配置如下：
    ```
    config interface 'wan'
            option proto 'pppoe'
            option mtu '1500'
            option special '0'
            option username 'xxxxxxxxxxxx'
            option mru '1480'
            option password 'xxxxxx'
            option ifname 'eth1'
            option last_succeed '1'
            option ipv6 'auto'
    ```
    其中 `option ifname 'eth1'` 表示此接口使用的物理网卡是 `eth1`

    编辑文件 `/etc/config/network`，在文件尾部添加如下配置：
    ```
    config interface 'modem'
            option proto 'static'
            option ifname 'eth1'
            option ipaddr '192.168.1.100'
            option netmask '255.255.255.0'
    ```
    注意：option ifname 和 wan 的 option ifname 相同，option ipaddr 设置为和光猫相同网段的IP地址。

3. 编辑防火墙配置文件 `vim /etc/config/firewall`，找到如下配置：
    ```
    config zone
            option name 'wan'
            list network 'wan'
            list network 'wan6'
            option input 'REJECT'
            option output 'ACCEPT'
            option forward 'REJECT'
            option masq '1'
            option mtu_fix '1'
    ```
    在 `list network 'wan6'` 下面添加一行 `list network 'modem'`， 修改完成后的配置如下：
    ```
    config zone
            option name 'wan'
            list network 'wan'
            list network 'wan6'
            list network 'modem'
            option input 'REJECT'
            option output 'ACCEPT'
            option forward 'REJECT'
            option masq '1'
            option mtu_fix '1'
    ```
    保存文件，重启路由器即可访问光猫后台管理界面。

    > 参考教程：  
    https://blog.csdn.net/qq1337715208/article/details/121570165

### OpenWRT 系统
打开 OpenWRT 后台管理界面，在 `网络 -> 接口` 中添加一个新的接口配置如下：
```
名称：modem
协议：静态地址
接口：选择和 wan 相同的接口
``` 
点击 `提交`，然后在 modem 接口基本设置中 IPv4 地址设置为与光猫相同网段的地址，子网掩码设置为 255.255.255.0，防火墙设置中区域分配为 wan，配置如下：
```
# 基本设置
IPv4 地址：192.168.1.100
IPv4 子网掩码：255.255.255.0
# 防火墙设置
创建/分配防火墙区域：wan
```
点击 `保存&应用`，即可访问光猫管理界面。
