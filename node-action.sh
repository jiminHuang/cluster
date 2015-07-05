#!/bin/bash
# 
# Author: jimin.huang
# 
# Created Time: 2015年06月04日 星期四 19时04分05秒
# 
# 安装，启动，停止，刷新一个集群节点.
##

#安装路径
INSTALL_PATH='/usr/local/node-action'

#依赖镜像文件
RELATIVE_IMAGES="$INSTALL_PATH/relative.txt"

#yml文件
COMPOSE_FILE="$INSTALL_PATH/docker-compose.yml"
COMPOSE_MODEL="$INSTALL_PATH/docker-compose.model"

#历史日志文件
HISTORY_FILE="$INSTALL_PATH/history.log"

#检查用户权限
if [[ $USER != "root" ]];then
    echo "无root权限！"
    exit
fi

#命令帮助信息
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
            echo -e "\nUsage: node-action init\n"
            echo -e "Init cluster node\n";;
        "reload")
            echo -e "\nUsage: node-action reload [OPTIONS] [arg..]\n"
            echo -e "Reload cluster node in new mode, ipaddress and joinip.\n"
            echo "Options:"
            echo -e "-m [server/client/server-bootstrap/server-bootstrap-expect]\t cluster mode\t"
            echo -e "-j 172.16.153.xx\t joinip\t"
            echo -e "-i 172.16.153.xx\t ipaddress\t";;
        "link")
            echo -e "\nUsage: node-action link\n";;
        "test")
            echo -e "\nUsage: node-action test\n"
            echo -e "Tests\n";;
        "refresh")
            echo -e "\nUsage: node-action refresh\n";;
    esac
}

#初始化节点环境,包括docker安装，docker设置，docker-compose安装，依赖镜像拉取
Init(){
    echo "初始化节点环境"
    
    #检查docker是否安装
    echo -n "检查docker..."
    docker > /dev/null 2>&1
    
    #命令执行返回码127表示命令并未安装
    if [ $? -eq 127 ];then
        echo -ne "\e[1;31m[未安装]\e[0m";
        
        #检查wget是否安装
        wget > /dev/null 2>&1;

        if [ $? -eq 127 ];then
            apt-get update && apt-get install wget -y;
        fi

        #拉取docker安装文件并安装
        wget -qO- https://get.docker.com/ | sh;

        echo -ne "\b\b\b\b\b\b\b\b"
        echo -e "\e[1;32m[已安装]\e[0m";
    else
        echo -e "\e[1;32m[已安装]\e[0m";
    fi
    
    #检查docker设置
    echo -n "检查docker DNS设置..."
    
    #包括dockerDNS设置与开放2375对外接口
    dnsSettings='DOCKER_OPTS=\"-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --dns 172.17.42.1 --dns-search service.consul\"'

    #配置文件中查找,没有则增加
    search=`cat /etc/default/docker | grep "$dnsSettings"` 

    if [[ -z $search ]];then
        echo $dnsSettings >> /etc/default/docker
    fi
    echo -e "\e[1;32m[已完成]\e[0m";

    
    #检查docker-compose是否安装
    echo -n "检查docker-compose..."

    docker-compose > /dev/null 2>&1
    if [ $? -eq 127 ];then
        echo -ne "\e[1;31m[未安装]\e[0m";
        
        #检查curl命令是否安装
        curl > /dev/null 2>&1
        if [ $? -eq 127 ];then
            #安装curl命令
            sudo apt-get update > /dev/null 2>&1 && sudo apt-get install curl -y > /dev/null 2>&1
        fi
        
        #拉取docker-compose
        curl -L https://github.com/docker/compose/releases/download/1.2.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose;
        chmod +x /usr/local/bin/docker-compose;

        echo -ne "\b\b\b\b\b\b\b\b"
        echo -e "\e[1;32m[已安装]\e[0m";
    else
        echo -e "\e[1;32m[已安装]\e[0m";
    fi
    
    #检查依赖镜像是否已拉取
    echo "检查镜像..."
    #需要拉取的镜像
    images=`cat $RELATIVE_IMAGES`
    #当前已拉取的镜像
    pulled_images=`docker images | cut -d " " -f1`

    echo "需要拉取以下镜像:"

    #拉取未拉取的镜像
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
    echo "初始化已完成"
}

