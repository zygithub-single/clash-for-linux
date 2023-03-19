#!/bin/bash

# 加载系统函数库(Only for RHEL Linux)
# [ -f /etc/init.d/functions ] && source /etc/init.d/functions

# 获取脚本工作目录绝对路径
Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# 加载.env变量文件
source $Server_Dir/.env

Conf_Dir="$Server_Dir/conf"
Temp_Dir="$Server_Dir/temp"
Log_Dir="$Server_Dir/logs"
URL=${CLASH_URL}

# 自定义action函数，实现通用action功能
success() {
  echo -en "\\033[60G[\\033[1;32m  OK  \\033[0;39m]\r"
  return 0
}

failure() {
  local rc=$?
  echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"
  [ -x /bin/plymouth ] && /bin/plymouth --details
  return $rc
}

action() {
  local STRING rc

  STRING=$1
  echo -n "$STRING "
  shift
  "$@" && success $"$STRING" || failure $"$STRING"
  rc=$?
  echo
  return $rc
}

# 判断命令是否正常执行 函数
if_success() {
  local ReturnStatus=$3
  if [ $ReturnStatus -eq 0 ]; then
          action "$1" /bin/true
  else
          action "$2" /bin/false
          exit 1
  fi
}

# 临时取消环境变量
unset http_proxy
unset https_proxy
unset no_proxy

# 检查url是否有效
echo -e '\n正在检测订阅地址...'
Text1="Clash订阅地址可访问！"
Text2="Clash订阅地址不可访问！"
for i in {1}
do
        wget --spider -T 5 -q -t 2 $URL
        ReturnStatus=$?
	echo $RetrunStatus
        if [ $ReturnStatus -ne 0 ]; then
                break
        else
                continue
        fi
done
if_success $Text1 $Text2 $ReturnStatus

# 拉取更新config.yml文件
echo -e '\n正在下载Clash配置文件...'
Text3="配置文件config.yaml下载成功！"
Text4="配置文件config.yaml下载失败，退出启动！"
for i in {1}
do
        #curl -s -o $Temp_Dir/clash.yaml $URL
        wget -q -O $Temp_Dir/clash.yaml $URL
	ReturnStatus=$?
        if [ $ReturnStatus -eq 0 ]; then
                break
        else
                continue
        fi
done
if_success $Text3 $Text4 $ReturnStatus

# 取出代理相关配置 
sed -n '/^proxies:/,$p' $Temp_Dir/clash.yaml > $Temp_Dir/proxy.txt

# 合并形成新的config.yaml
cat $Temp_Dir/templete_config.yaml > $Temp_Dir/config.yaml
cat $Temp_Dir/proxy.txt >> $Temp_Dir/config.yaml
\cp $Temp_Dir/config.yaml $Conf_Dir/

# Configure Clash Dashboard
Work_Dir=$(cd $(dirname $0); pwd)
Dashboard_Dir="${Work_Dir}/dashboard/public"
sed -ri "s@^# external-ui:.*@external-ui: ${Dashboard_Dir}@g" $Conf_Dir/config.yaml
# Get RESTful API Secret
Secret=`grep '^secret: ' $Conf_Dir/config.yaml | grep -Po "(?<=secret: ').*(?=')"`

# 获取CPU架构
if /bin/arch &>/dev/null; then
	CpuArch=`/bin/arch`
elif /usr/bin/arch &>/dev/null; then
	CpuArch=`/usr/bin/arch`
elif /bin/uname -m &>/dev/null; then
	CpuArch=`/bin/uname -m`
else
	echo -e "\033[31m\n[ERROR] Failed to obtain CPU architecture！\033[0m"
	exit 1
fi

if [[ $CpuArch =~ "x86_64" ]]; then
	Arch_version="/bin/clash-linux-amd64"
elif [[ $CpuArch =~ "aarch64" ]]; then
	Arch_version="/bin/clash-linux-armv7"
fi

# 启动Clash服务
#echo -e '\n正在启动Clash服务...'
#Text5="服务启动成功！"
#Text6="服务启动失败！"
#if [[ $CpuArch =~ "x86_64" ]]; then
#	nohup $Server_Dir/bin/clash-linux-amd64 -d $Conf_Dir &> $Log_Dir/clash.log &
#	ReturnStatus=$?
#	if_success $Text5 $Text6 $ReturnStatus
#elif [[ $CpuArch =~ "aarch64" ]]; then
#	nohup $Server_Dir/bin/clash-linux-armv7 -d $Conf_Dir &> $Log_Dir/clash.log &
#	ReturnStatus=$?
#	if_success $Text5 $Text6 $ReturnStatus
#else
#	echo -e "\033[31m\n[ERROR] Unsupported CPU Architecture！\033[0m"
#	exit 1
#fi
cat>/etc/systemd/system/clash.service<<EOF
[Unit]
Description=Clash daemon, A rule-based proxy in Go.
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=$Server_Dir$Arch_version -d $Conf_Dir

[Install]
WantedBy=multi-user.target
EOF

if [ $? -eq 0 ]; then
	echo "add service succ !"
else
	echo "add service fail QAQ"
	
fi


echo -e '\n正在启动Clash服务...'
Text5="服务启动成功！"
Text6="服务启动失败！"


systemctl daemon-reload
systemctl start clash
systemctl enable clash
if [ $? -eq 0 ]; then
	echo $Text5
else
	echo $Text6
fi

# Output Dashboard access address and Secret
echo ''
echo -e "Clash Dashboard 访问地址：http://IP:9090/ui"
echo -e "Secret：${Secret}"
echo ''

# 添加环境变量(root权限)
#echo -e "source /etc/profile.d/clash.sh\n"
source /etc/profile.d/clash.sh
echo -e "请执行以下命令开启系统代理: proxy_on\n"
echo -e "若要临时关闭系统代理，请执行: proxy_off\n"
echo -e "systemctl start clash # start clash service\n"
echo -e "systemctl enable clash # enable clash service\n"
echo -e "systemctl stop clash # stop clash service\n"
