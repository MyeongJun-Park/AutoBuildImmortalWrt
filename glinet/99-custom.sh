#!/bin/sh
# 该脚本为immortalwrt首次启动时 运行的脚本 即 /etc/uci-defaults/99-custom.sh
# 设置默认防火墙规则，方便虚拟机首次访问 WebUI
uci set firewall.@zone[1].input='ACCEPT'

# 设置主机名映射，解决安卓原生 TV 无法联网的问题
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"

# 检查配置文件是否存在
SETTINGS_FILE="/etc/config/pppoe-settings"
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "PPPoE settings file not found. Skipping." >> $LOGFILE
else
   # 读取pppoe信息(由build.sh写入)
   . "$SETTINGS_FILE"
fi

# 无需判断网卡数量 因为glinet是多网口
uci set network.lan.ipaddr='192.168.8.1'
echo "set 192.168.8.1 at $(date)" >> $LOGFILE

# 判断是否启用 PPPoE
echo "print enable_pppoe value=== $enable_pppoe" >> $LOGFILE
if [ "$enable_pppoe" = "yes" ]; then
    echo "PPPoE is enabled at $(date)" >> $LOGFILE
    # 设置拨号信息
    uci set network.wan.proto='pppoe'                
    uci set network.wan.username=$pppoe_account     
    uci set network.wan.password=$pppoe_password     
    uci set network.wan.peerdns='1'                  
    uci set network.wan.auto='1' 
    echo "PPPoE configuration completed successfully." >> $LOGFILE
else
    echo "PPPoE is not enabled. Skipping configuration." >> $LOGFILE
fi

# 设置所有网口可访问网页终端
uci delete ttyd.@ttyd[0].interface

# 设置所有网口可连接 SSH
uci set dropbear.@dropbear[0].Interface=''
uci commit

# 设置编译作者信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Compiled by MyeongJun-Park"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

# 创建新的网络接口 "USB"
uci set network.usb='interface'                # 新建接口名称为 USB
uci set network.usb.proto='dhcp'               # 设置协议为 DHCP 客户端
uci set network.usb.device='eth2'              # 设置设备为 eth2

# 分配防火墙区域为 WAN 和 WAN6
uci add_list firewall.@zone[0].network='usb'   # 将 USB 接口添加到 WAN 区域
uci add_list firewall.@zone[1].network='usb'   # 将 USB 接口添加到 WAN6 区域

# 保存并应用配置
uci commit network
uci commit firewall

# 重启相关服务
/etc/init.d/network restart
/etc/init.d/firewall restart

exit 0