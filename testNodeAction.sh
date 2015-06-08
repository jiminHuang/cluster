#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月08日 星期一 15时24分34秒
# 

INSTALL_PATH='/usr/local/node-action'
RELATIVE_IMAGES="$INSTALL_PATH/relative.txt"
COMPOSE_FILE="$INSTALL_PATH/docker-compose.yml"
COMPOSE_MODEL="$INSTALL_PATH/docker-compose.model"

if [[ $USER != "root" ]];then
    echo "无root权限！"
    exit
fi

args=( \
    "server 127.0.0.1" \
    "server 127.0.0.1 127.0.0.1" \
    "client 127.0.0.1 127.0.0.1" \
)

TestInit(){
    for arg in ${#args[@]};
    do
        node-action init $arg  2>/dev/null 1>&2;
        if [ ! $? -eq 0 ];then
            echo "init测试: 参数$arg失败"
            return -1;
        fi
        docker-compose -f $COMPOSE_FILE stop 2>/dev/null 1>&2;
        echo y | sudo docker-compose -f $COMPOSE_FILE rm 2>/dev/null 1>&2;
    done
}

TestReload(){
    node-action reload ${args[0]} 2>/dev/null 1>&2
    if [ ! $? -eq 0 ];then
        echo "reload测试：参数${args[0]}失败"
        return -1;
    fi
    joinIp=`cat $COMPOSE_FILE | \
        awk '/join --addr=/{print $3}' | \
        awk -F '/' '{print $3}' | \
        awk -F ':' '{print $1}'`
    if [[ $joinIp != '127.0.0.1' ]];then
        echo "reload测试：joinIp在参数${args[0]}处匹配出错"
        return -1;
    fi
    
    comm=`cat $COMPOSE_FILE | \
        awk '/-advertise/{print $1 $2}'`
    if [[ $comm != '-server-bootstrap' ]];then
        echo "reload测试：comm在参数${args[0]}处匹配出错"
        return -1;
    fi

    hostnames=(`cat $COMPOSE_FILE | \
        awk '/hostname: /{print $0}'| \
        awk -F: '{print $2}' | \
        awk -F ' ' '{print $1}'`)
    if [[ ${hostnames[0]} != $HOSTNAME ]];then
        echo "reload测试：hostname在参数${args[0]}处匹配出错"
        return -1;
    fi

    node-action reload ${args[2]} 2>/dev/null 1>&2
    if [ ! $? -eq 0 ];then
        echo "reload测试：参数${args[2]}失败"
        return -1;
    fi
    comm=`cat $COMPOSE_FILE | \
        awk '/-advertise/{print $1 $2}'`
    if [[ $comm != '-join127.0.0.1' ]];then
        echo "reload测试：comm在参数${args[2]}处匹配出错"
        return -1;
    fi
    
    return 0
}

TestDocker(){
    consulDocker=`docker inspect nodeaction_consul_1| \
        awk '/Running/{print $2}' | \
        awk -F ',' '{print $1}'` 

    if [ ! $? -eq 0 ] || [[ $consulDocker != $1 ]];then
        echo -e "\ndocker状态检查:consul失败"; 
        return -1;
    fi

    swarmDocker=`docker inspect nodeaction_swarm_1| \
        awk '/Running/{print $2}' | \
        awk -F ',' '{print $1}'` 
    if [ ! $? -eq 0 ];then
        echo -e "\ndocker状态检查:swarm失败";
        return -1;
    fi
    registratorDocker=`docker inspect nodeaction_registrator_1| \
        awk '/Running/{print $2}' | \
        awk -F ',' '{print $1}'` 
    if [ ! $? -eq 0 ] || [[ $registratorDocker != $1 ]];then
        echo -e "\ndocker状态检查:registrator失败";
        return -1;
    fi
    return 0
}

TestStart(){
    node-action reload ${args[0]} 2>/dev/null 1>&2
    node-action start 2>/dev/null 1>&2
    if [ ! $? -eq 0 ];then
        echo "start测试：参数${args[0]}失败"
        return -1;
    fi
    TestDocker 'true'
    return $?
    
}

TestStop(){
    node-action reload ${args[0]} 2>/dev/null 1>&2
    node-action start 2>/dev/null 1>&2
    node-action stop 2>/dev/null 1>&2

    if [ ! $? -eq 0 ];then
        echo "stop测试：参数${args[0]}失败"
        return -1;
    fi
    
    TestDocker 'false'

    return $?
}

TestRefresh(){
    node-action reload ${args[0]} 2>/dev/null 1>&2
    node-action start 2>/dev/null 1>&2
    node-action refresh '127.0.0.1' 2>/dev/null 1>&2
    
    if [ ! $? -eq 0 ];then
        echo "refresh测试：参数${args[0]}失败"
        return -1;
    fi
    
    return 0
}

tests=("TestReload" "TestStart" "TestStop" "TestRefresh" "TestInit")

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

echo "节点部署脚本测试"

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

if [ $failedTimes -gt 0 ];then
    exit $failedTimes
fi 
