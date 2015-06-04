#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月02日 星期二 10时33分23秒
# 
source "/home/jimin/.profile"

IP_LOG_FILE='ipAddress.log'
LOG_FILE='action.log'
ACTION_BASH='action.sh'

if [ ! -e $LOG_FILE ];then
    echo "$(date) 创建记录文件";
    touch $LOG_FILE;
fi

if [ ! -e $IP_LOG_FILE ];then
    echo "$(date) 创建IP地址记录文件";
    touch $IP_LOG_FILE;
fi

/sbin/ifconfig
if [ $? -eq 127 ];then
    apt-get install net-tools -y
fi

ipAddress=`/sbin/ifconfig ${1:-eth0}|\
awk '/inet addr/{print $2}' |\
awk -F: '{print $2}'`;

formerIpAddress=`tac $IP_LOG_FILE |\
sed -n -e "1p"|\
tac`;

if [ -z $formerIpAddress ];then
    echo $ipAddress > $IP_LOG_FILE;
    echo "$(date) 之前未记录IP地址" >> $LOG_FILE;
    echo "$(date) 已记录当前IP地址${ipAddress}" >> $LOG_FILE;
    ./$ACTION_BASH restart $ipAddress
else
    if [ $formerIpAddress != ${ipAddress} ];then
        echo "$(date) 当前IP地址为${ipAddress}" >> $LOG_FILE;
        echo "$(date) 上一次记录IP地址为${formerIpAddress}, IP地址变动" >> $LOG_FILE;
        ./$ACTION_BASH restart $ipAddress >> $LOG_FILE
        echo $ipAddress >> $IP_LOG_FILE;
        echo "$(date) 已记录当前IP地址${ipAddress}" >> $LOG_FILE;
    fi
fi