#历史文件操作:读与写
HistoryFile(){
    #检查参数
    if [[ -z $1 ]];then
        echo "历史文件操作参数为空"
        return -1
    fi
    
    #检查历史文件
    if [ ! -e $HISTORY_FILE ];then
        echo ""
        touch $HISTORY_FILE
    fi
    
    case $1 in 
        "read")
            echo `tac $HISTORY_FILE | sed -n -e "1p" | tac`;;
        "write")
            if [[ -z $2 ]];then
                echo "历史文件写参数为空"
                return -1
            fi
            echo $2 >> $HISTORY_FILE;;
    esac 
}

#历史文件操作：读和写的单元测试
TestHistoryFile(){
    #空参数测试
    HistoryFile
    if [ $? -eq 0 ];then
        echo "空参数测试失败"
        return -1
    fi
    
    #写测试
    tmp=$HISTORY_FILE
    HISTORY_FILE="/tmp/history.log"
    
    #无参数写测试
    HistoryFile write
    if [ $? -eq 0 ];then
        echo "无参数写测试失败"
        rm $HISTORY_FILE
        HISTORY_FILE=$tmp
        return -1
    fi
    
    #文件测试
    if [ ! -e $HISTORY_FILE ];then
        echo "文件测试失败"
        rm $HISTORY_FILE
        HISTORY_FILE=$tmp
        return -1
    fi
        
    #有参数写测试
    HistoryFile write "server 127.0.0.1"
    if [ ! $? -eq 0 ];then
        echo "有参数写测试失败"
        rm $HISTORY_FILE
        HISTORY_FILE=$tmp
        return -1
    fi
    
    #读测试
    readResult=`HistoryFile read`
    if [ ! $? -eq 0 ] || [[ $readResult != "server 127.0.0.1" ]];then
        rm $HISTORY_FILE
        HISTORY_FILE=$tmp
        echo "读测试失败"
        return -1
    fi

    rm $HISTORY_FILE
    HISTORY_FILE=$tmp
    return 0
} 

#根据mode生成consul镜像命令
GenerateCommand(){
    case $1 in   
        "server")
            echo "-server -join {joinip}";;
        "server-bootstrap")
            echo "-server -bootstrap";;
        "server-bootstrap-expect")
            echo "-server -bootstrap-expect {joinip}";;
        "client")
            echo "-join {joinip}";;
        *)
            echo "{command}";;
    esac
}

