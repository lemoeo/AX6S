# Redmi AX6S 解锁 SSH、安装 ShellClash、刷入 OpenWRT 教程

## 解锁并固化 Telnet & SSH

1. 升级开发版固件  
下载 miwifi_rb03_firmware_stable_1.2.7.bin，浏览器打开 http://miwifi.com 进入小米路由器管理后台，打开 系统升级 -> 手动升级，选择下载的固件，将固件升级到开发版。

2. 获取 root 密码  
打开  https://www.oxygen7.cn/miwifi/ ，输入路由器后台右下角完整的 SN 号，点击 Go 即可计算出 root 密码。

3. 使用 SSH 连接路由器  
开发版默认已开启 Telnet 和 SSH，如果 SSH 无法连接，先 Telnet 连接到路由器，然后执行以下命令开启后再尝试用 SSH 连接路由器。  
Telnet / SSH 用户名：root  
密码：上一步计算出的密码
    ```shell
    nvram set telnet_en=1
    nvram set ssh_en=1
    nvram set uart_en=1
    nvram set boot_wait=on
    nvram commit
    /etc/init.d/dropbear enable
    /etc/init.d/dropbear start
    ```

4. 备份 Bdata 和 crash 分区
    1. 执行命令 `cat /proc/mtd`，查看 Bdata 和 crash 对应的 dev，我这里 Bdata 和 crash 对应的 dev 分别为 mtd5 和 mtd7。
    2. 执行下面命令备份 Bdata 和 crash，如果你的 Bdata 和 crash 不是 mtd5 和 mtd7，将 mtd5 和 mtd7 替换为正确的值即可。
        ```shell
        nanddump -f /tmp/Bdata_mtd5.img /dev/mtd5
        nanddump -f /tmp/crash_mtd7.img /dev/mtd7
        ```
    3. 打开 WinSCP ，使用 SCP 协议连接路由器，将备份的 Bdata_mtd5.img 和 crash_mtd7.img 下载保存好。

