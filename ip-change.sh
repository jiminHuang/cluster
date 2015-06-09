#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月02日 星期二 10时33分23秒
# 
INSTALL_PATH='/usr/local/ip-change'
IP_LOG_FILE="$INSTALL_PATH/ipAddress.log"
LOG_FILE="$INSTALL_PATH/action.log"
ACTION_BASH="$INSTALL_PATH/register.sh"
TEST_BASH="$INSTALL_PATH/testIpChange.sh"

Usage(){
    echo -e "\nUsage: ip-change COMMAND [arg..]\n"
    echo -e "listen the change of ip address.\n"
    echo "Commands:"
    echo -e "start [webname]\t start listening\t"
    echo -e "test\t Test the command\t\n"
}

if [ ! -e $LOG_FILE ];then
    echo "$(date) 创建记录文件";
    touch $LOG_FILE;
fi

if [ ! -e $IP_LOG_FILE ];then
    echo "$(date) 创建IP地址记录文件";
    touch $IP_LOG_FILE;
fi

if [ ! -e $ACTION_BASH ];then
    echo "$(date) 创建样例执行文件";
    touch $ACTION_BASH;
fi

if [ ! -x $ACTION_BASH ];then
    chmod +x $ACTION_BASH;
fi

if [[ $USER != "root" ]];then
    echo "无root权限！"
    exit
fi

/sbin/ifconfig >/dev/null 
if [ $? -eq 127 ];then
    apt-get update >/dev/null 2>&1 && apt-get install net-tools -y >/dev/null 2>&1
fi

if [[ -z $1 ]];then
    Usage;
fi

case $1 in
    "start")
        ipAddress=`/sbin/ifconfig ${2:-eth0}|\
        awk '/inet addr/{print $2}' |\
        awk -F: '{print $2}'`;
    
        formerIpAddress=`tac $IP_LOG_FILE |\
        sed -n -e "1p"|\
        tac`;
        
        if [ -z $formerIpAddress ];then
            echo $ipAddress > $IP_LOG_FILE;
            echo "$(date) 之前未记录IP地址" >> $LOG_FILE;
            echo "$(date) 已记录当前IP地址${ipAddress}" >> $LOG_FILE;
            bash $ACTION_BASH $ipAddress >> $LOG_FILE
        else
            if [[ $formerIpAddress != ${ipAddress} ]];then
                echo "$(date) 当前IP地址为${ipAddress}" >> $LOG_FILE;
                echo "$(date) 上一次记录IP地址为${formerIpAddress}, IP地址变动" >> $LOG_FILE;
                bash $ACTION_BASH $ipAddress >> $LOG_FILE
                echo $ipAddress >> $IP_LOG_FILE;
                echo "$(date) 已记录当前IP地址${ipAddress}" >> $LOG_FILE;
            fi
        fi;;
    "test")
        bash $TEST_BASH;
        exit $?;
esac