#重载节点参数，生成新的yml配置文件
#参数     : [-m]服务器模式 [-j]加入集群IP地址 [-i]自身IP地址 
#[注意1]  : 每一次都将从上一次文件读取参数。未被重载的参数直接继承上一次生成的参数。
#[注意2]  : -m参数为server-bootstrap时，服务器进入bootstrap模式.该模式下[-j]参数被忽略 
#[注意3]  : -m参数为server-bootstrap-expect时，服务器进入bootstrapi-expect模式.该模式下[-j]参数用来读取bootstrap的数目,此时-j参数为必须
Reload(){
    #定义参数数组
    declare -A args
    #读入参数
    while getopts "m:j:i:" arg
    do
        case $arg in
            m) args[mode]=$OPTARG;;
            j) args[joinip]=$OPTARG;;
            i) args[ipaddress]=$OPTARG;;
            *) echo "argument not found!";
                Usage reload;;
        esac
    done
        
    #检验参数数量，必须大于0
    if [ ${#args[*]} -eq 0 ];then
        echo "参数数量为0！";
        Usage reload;
    fi
    
    #从历史文件读取上一次参数
    formerArgs=(`HistoryFile read`)
    
    #如果参数未输入，则使用上一次对应参数
    mode=${args[mode]:-${formerArgs[0]}}
    joinip=${args[joinip]:-${formerArgs[1]}}
    ipaddress=${args[ipaddress]:-${formerArgs[2]}}
    
    
    #新的文件模板
    cp $COMPOSE_MODEL $COMPOSE_FILE

    #如果参数依然为空，使用默认值
    mode=${mode:-'{mode}'}

    #bootstrap模式下，使用ipaddress作为joinip
    if [[ $mode = 'server-bootstrap' ]] || [[ $mode = 'server-bootstrap-expect' ]];then
        sed -i "s/{joinip}/{ipaddress}/" $COMPOSE_FILE
    fi
    joinip=${joinip:-'{joinip}'}
    ipaddress=${ipaddress:-'{ipaddress}'}

    HistoryFile write "$mode $joinip $ipaddress"
    
    #mode参数转化为command
    mode=`GenerateCommand $mode`
    
    
    #填充模板
    sed -i "s/{hostname}/$HOSTNAME/g" $COMPOSE_FILE
    sed -i "s/{command}/$mode/g" $COMPOSE_FILE
    sed -i "s/{joinip}/$joinip/g" $COMPOSE_FILE
    sed -i "s/{ipaddress}/$ipaddress/g" $COMPOSE_FILE
    
    echo "填充模板完成"
}

#开启服务器节点
Start(){
    #读取上一次填充的参数
    args=(`HistoryFile read`)
    mode=${args[0]}
    joinip=${args[1]}
    ipaddress=${args[2]}
    #检查参数
    if [[ -z $mode ]] || [[ $mode = '{command}' ]];then
        echo "节点mode尚未设置"
        exit -1
    fi
    
    if [[ -z $ipaddress ]] || [[ $ipaddress = '{ipaddress}' ]];then
        echo "节点ip地址尚未设置"
        exit -1;
    fi
    
    if [[ $mode = 'server' ]] || [[ $mode = 'client' ]];then
        if [[ -z $joinip ]] || [[ $joinip = '{joinip}' ]];then
            echo "当前模式下，节点joinip地址需要设置"
            exit -1
        fi
    fi
    
    if [[ $mode = 'server-bootstrap-expect' ]];then
        if [[ -z $joinip ]] || [[ $joinip = '{joinip}' ]];then
            echo "当前模式下，节点joinip地址需要设置"
            exit -1
        fi
        #简单判断是否为数字
        [ $joinip -gt 0 ] 2>/dev/null 1>&2
        if [ ! $? -eq 0 ] || [ ! `echo $joinip % 2 | bc ` -eq 1 ];then
            echo "当前模式下，节点joinip需要为大于1的奇数"
            exit -1
        fi
    fi
        
    echo "开启节点"
    Stop
    echo y | sudo docker-compose -f $COMPOSE_FILE rm swarm 
    sleep 5m
    docker-compose -f $COMPOSE_FILE up -d consul 
    docker-compose -f $COMPOSE_FILE up -d registrator 
    docker-compose -f $COMPOSE_FILE up -d swarm 
}

#关闭并删除服务器节点容器
Stop(){
    docker-compose -f $COMPOSE_FILE stop
}

#刷新服务器服务缓存
#因为consul不会把突然断连的节点及节点上服务从集群中删除，因此再一次以该节点加入时，上一次节点服务仍然存在，这时需要注销当前节点，再重启服务注册服务
Refresh(){
    #从之前参数中读取consul server地址
    formerArgs=(`HistoryFile Read`)
    mode=${formerArgs[0]}
    if [[ $mode = 'server-bootstrap' ]] || [[ $mode = 'server-bootstrap-expect' ]];then
        consulServer=${formerArgs[2]}
    else
        consulServer=${formerArgs[1]}
    fi
    
    if [[ -z $consulServer ]] || [[ ! -z `echo $consulServer | grep '{' ` ]];then
        echo "joinip或ipaddress尚未设置！"
        exit -1;
    fi
    
    #检查curl是否安装
    curl 2>/dev/null 1>&2
    if [ ! $? -eq 0 ];then
        apt-get update 2>/dev/null 1>&2 && apt-get install curl -y 2>/dev/null 1>&2 
    fi

    curl http://$1:8500/v1/catalog/deregister -d "{\"Node\":\"$HOSTNAME\"}"

    docker-compose -f $COMPOSE_FILE stop registrator
    docker-compose -f $COMPOSE_FILE start registrator
}

#链接ip地址变动监测脚本
Link(){
    ip-change reload "sudo node-action reload -i \$1 && sudo node-action start"
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

Tests(){
    tests=("TestHistoryFile")
    echo "节点操作脚本测试"

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
}


if [[ -z $? ]];then
    Usage "command";
else
    if [[ -z $1 ]];then
        Usage "command";
    else
        case $1 in
            "init") Init;;
            "start") Start;;
            "stop") Stop;;
            "reload") 
                paras=($@)
                paras=${paras[@]:1:6}
                Reload $paras;;
            "refresh") Refresh;;
            "link") Link;;
            "test") Tests;;
            *) Usage "command";;
        esac
    fi
fi
