#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月08日 星期一 10时49分13秒
# 
INSTALL_PATH='/usr/local/ip-change'
IP_LOG_FILE="$INSTALL_PATH/ipAddress.log"
LOG_FILE="$INSTALL_PATH/action.log"
ACTION_BASH="$INSTALL_PATH/register.sh"

if [[ $USER != "root" ]];then
    echo "无root权限！"
    exit
fi

TestChange(){
    echo "127.0.0.1" >> $IP_LOG_FILE
    if [ -e $ACTION_BASH ];then
        cp $ACTION_BASH "$ACTION_BASH.bak"
    fi
    echo "echo \"suc \$1\" > $ACTION_BASH" > $ACTION_BASH
    ip-change start
    formerIpAddress=`tac $IP_LOG_FILE |\
    sed -n -e "1p"|\
    tac`;
    if [[ $formerIpAddress = "127.0.0.1" ]];then
        return -1;
    fi
    actionResult=`sed -n -e "1p" $ACTION_BASH`
    if [[ $actionResult != "suc $formerIpAddress" ]];then
        return -1;
    fi
    mv "$ACTION_BASH.bak" $ACTION_BASH
    return 0;
}

TestUnChange(){
    if [ -e $ACTION_BASH ];then
        cp $ACTION_BASH "$ACTION_BASH.bak"
    fi
    echo "echo \"err\" > $ACTION_BASH" > $ACTION_BASH
    ip-change start
    actionResult=`sed -n -e "1p" $ACTION_BASH`
    if [[ $actionResult = "err" ]];then
        return -1;
    fi
    echo '' > $IP_LOG_FILE
    return 0;
}

Test(){
    echo -n "Test_$1..."
    if [[ -z $1 ]];then
        return -1;
    fi
    $1
    if [ ! $? -eq 0 ];then
        echo -e "[失败]";
        return -1;
    else
        echo -e "[成功]";
        return 0;
    fi
}

tests=("TestChange" "TestUnChange")
echo "IP自动侦测脚本测试"

failedTimes=0
for testCase in ${tests[@]};
do
    Test $testCase;
    if [ ! $? -eq 0 ];then
        let failedTimes+=1; 
    fi
done

echo "===================================="
echo "共进行${#tests[*]}项测试,失败了$failedTimes 项测试"

exit $failedTimes
