#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月02日 星期二 10时33分23秒
# 
# 记录当前IP地址并与之前IP地址比较，如果改变则执行指定脚本文件
# Example: ip-change listen 
#
#

#安装路径
INSTALL_PATH='/usr/local/ip-change'

#日志文件路径
IP_LOG_FILE="$INSTALL_PATH/ipAddress.log"
LOG_FILE="$INSTALL_PATH/action.log"

#脚本文件路径
ACTION_BASH="$INSTALL_PATH/register.sh"

#命令帮助信息
Usage(){
    echo -e "\nUsage: ip-change COMMAND [arg..]\n"
    echo -e "listen the change of ip address.\n"
    echo "Commands:"
    echo -e "listen [webname]\t Start listening\t"
    echo -e "reload [bash]\t Reload the content of bash file\t"
    echo -e "cron\t Create crontab task\t"
    echo -e "test\t Test the command\t\n"
    exit -1
}

#检查用户权限
if [[ $USER != "root" ]];then
    echo "无root权限！"
    exit
fi

#检查必要参数
if [[ -z $1 ]];then
    Usage;
fi

#获取当前网卡IP，参数为空时自动获取eth0网卡
#Example: PresentIpAddress 获取eth0 IP地址
#Example: PresentIpAddress lo 获取lo IP地址
PresentIpAddress(){
    #检查ifconfig命令是否安装，该命令提供网卡信息
    /sbin/ifconfig >/dev/null 

    #安装ifconfig命令
    if [ $? -eq 127 ];then
        apt-get update >/dev/null 2>&1 && apt-get install net-tools -y >/dev/null 2>&1
    fi

    #返回截取的IP地址
    echo `/sbin/ifconfig ${1:-eth0}|\
    awk '/inet addr/{print $2}' |\
    awk -F: '{print $2}'`;
}

#获取当前网卡IP的单元测试
TestPresentIpAddress(){
    #lo地址始终为127.0.0.1
    ipAddress=`PresentIpAddress lo`
    
    if [[ $ipAddress != "127.0.0.1" ]];then
        return -1
    fi
    
    return 0
}

#生成带时间的字符串
#注意：生成的时间与字符串产生的时间并不一致
GenerateStringWithDate(){
    if [[ -z $@ ]];then
        echo "日志信息 为空"
    else
        echo "$(date) $@";
    fi    
}

#生成带时间的字符串的单元测试
TestGenerateStringWithDate(){
    #空串测试
    if [[ `GenerateStringWithDate` != "日志信息 为空" ]];then
        return -1
    fi
    
    #命令执行测试
    echo `GenerateStringWithDate "测试信息"`
    if [ ! $? -eq 0 ];then
        return -1
    fi
    
    return 0
}

#在日志文件中记录操作信息
LogAction(){
    #检查日志文件是否存在
    if [ ! -e $LOG_FILE ];then
        touch $LOG_FILE;
        echo `GenerateStringWithDate "创建日志文件"` >> $LOG_FILE
    fi
    
    #写入带时间的操作信息
    echo `GenerateStringWithDate $@` >> $LOG_FILE
}

#在日志文件中记录信息的单元测试
TestLogAction(){
    #设定测试路径
    tmp=$LOG_FILE
    LOG_FILE="/tmp/test.log"

    LogAction "测试信息"

    #日志文件是否被创建
    if [ ! -e $LOG_FILE ];then
        echo "日志文件未被创建"
        rm $LOG_FILE
        LOG_FILE=$tmp
        return -1
    fi 

    #检验写入信息
    if [[ -z `cat $LOG_FILE | grep '测试信息'` ]];then
        echo "信息未被正确写入"
        rm $LOG_FILE
        LOG_FILE=$tmp
        return -1
    fi

    #还原
    rm $LOG_FILE
    LOG_FILE=$tmp
    return 0

}

#检查IP地址
CheckIp(){
    #检查是否为空
    if [[ -z $1 ]];then
        LogAction "IP地址为空";
        return -1;
    fi
    
    #正则匹配检查
    RECheckResult=`echo $1|egrep "([0-9]{1,3}\.){3}[0-9]{1,3}$"`    
    if [[ -z $RECheckResult ]];then
        LogAction "IP地址格式有误"
        return -1;
    fi
    return 0
}

#检查IP地址的单元测试
TestCheckIp(){
    #测试情景设定
    checks=("" "127.0.0.1" "123.123.1111" "127.0.0.1,")
    results=(255 0 255 255)

    for ((case=0;case<"${#checks[*]}";case++))
    do
        CheckIp ${checks[$case]}
        if [ ! $? -eq ${results[$case]} ];then
            echo "第${case}项检验失败"
            return -1
        fi
    done
    
    return 0
}

#IP日志文件操作：读和写
#Example: IpAddressLog read 读取上一次记录IP
#Example: IpAddressLog write "127.0.0.1" 写入新的IP
IpAddressLog(){
    #检查IP日志文件是否存在
    if [ ! -e $IP_LOG_FILE ];then
        LogAction "创建IP地址记录文件";
        touch $IP_LOG_FILE;
    fi
    
    #检查参数
    if [[ -z $1 ]];then
        LogAction "IP日志操作缺乏必要参数"
        return -1
    fi
    
    case $1 in 
        "read")
            readIp=`tac $IP_LOG_FILE |\
                sed -n -e "1p" |\
                tac`
            CheckIp $readIp
            if [ ! $? -eq 0 ];then
                LogAction "读取IP $readIp 未通过IP检查"
                echo ""
            else
                echo $readIp
            fi;;
        "write")
            CheckIp $2
            if [ ! $? -eq 0 ];then
                LogAction "写入IP $2 未通过IP检查"
                return -1
            else
                echo $2 >> $IP_LOG_FILE 
            fi;;
    esac
}

