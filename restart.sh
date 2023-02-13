#!/bin/bash

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

# 函数，判断命令是否正常执行
if_success() {
	if [ $? -eq 0 ]; then
	        action "$1" /bin/true
	else
	        action "$2" /bin/false
	        exit 1
	fi
}

# 定义路劲变量
Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
Conf_Dir="$Server_Dir/conf"
Log_Dir="$Server_Dir/logs"

## 关闭clash服务
Text1="服务关闭成功！"
Text2="服务关闭失败！"
# 查询并关闭程序进程
PID_NUM=`ps -ef | grep [c]lash-linux-a | wc -l`
PID=`ps -ef | grep [c]lash-linux-a | awk '{print $2}'`
if [ $PID_NUM -ne 0 ]; then
	kill -9 $PID
	# ps -ef | grep [c]lash-linux-a | awk '{print $2}' | xargs kill -9
fi
if_success $Text1 $Text2

sleep 3

## 重启启动clash服务
Text3="服务启动成功！"
Text4="服务启动失败！"
# 获取CPU架构  x86_64/aarch64
get_arch=`/bin/arch`
if [[ $get_arch =~ "x86_64" ]]; then
	nohup $Server_Dir/bin/clash-linux-amd64 -d $Conf_Dir &> $Log_Dir/clash.log &
	if_success $Text3 $Text4
elif [[ $get_arch =~ "aarch64" ]]; then
	nohup $Server_Dir/bin/clash-linux-armv7 -d $Conf_Dir &> $Log_Dir/clash.log &
	if_success $Text3 $Text4
else
	echo -e "\033[31m[ERROR] Unsupported CPU Architecture！\033[0m"
	exit 1
fi

