# cluster
节点操作脚本与IP地址自动检测变动脚本

###下载
[github download](https://github.com/windworship/cluster/archive/master.zip)

###使用脚本初始化并开启一个集群节点
下列命令初始化并开启了一个**server-bootstrap**集群节点，其他模式请参照之后的命令说明修改
```bash
  #安装命令并初始化脚本
  cd [download path]    
  sudo ./install.sh   
  sudo node-action init
  
  #重载节点参数并与ip自动检测脚本链接
  sudo node-action reload -m server-bootstrap   
  sudo node-action link
  
  #ip自动检测脚本在crontab定时任务中注册
  sudo ip-change cron
  
  #开启crontab定时任务
  sudo service cron start   
```
至此节点已经初始化完成并开启，一个每分钟自动执行的定时任务会侦测节点ip地址变动并自动使用新ip地址重新启动整个节点

###命令

####node-action

#####init

初始化节点环境。包括检查docker是否安装，docker的dns服务器设置与开放端口，docker-compose是否安装，以及依赖镜像是否拉取。

```bash
  sudo node-action init
```

#####reload

重载命令。重载节点环境参数，包括运行模式，加入集群主服务器ip地址，节点ip地址。

```bash
  sudo node-action reload -m server -j 172.16.xxx.xxx -i 172.16.xxx.xxx
```

同样可以使用该命令一次重载一个参数。

```bash
  sudo node-action reload -m server-bootstrap
```

脚本保存了每次重载的参数，意味着在这一次命令中你没有重载的参数将会自动继承上一次它的值。

参数：

- **[-m]** 运行模式
  - **server** 加入服务器模式，加入集群并成为其中一个主服务器节点
  - **client** 客户端模式，加入集群
  - **server-bootstrap** bootstrap服务器模式，创建一个集群并立即开启
  - **server-bootstrap-expect** bootstrap-expect服务器模式，创建一个集群但是只有当集群中主服务器节点达到expect数量时才会开启集群    

> **NOTICE**    
> 在一个consul集群中，主服务器节点数量必须为**奇数**，否则集群将会等待，因为无法投票选出一个领导节点   

- **[-j]** 加入集群的其中一个主服务器地址

> **NOTICE**    
> 1. 在加入服务器模式与客户端模式中，这个参数是必须的   
> 2. 在bootstrap服务器模式中，这个参数将被忽略   
> 3. 在bootstrap-expect服务器模式中，这个参数被用来传递expect数量，换言之你这时应该使用一个**奇数**重载它 

- **[-i]** 节点的ip地址

#####start

开启节点服务器。每一次使用reload命令重载参数，这些参数都被用来生成一个docker-compose文件，该文件在此时使用。为了允许重载一个参数而不是多个参数的实现，我们在**这个命令**才进行了参数的检验，这也意味着你必须在这条命令之前给出了选定模式下的**指定格式的所有参数**。

```bash
  sudo node-action start
```

同时docker-consul有一个奇怪的地方，当你重启这个容器时，如果在停止后3min内开启，那么容器会拒绝所有外来网络消息，也就无法加入集群。我们强制在start命令中加入了5min的限制，因此，命令实际上是在你执行后的5min才开启整个节点。

#####stop
停止节点服务器。节点服务器的容器依然存在。

```bash
  sudo node-action stop
```

#####refresh
用于刷新服务缓存。consul集群对于强制退出的节点并不会删除，而是会标记一个特殊状态并保存注册的所有服务信息。当我们使用新参数重启节点时，可能会导致之前注册的服务与现在注册的服务累积的现象(尽管是同一个服务，却可能重复十几次)。命令向加入集群的主服务器节点发送消息注销节点，重启registrator服务使节点及服务重新在集群中注册，因此**确保此时参数中的主服务器节点是可用的**

```bash
  sudo node-action refresh
```

#####link
用于链接ip地址自动检测脚本。使用自动检测脚本开放的接口，写入ip地址自动变化后的执行命令，即重载节点ip地址参数并重启整个节点。

```bash
  sudo node-action link
```

#####test
节点单元测试，目前仅有历史文件的读写测试。

```bash
  sudo node-action test
```

####ip-change

#####listen
获取当前ip地址并与之前的ip地址比较，如果ip地址变动则自动执行指定脚本。
```bash
  sudo ip-change listen
```

#####reload
使用指定内容写入执行脚本。脚本在ip地址变动时被调用.脚本在执行时被传入了当前ip地址的参数。
```bash
  sudo ip-change reload "sudo node-action reload -i $1 && sudo node-action start"
```

#####cron
向crontab定时服务中注册当前命令，为每分钟一次。
```bash
  sudo ip-change cron
```

#####test
脚本的单元测试
```bash
  sudo ip-change test
```
