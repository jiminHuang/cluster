#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月04日 星期四 19时04分05秒
# 
# The actions of a cluster node including init, start, stop, reload.

INSTALL_PATH='/usr/local/node-action'
RELATIVE_IMAGES="$INSTALL_PATH/relative.txt"
COMPOSE_FILE="$INSTALL_PATH/docker-compose.yml"
COMPOSE_MODEL="$INSTALL_PATH/docker-compose.model"
TEST_FILE="$INSTALL_PATH/testNodeAction.sh"
RELOAD_FILE="$INSTALL_PATH/reload.txt"

if [[ $USER != "root" ]];then
    echo "无root权限！"
    exit
fi

Usage(){
    case $1 in
        "command") 
            echo -e "\nUsage: node-action COMMAND [arg..]\n"
            echo -e "The actions of a cluster node including init, start, stop, reload.\n"
            echo "Commands:"
            echo -e "init\t Initialize the environment of a cluster node\t"
            echo -e "start\t Start a cluster node\t"
            echo -e "stop\t Stop a cluster node\t"
            echo -e "reload\t Reload the environment\t"
            echo -e "refresh\t Refresh the registered services\t"
            echo -e "test\t Test the command\t\n";;
        "init")
            echo -e "\nUsage: node-action init [mode] [ipaddress] [joinip]\n"
            echo -e "Init cluster node\n";;
        "reload")
            echo -e "\nUsage: node-action reload [mode] [ipaddress] [joinip]\n"
            echo -e "Reload cluster node in new ipaddress and joinip.\n"
            echo -e "Notion: The mode can't change in this command\n\n";;
        "test")
            echo -e "\nUsage: node-action test\n"
            echo -e "Tests\n";;
        "refresh")
            echo -e "\nUsage: node-action refresh CONSUL_IP\n";;
    esac
}

Init(){
    if [[ -z $1 ]];then
        echo "mode is missing";
        Usage "init";
    fi 
    if [[ $1 != 'server' ]] \
        && [[ $1 != 'client' ]];then
        echo "mode not in server or client";
        Usage "init";
    fi
    if [[ -z $2 ]];then
        echo "ipaddress is missing";
        Usage "init";
    fi

    echo -n "检查docker..."
    
    docker > /dev/null 2>$1
    
    if [ $? -eq 127 ];then
        echo -ne "\e[1;31m[未安装]\e[0m";
        wget > /dev/null 2>&1;
        if [ $? -eq 127 ];then
            apt-get update && apt-get install wget -y;
        fi
        wget -qO- https://get.docker.com/ | sh;
        echo -ne "\b\b\b\b\b\b\b\b"
        echo -e "\e[1;32m[已安装]\e[0m";
    else
        echo -e "\e[1;32m[已安装]\e[0m";
    fi
    
    echo -n "检查docker DNS设置..."
    
    dnsSettings='DOCKER_OPTS=\"-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --dns 172.17.42.1 --dns-search service.consul\"'

    search=`cat /etc/default/docker | grep "$dnsSettings"` 
    if [[ -z $search ]];then
        echo $dnsSettings >> /etc/default/docker
    fi
    echo -e "\e[1;32m[已完成]\e[0m";

    echo -n "检查docker-compose..."

    docker-compose > /dev/null 2>&1
    
    if [ $? -eq 127 ];then
        echo -ne "\e[1;31m[未安装]\e[0m";
        curl > /dev/null 2>&1
        if [ $? -eq 127 ];then
            sudo apt-get update > /dev/null 2>&1 && sudo apt-get install curl -y > /dev/null 2>&1
        fi
        curl -L https://github.com/docker/compose/releases/download/1.2.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose;
        chmod +x /usr/local/bin/docker-compose;
        echo -ne "\b\b\b\b\b\b\b\b"
        echo -e "\e[1;32m[已安装]\e[0m";
    else
        echo -e "\e[1;32m[已安装]\e[0m";
    fi
    
    echo "检查镜像..."
    images=`cat $RELATIVE_IMAGES`
    echo "需要拉取以下镜像:"
    pulled_images=`docker images | cut -d " " -f1`
    
    for image in $images;
    do
        echo -n "$image..."
        searched=false;
        for pulled_image in $images;
        do
            if [[ $image == $pulled_image ]];then
                echo -n "$pulled_image"
                searched=true;
                break;
            fi
        done
        if [ ! $searched ];then
            echo -ne "\e[1;31m[未拉取]\e[0m";
            docker pull $image;
            echo -ne "\b\b\b\b\b\b\b\b"
            echo -e "\e[1;32m[已拉取]\e[0m";
        else
            echo -e "\e[1;32m[已拉取]\e[0m";
        fi
    done
    
    Reload $1 $2 $3
    Start
}

Reload(){
    if [[ -z $1 ]];then
        echo "mode is missing";
        Usage "reload";
    fi 
    if [[ $1 != 'server' ]] \
        && [[ $1 != 'client' ]];then
        echo "mode not in server or client";
        Usage "reload";
    fi
    if [[ -z $2 ]];then
        echo "ipaddress is missing";
        Usage "reload";
    fi

    comm=""
    if [[ -z $3 ]];then
        case $1 in
            "client") Usage "reload";;
            "server") comm="-server -bootstrap";;
        esac
    else
        comm="$comm -join $3"
    fi

    echo "$1 \$1 $3" > $RELOAD_FILE
    
    echo "生成命令 $comm"
    
    echo "开始生成Yml文件"
    
    cp $COMPOSE_MODEL $COMPOSE_FILE

    sed "s/{ipaddress}/$2/g" -i $COMPOSE_FILE
    sed "s/{command}/$comm/g" -i $COMPOSE_FILE
    sed "s/{joinip}/${3:-$2}/g" -i $COMPOSE_FILE
    sed "s/{hostname}/$HOSTNAME/g" -i $COMPOSE_FILE
    
    echo "Yml文件生成完毕"
    echo "配置重置完成"

}

Start(){
    echo "开启节点"
    docker-compose -f $COMPOSE_FILE stop swarm
    echo y | sudo docker-compose -f $COMPOSE_FILE rm swarm 
    docker-compose -f $COMPOSE_FILE up -d consul 
    docker-compose -f $COMPOSE_FILE up -d registrator 
    docker-compose -f $COMPOSE_FILE up -d swarm 
}

Stop(){
    docker-compose -f $COMPOSE_FILE stop
}

Refresh(){
    if [[ -z $1 ]];then
        Usage "refresh";
    else
        curl http://$1:8500/v1/catalog/deregister -d "{\"Node\":\"$HOSTNAME\"}"
        docker-compose -f $COMPOSE_FILE stop registrator
        docker-compose -f $COMPOSE_FILE start registrator
    fi
}

Test(){
    bash $TEST_FILE
    exit $?
}


if [[ -z $? ]];then
    Usage "command";
else
    if [[ -z $1 ]];then
        Usage "command";
    else
        case $1 in
            "init") Init $2 $3 $4;;
            "start") Start;;
            "stop") Stop;;
            "reload") Reload $2 $3 $4;;
            "test") Test;;
            "refresh") Refresh $2;;
            *) Usage "command";;
        esac
    fi
fi