5. 修改 Bdata 和 crash 实现固化 Telnet / SSH
    1. 使用 HxD.exe 打开 crash_mtd7.img，将开头修改为 `A5 5A 00 00`，然后保存即可，如图。
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/1.png)
    2. 使用 HxD.exe 打开 Bdata_mtd5.img
    将 telnet_en、ssh_en、uart_en 的值修改为`1`，如图：
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/2.png)
    复制`boot_wait=on`，以覆盖方式粘贴到图中位置：
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/3.png)
    此时修改后的效果如图：
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/4.png)
    计算校验和，首先点击编辑-选择块
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/5.png)
    起始偏移输入4，结束偏移输入FFFF，点击确定
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/6.png)
    点击分析-校验码
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/7.png)
    选择CRC-32，点击确定
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/8.png)
    将开头四个字节修改为计算出的校验和的逆序的方式。
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/9.png)
    修改完成，点击保存。
    ![image](https://github.com/lemoeo/AX6S/raw/main/doc/10.png)

6. 刷入修改过的 Bdata_mtd5.img 和 crash_mtd7.img
    1. 首先使用 WinSCP，将修改过的 crash_mtd7.img 上传到路由器的 /tmp 目录下，然后执行下面命令刷入并重启路由器。
        ```shell
        mtd -r write /tmp/crash_mtd7.img crash
        ```
    2. 上传修改过的 Bdata_mtd5.img，刷入并重启。
        ```shell
        mtd -r write /tmp/Bdata_mtd5.img Bdata
        ```
    3. 清除解锁。修复WIFI客户端数量显示、Internet灯不亮等一些奇怪的问题
        ```shell
        mtd erase crash
        reboot
        ```
    > 自此， 无论是恢复出厂设置还是用官方修复工具刷机，Telnet 都是开启的状态。

7. 系统版本切换  
    ```shell
    # 查看当前启动分区
    nvram get flag_last_success
    ```
    如果执行上面命令返回为`1`，说明当前开发版系统在`1`分区，执行下面命令切换到`0`分区的稳定版系统：
    ```shell
    nvram set flag_last_success=0
    nvram set flag_boot_rootfs=0
    nvram commit
    reboot
    ```
    如果返回为 `0`，说明当前开发版系统在`0`分区，执行下面命令切换到`1`分区的稳定版系统：
    ```shell
    nvram set flag_last_success=1
    nvram set flag_boot_rootfs=1
    nvram commit
    reboot
    ```

8. 稳定版开启 SSH
    - 临时开启 SSH (路由器重启会失效)
    使用 Telnet 连接路由器，执行下面命令即可临时开启SSH：
      ```shell
      sed -i 's/channel=.*/channel=\"debug\"/g' /etc/init.d/dropbear
      /etc/init.d/dropbear restart
      ```
    - 永久开启 SSH
    原理就是添加一个开启自动运行的脚本，来实现自动开启 SSH。缺点就是恢复出厂设置或重新刷机后需要重新添加。
      ```shell
      # 创建一个目录并进入目录
      mkdir /data/auto_ssh && cd /data/auto_ssh
      # 下载脚本
      curl -O https://github.com/lemoeo/AX6S/raw/main/auto_ssh.sh
      # 添加执行权限
      chmod +x auto_ssh.sh
      # 添加开机自动运行
      uci set firewall.auto_ssh=include
      uci set firewall.auto_ssh.type='script'
      uci set firewall.auto_ssh.path='/data/auto_ssh/auto_ssh.sh'
      uci set firewall.auto_ssh.enabled='1'
      uci commit firewall
      ```

    > 自此，稳定版本固件重启也会自动开启SSH了。
    > 
    > 如果不需要自动开启 SSH 了，可以执行下面命令移除：
    ```shell
    # 移除开机自动运行
    uci delete firewall.auto_ssh
    uci commit firewall
    ```

    > 参考教程：  
    > https://www.right.com.cn/forum/thread-8206757-1-1.html  
    > https://www.wutaijie.cn/?p=254


## 官方固件安装 ShellClash
使用 SSH 连接路由器，执行下面命令安装(选择一个源进行安装即可)：
```shell
#fastgit.org加速
export url='https://raw.fastgit.org/juewuy/ShellClash/master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
#GitHub源
export url='https://raw.githubusercontent.com/juewuy/ShellClash/master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
#jsDelivrCDN源
export url='https://cdn.jsdelivr.net/gh/juewuy/ShellClash@master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
#作者私人源
export url='https://shellclash.ga' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
```

> ShellClash 项目地址：https://github.com/juewuy/ShellClash


## 刷入 OpenWRT 固件
### 选择一个固件并下载
[【20220427】AX6S 开源/闭源无线驱动Openwrt 刷机教程/固件下载](https://www.right.com.cn/forum/thread-8187405-1-1.html)  
[[更新v3][20220417]红米AX6S LEDE R22.4.1定制化多功能OpenWrt固件](https://www.right.com.cn/forum/thread-8219050-1-1.html)  
[[更新][220423]红米AX6S OpenWrt官方master分支自用养老固件](https://www.right.com.cn/forum/thread-8214026-1-1.html)

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
### 小米路由器系统
1. SSH 连接路由器  
2. 编辑网络接口配置文件 `vim /etc/config/network`，找到 `wan` 相关配置如下：
```
config interface 'wan'
        option proto 'pppoe'
        option peerdns '0'
        option username 'xxxxxxxxxxxx'
        option password 'xxxxxx'
        option special '0'
        option mru '1480'
        option ifname 'eth4'
        option ipv6 'auto'
```
其中 option ifname 'eth4' 表示此接口使用的物理网卡是eth4。

编辑文件 `/etc/config/network`，在文件尾部添加如下配置：
```
config interface 'modem'                  
        option proto 'static'             
        option ifname 'eth4'            
        option ipaddr '192.168.1.100'     
        option netmask '255.255.255.0' 
```
option ifname 和 wan 的 option ifname 相同，option ipaddr 设置为和光猫相同网段的IP地址。

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

> 参考：
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