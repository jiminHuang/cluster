#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月04日 星期四 19时04分05秒
# 
# The actions of a cluster node including init, start, stop, restart.

RELATIVE_IMAGES='relative.txt'

Init(){
    if [[ -z $1 -o $1 != 'server' -o $1 != 'client' ]];then
        Usage 2;
    fi
    
    docker
    
    if [ $? -eq 127 ];then
        wget
        if [ $? -eq 127 ];then
            apt-get update && apt-get install wget -y;
        else
            wget -qO- https://get.docker.com/ | sh;
            echo "DOCKER_OPTS='--dns 172.17.42.1 --dns 8.8.8.8 --dns-search service.consul'" >> /etc/default/docker
        fi
    fi
    
    docker-compose
    
    if [ $? -eq 127 ];then
        curl -L https://github.com/docker/compose/releases/download/1.2.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose;
        chmod +x /usr/local/bin/docker-compose;
    fi
    
    images=`cat $RELATIVE_IMAGES`
    
    for image in $images;
    do
        docker pull $image;
    done
}

Start(){

    ipAddress=`/sbin/ifconfig eth0|\
    awk '/inet addr/{print $2}' |\
    awk -F: '{print $2}'`;
    
    if [[ -z $1 ]];then
        checkMode=`docker inspect consul_$HOSTNAME | grep server`
        if [[ -z $checkMode ]];then
            originMode='client';
        else
            originMode='server';
        fi
    else
        originMode=$1;
    fi
    
    if [[ -z $2 ]];then
        joinIp=(`docker inspect consul_$HOSTNAME |\
        grep -A 1 "\-join" | \
        egrep -o '([0-9]{1,3}.){3}[0-9]{1,3}'`);
        if [ $(#joinIp[*]) -gt 0 ];then
            joinIp=$joinIp[0];
        else
            joinIp='';
        fi
    else
        joinIp=$2;
    fi

    
    
    #start consul server
    case $originMode in
        "server") mode='-server -bootstrap';;
        "client") mode='';;
    esac 

    if [[ -n $joinIp ]];then
        join="-join $joinIp";
    else
        join='';
    fi
        
    docker run --name consul_$HOSTNAME -h $HOSTNAME  \
        -p $ipAddress:8300:8300 \
        -p $ipAddress:8301:8301 \
        -p $ipAddress:8301:8301/udp \
        -p $ipAddress:8302:8302 \
        -p $ipAddress:8302:8302/udp \
        -p $ipAddress:8400:8400 \
        -p $ipAddress:8500:8500 \
        -p 172.17.42.1:53:53/udp \
        -d  \
        progrium/consul $mode $join -advertise $ipAddress

    docker run -d \
    -v /var/run/docker.sock:/tmp/docker.sock \
    --name registrator_$HOSTNAME \
    -h $HOSTNAME progrium/registrator consul:// 
    
    docker run --rm swarm join --addr=$ipAddress:2375 consul://${joinIp:-$ipAddress}/swarm
    
}

Stop(){
    docker stop consul_$HOSTNAME
    docker rm consul_$HOSTNAME
}



if [[ -z $? ]];then
    Usage;
else
    if [[ -z $1 ]];then
        Usage 1;
    else
        case $1 in
            "init") Init $2 $3;;
            "start") Start $2;;
            "stop") Stop;;
            "restart") Stop; Start;;
            *) Usage 1;;
        esac


                 
    
