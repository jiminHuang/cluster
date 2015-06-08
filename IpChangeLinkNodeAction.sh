#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月08日 星期一 21时43分14秒
# 
ROOT_PATH='/usr/local/'
INSTALL=('node-action' 'ip-change')
ACTION_BASH="${ROOT_PATH}${INSTALL[1]}/register.sh"
RELOAD_FILE="${ROOT_PATH}${INSTALL[0]}/reload.txt"

if [[ $USER != "root" ]];then
    echo "无root权限！"
    exit
fi

if [ ! -e $RELOAD_FILE ];then
    echo "还没有配置节点操作！"
    exit 0
fi

if [ ! -e $ACTION_BASH ];then
    echo "还没有配置ip检测"
    exit 0
fi

comm=`sed -n -e "1p" $RELOAD_FILE`

echo "RELOAD 命令: $comm"

echo "node-action reload $comm " > $ACTION_BASH