#IP日志文件操作单元测试
TestIpAddressLog(){
    #测试路径设定
    tmp=$LOG_FILE
    LOG_FILE='/tmp/test.log'
    ipTmp=$IP_LOG_FILE
    IP_LOG_FILE='/tmp/testIp.log'

    #无参数测试
    IpAddressLog
    if [ $? -eq 0 ];then
        rm $LOG_FILE
        rm $IP_LOG_FILE
        LOG_FILE=$tmp
        IP_LOG_FILE=$ipTmp
        echo "无参数测试失败"
        return -1
    fi
    
    #检查文件是否创建
    if [ ! -e $IP_LOG_FILE ];then
        rm $LOG_FILE
        rm $IP_LOG_FILE
        LOG_FILE=$tmp
        IP_LOG_FILE=$ipTmp
        echo "文件创建失败"
        return -1
    fi
    
    
    #写测试
    IpAddressLog write "127.0.0.1"
    if [ ! $? -eq  0 ];then
        rm $LOG_FILE
        rm $IP_LOG_FILE
        LOG_FILE=$tmp
        IP_LOG_FILE=$ipTmp
        echo "写测试失败"
        return -1
    fi

    #读测试
    readResult=`IpAddressLog read`
    if [[ $readResult != '127.0.0.1' ]];then
        rm $LOG_FILE
        rm $IP_LOG_FILE
        LOG_FILE=$tmp
        IP_LOG_FILE=$ipTmp
        echo "读测试失败"
        return -1
    fi
    
    #还原
    rm $LOG_FILE
    rm $IP_LOG_FILE
    LOG_FILE=$tmp
    IP_LOG_FILE=$ipTmp
    return 0
}

#重载脚本文件
Reload(){
    echo $@ > $ACTION_BASH
}

#当IP改变时执行脚本
ActionWhenIpChange(){
    #检查是否有对应脚本
    if [ ! -e $ACTION_BASH ];then
        LogAction "创建空注册脚本"
        touch $ACTION_BASH;
    fi

    #检查脚本是否有执行权限
    if [ ! -x $ACTION_BASH ];then
        chmod +x $ACTION_BASH;
    fi
    
    bash $ACTION_BASH $1 >> $LOG_FILE 
}

#当IP改变时执行脚本的单元测试
TestActionWhenIpChange(){
    #测试环境设定
    tmp=$LOG_FILE
    LOG_FILE='/tmp/test.log'
    bashTmp=$ACTION_BASH
    ACTION_BASH='/tmp/action.sh'
    
    #空脚本测试
    ActionWhenIpChange "127.0.0.1"

    #检查文件是否创建
    if [ ! -e $ACTION_BASH ];then
        rm $LOG_FILE
        rm $ACTION_BASH
        LOG_FILE=$tmp
        ACTION_BASH=$bashTmp
        echo "文件创建失败"
        return -1
    fi
    
    #检查文件是否可执行
    if [ ! -x $ACTION_BASH ];then
        rm $LOG_FILE
        rm $ACTION_BASH
        LOG_FILE=$tmp
        ACTION_BASH=$bashTmp
        echo "文件不可执行"
        return -1
    fi

    #写入脚本
    Reload "echo \"suc \$1\" > $ACTION_BASH"

    #脚本测试
    ActionWhenIpChange "127.0.0.1"
    
    #检查执行结果
    result=`tac $ACTION_BASH | sed -n -e "1p" | tac`
    if [[ $result != 'suc 127.0.0.1' ]];then
        rm $LOG_FILE
        rm $ACTION_BASH
        LOG_FILE=$tmp
        ACTION_BASH=$bashTmp
        echo "脚本测试失败"
        return -1
    fi
    
    #还原 
    rm $LOG_FILE
    rm $ACTION_BASH
    LOG_FILE=$tmp
    ACTION_BASH=$bashTmp
    return 0
}

#创建crontab定时任务
Cron(){
    timer='* * * * * root sudo ip-change listen'
    if [[ -z `cat /etc/crontab | grep "$timer"` ]];then
        echo "$timer" >> /etc/crontab
    fi
}

#主测试，打印辅助信息
Test(){
    echo "[$1测试]:"
    if [[ -z $1 ]];then
        echo "测试为空"
        return -1;
    fi
    $1
    if [ ! $? -eq 0 ];then
        echo "失败";
        return -1;
    else
        echo "成功";
        return 0;
    fi
}

#脚本执行
case $1 in
    "listen") #listen命令获取当前IP,当IP改变时执行注册脚本

        #获取IP地址
        ipAddress=`PresentIpAddress`
        formerIpAddress=`IpAddressLog read`
    
        LogAction "当前IP地址为${ipAddress}"
        IpAddressLog write $ipAddress
        if [ ! $? -eq 0 ];then
            echo "写入当前IP地址失败"
            exit -1;
        fi

        #IP地址变动
        if [[ ${formerIpAddress} != ${ipAddress} ]];then
            LogAction "IP地址变动，开始执行脚本：";
            ActionWhenIpChange $ipAddress
        fi;;

    "reload") #重载脚本文件
        Reload $2;;
    
    "cron") #创建crontab定时任务
        Cron;;

    "test") #test命令测试脚本
        tests=("TestPresentIpAddress" "TestGenerateStringWithDate" "TestLogAction" "TestCheckIp" "TestIpAddressLog" "TestActionWhenIpChange")
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
        
        exit $failedTimes;;
    *)
        Usage;;
esac
