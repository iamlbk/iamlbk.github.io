---
layout: post
title: "ssh免密码登录"
date: 2016-02-10 13:00:57 +0800
comments: true
categories: 工具
tags: [ssh, linux]
keywords: ssh, ssh免密码登录, hadoop安装ssh免密码登录
---

由于最近在学习hadoop, 需要ssh免密码登录, 所以学习了一下ssh免密码安装. 在这里记录一下ssh免密码登录的方法和使用场合.

## 单机免密码登录
如果要ssh免密码登录本机, 比如是伪分布模式安装hadoop的话, 就需要ssh免密码登录本机. 那么我们可以使用如下的方式实现免密码登录:
```bash
ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''            # 生成公私钥
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys     # 共享授权密钥
chmod 600 ~/.ssh/authorized_keys                    # 修改文件权限
```
<!--more-->

### 命令的解释

第一行, 使用`ssh-keygen`生成公私钥.  `-t rsa`指定生成公私钥的算法为rsa. `-f ~/.ssh/id_rsa`指定生成的公私钥存放的文件路径, 其中id_rsa存放的是私钥, id_rsa.pub存放的是公钥. `-P ''`指定密码为空.

第二行就不再解释了.

第三行是因为如果authorized_keys文件的权限允许所有者之外的人修改, 那么这个文件中的内容并不起作用. 也就是所有组和其他人都不能拥有写权限, 个人建议权限设置成600. 由于初始时没有authorized_keys文件, 如果authorized_keys文件是由重定向生成的, 那么权限很可能大于644, 所以这里手工修改一下文件权限.

### 安全性
在生成公私钥时不指定密码确实不是很安全. 例如, 如果有人登录到你的系统, 就可以免密码登录到所有经过授权的机器(这里是本机). 如果有人拿到了你的私钥, 那么也可以免密码登录到所有经过授权的机器. 

但是由于这里是登录本机, 基本上也就不存在安全问题了: 都已经登录到这台机器了, 再ssh登录这台机器也没有多大的意义; 同样, 如果都拿到私钥了, 那么应该也是登录过这台机子了. 而且还有一点是, 这很可能是在开发环境中, 那么对安全性的要求可能就没有那么高了, 而对便利性的要求可能会较高.

## 一台主机到多台主机免密码登录
这里我们假设我们有四台机器, 主机名分别为: master, slave1, slave2, slave3. 我们的目的是从master免密码登录到slave1-3主机上.
### 生成公私钥
如果还是用上面的方式生成公私钥. 如果有人登录了master主机, 那他就可以免密码登录到所有的slave主机上. 同样如果他拷贝走master上的私钥, 也可以免密码登录到所有的slave主机上. 所以这里建议设置密码. 生成公私钥的命令如下:
```bash
ssh-keygen -t rsa -f ~/.ssh/id_rsa
``` 
当提示输入密码时, 输入一个密码即可. 下面我们把生成公私钥时输入的密码简称ssh密码.
### 共享公钥
这里我们先使用`ssh-copy-id`完成共享公钥. 在master主机上执行如下命令:
```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub slave1
```
其中`-i ~/.ssh/id_rsa.pub`指定我们需要共享的公钥文件. slave1为主机名, 也可以写成对应的ip. 执行这条命令时, 需要输入slave1主机上对应账号的密码.
之后我们就可以使用ssh密码登录slave1了. 为了免密码登录, 需要为每一个需要免密码登录的主机都执行一次这条命令.
### 配置记住密码
为了记住密码, 我们需要在master主机中的~/.bash_profile中添加如下的命令:
```bash
eval `ssh-agent`
ssh-add
```
其中第一行是启动ssh-agent服务. 该服务的作用范围为当前shell. 第二行是把专用密钥添加到ssh-agent的高速缓存中. 需要注意的是, 在执行`ssh-add`时需要输入ssh密码, 所以在开机输入用户名、密码登录后还会提示输入ssh密码. 如果觉得烦人, 可以在以后手动执行`ssh-add`.

到这里我们就可以在**这个shell**中免密码登录slave1-3了. 可以使用`ssh slave1`登录slave1试试, 如果还需要密码, 说明配置有一些问题. 可以在仔细看看上面的步骤.

如果需要多台主机到多台主机免密码登录, 那么只需要在多台主机间相互共享公钥就行了. 都配置好记住密码就行了.
### 安全性
我们假设有两个shell: tty1, tty2. 其中tty1上在登录过以后输入了ssh密码. 而tty2上在登录过没有输入ssh密码. 那么在tty2上登录slave1-3时还是需要输入ssh密码的. 所以, 即使有人登录到master主机上, 不知道ssh密码也是不能免密码登录到slave1-3主机的. 同样的, 就算拷贝走私钥, 也没有用. 所以这样是安全的.

## 其他共享公钥的方式
在上面我们是使用`ssh-copy-id`共享公钥的, 但是当主机很多时, 做好做对这件事将是一个很大的挑战; 当要修改密码, 重新生成公私钥时还得同步所有的公钥... 

为了更加方便, 我们可以这样做:

在一台机器上创建好用户主目录, 然后生成公私钥, 然后将公钥添加到本机的授权文件中. 比如:
```bash
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
```
接着将该用户的主目录设置为nfs共享. 最后其他的主机都不使用自己的主目录, 而是挂载刚才共享的主目录. 那么就可以非常方便的共享公钥了. 具体步骤如下
### 创建nfs共享
在一(多)台机器上生成公私钥. 然后创建nfs共享. 修改`/etc/exports`文件. 添加如下内容:
```plain
/home/hadoop    192.168.45.0/24(rw,sync)
```
个人建议最少在两台机器上生成公私钥, 然后创建nfs共享. 这样万一其中一台由于网络等原因无法挂载时, 可以使用另外一台机器上的数据. 如果有多台机器, 那么需要注意同步数据.

### 自动挂载nfs共享
这里应该是可以直接在`/etc/fstab`中添加挂载点的. 但是autofs更加适合这里的情况, 所以我们使用autofs.

首先我们安装autofs. 然后修改`/etc/auto.master`, 添加如下内容:
```
/home/remoteuser    /ect/auto.remoteuser
```
其中`/home/remoteuser`是需要挂载的父级目录, `/ect/auto.remoteuser`是具体配置文件的位置.
接下来, 我们需要编辑`/ect/auto.remoteuser`(这个文件原本没有, 需要手工创建). 添加如下内容:
```
hadoop  -fstype=nfs,rw,soft,intr    nfsserver1,nfsserver2:/home/hadoop
```
其中`hadoop`是挂载点的最后一级目录, `/home/remoteuser/hadoop`就是最终的挂载点.
`-fstype=nfs,rw,soft,intr`是相应的选项.
`nfsserver1,nfsserver2:/home/hadoop`中的`nfsserver1`和`nfsserver2`是nfs共享的主机名,`/home/hadoop`是共享的目录.更加灵活的配置方式可以参见`man 5 autofs`

之后再修改用户的主目录为`/home/remoteuser/hadoop`. 接下来, 在任意的主机上使用`ssh-add`添加过密码后, 就可以在该主机该shell上免密码登录所有的主机了.
