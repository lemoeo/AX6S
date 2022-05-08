## AX6S 固化  Telnet / SSH

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
  - 使用 HxD.exe 打开 crash_mtd7.img，将开头修改为 `A5 5A 00 00`，然后保存即可，如图。
  ![image](https://github.com/lemoeo/AX6S/raw/main/doc/1.png)
  - 使用 HxD.exe 打开 Bdata_mtd5.img
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
  ```
  mtd erase crash
  reboot
  ```
  > 自此， 无论是恢复出厂设置还是用官方修复工具刷机，Telnet 都是开启的状态。

7. 系统版本切换
查看当前启动分区
```
nvram get flag_last_success
```
如果执行上面命令返回为`1`，说明当前开发版系统在`1`分区，执行下面命令切换到`0`分区的稳定版系统：
```
nvram set flag_last_success=0
nvram set flag_boot_rootfs=0
nvram commit
reboot
```
如果返回为 `0`，说明当前开发版系统在`0`分区，执行下面命令切换到`1`分区的稳定版系统：
```
nvram set flag_last_success=1
nvram set flag_boot_rootfs=1
nvram commit
reboot
```

8. 稳定版开启 SSH
- 临时开启 SSH (路由器重启会失效)
使用 Telnet 连接路由器，执行下面命令即可临时开启SSH：
```
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
```
# 移除开机自动运行
uci delete firewall.auto_ssh
uci commit firewall
```

> 参考教程：
> https://www.right.com.cn/forum/thread-8206757-1-1.html
> https://www.wutaijie.cn/?p=254