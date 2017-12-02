---
layout: post
title: "发送短信(一):同步/异步发送短信"
date: 2016-02-19 12:52:11 +0800
comments: true
categories: 编程语言
tags: [发送短信, java]
keywords: java, 发送短信, WebService, 短信服务接口
---

本篇本章是发送短信的第一部分, 说一下同步/异步发送短信的代码, 以后几篇我们稍微完善一下功能, 添加发送频率的限制和日发送次数的限制.

发送短信的方法可能不少, 我们的方法是使用服务商提供的服务. 一般来说, 这些服务都是和语言无关的, 这里我们使用java写示例程序.

<!--more-->

## 发送短信的接口
 这里我们介绍一些服务商:

- 互亿无线: http://www.ihuyi.com/
- 容联云通讯: http://www.yuntongxun.com/
- 其他发送短信的接口可以在Api Store上查找: http://apistore.baidu.com/ .比如搜索"短信": http://apistore.baidu.com/astore/servicesearch?word=%E7%9F%AD%E4%BF%A1&searchType=null

可以都看看, 根据自己的情况选择其中的一款. 这里我使用的是互亿无线, 只是因为我最开始只知道互亿无线, 使用的也是它.

## 开发文档
使用这些服务商提供的服务首先得先看开发文档. 文档在这里下载: http://h.ihuyi.com/bbs/thread-36-1-1.html . 主要的文档如下

- 开发说明及常见问题: 简单的开发教程
- 接口文档--必须看: 开发文档
- DEMO: 该文件夹下的子文件夹是示例, 以语言命名

从开发文档中我们可以看到. 可以直接使用http请求也可以使用WebService请求发送短信. 由于DEMO文件夹下的java和jsp文件夹中的代码都是使用http请求发送短信. 所以这里就不再细说了, 我们使用WebService的方式演示发送短信.

## 生成客户端代码
从接口文档中我们知道它的WebService的WSDL的url为: http://106.ihuyi.cn/webservice/sms.php?WSDL
那么我们可以执行下面的命令生成客户端代码:

```bash
wsimport -keep http://106.ihuyi.cn/webservice/sms.php?WSDL
```

其中`wsimport`是JDK自带的工具, `-keep url`选项是"保留生成的文件". 该命令会在当前目录下生成`sms.cn.ihuyi._106`包, 以及众多的类.
接下来开始编写我们自己的代码.

## 定义接口
为了方便, 这里我们首先定义一个接口:

```java
public interface Sms {
    /**
     * 向mobile发送短信, 内容为message
     * 
     * @param mobile  手机号
     * @param message 短信内容
     * @return 成功返回-1, 否则返回其他值
     */
    int sendMessage(String mobile, String message);
}
```

这个接口很简单, 只有一个方法. 这个方法用来发送短信. 

## 同步发送短信
接下来我们首先实现一个同步发送短信的类:

```java
public class IhuyiSmsImpl implements Sms {
  
    private String account;
    private String password;

    public void setAccount(String account) {
        this.account = account;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    @Override
    public int sendMessage(String mobile, String message) {
        cn.ihuyi._106.Sms factory = new cn.ihuyi._106.Sms();
        SmsSoap smsSoap = factory.getSmsSoap();
        SubmitResult submit = smsSoap.submit(account, password, mobile, message);
        int code = submit.getCode();
        if(code == 2){
            return -1;
        }  
        System.out.println("发送短信失败, code:" + code);
        return code;
    }
}
```

在第17行, 我们获得远程对象的一个代理对象. 之后就可以通过这个代理对象进行发送短信, 查询账户余额等操作.

第18行, 使用该代理对象的submit方法提交了短信内容. 该方法的参数信息及返回值含义在接口文档中有详细的说明.

第19行我们获得了结果的状态码. 根据文档上的说明, 状态码为2说明提交成功. 简单起见, 这里我们只关注提交成功的情况. 需要注意的是, 状态码为2只是说明提交成功. 根据官网上的"3-5秒内响应、100%到达", 我们可以推测.
如果提交成功, 那么基本上3-5秒内,短信就会发送成功, 根据用户的网络情况, 可能稍有延迟用户就可以收到短信.

使用这段代码发送短信也很简单, 直接`new`一个对象, 设置好账号和密码就可以发送短信了.

## 异步发送短信
由于发送短信涉及到网络通信, 因此`sendMessage`方法可能会有一些延迟. 为了改善用户体验, 我们可以使用异步发送短信的方法. 原理很简单: 如果用户请求发送短信, 我们不是直接调用`IhuyiSmsImpl`的`sendMessage`方法, 而是将请求保存起来(生产者), 然后告诉用户: 短信发送成功. 之后有若干个消费者取出任务, 调用`sendMessage`方法发送短信. 

这里, 我使用线程池完成上面的任务:

``` java
public class AsyncSmsImpl implements Sms {
    public Sms sendSms;
    private ExecutorService executorService = Executors.newFixedThreadPool(3);

    public void setSendSms(Sms sendSms) {
        this.sendSms = sendSms;
    }

    @Override
    public int sendMessage(String mobile, String message) {
        try {
            executorService.submit(() -> sendSms.sendMessage(mobile, message));
        }
        catch(Exception e) {
            Sysemt.out.println("提交任务时发生错误" + e);
            return 0;
        }
        return -1;
    }

    public void destroy(){
        try{
            executorService.shutdown();
        }
        catch(Exception e){}
    }
}
```

代码很简单, 直接将`Sms`接口的`sendMessage(mobile, message)`方法作为一个任务加到线程池的任务队列中. 这样等到有空闲线程时, 就会执行`sendSms.sendMessage(mobile, message)`发送短信. 这里我们假设只要保存到线程池就可以成功发送短信. 因为发送失败的情况实际上很罕见.

到这里同步/异步发送短信就算是完成了, 代码可以在[这里](/downloads/code/2016/02/sms1.zip "下载源码")下载. 接下来的几篇我们看看一些常见的限制的实现, 比如: 一分钟只能发1次, 一天只能发送5次等.

发送短信文章:

- [发送短信--同步/异步发送短信](/blog/20160219/sms-java-code-1/ "发送短信--同步/异步发送短信"): http://www.iamlbk.com/blog/20160219/sms-java-code-1/
- [发送短信--限制发送频率](/blog/20160219/sms-java-code-2/ "发送短信--限制发送频率"):  http://www.iamlbk.com/blog/20160219/sms-java-code-2/
- [发送短信--限制日发送次数](/blog/20160219/sms-java-code-3/ "发送短信--限制日发送次数"): http://www.iamlbk.com/blog/20160219/sms-java-code-3/
