---
layout: post
title: "tomcat配置https访问方式"
date: 2016-07-31 08:56:23 +0800
comments: true
categories: 工具
tags: [tomcat, https]
keywords: tomcat, https, 证书
---

由于项目需要, 学习了一下tomcat配置https访问. 这里简单聊一下tomcat配置https访问的步骤. 

## 生成证书
在浏览器通过https访问网站时, 网站需要出示一个证书证明自己的身份. 因此在配置https访问之前, 我们需要生成一个密钥对. 我们为了省事, 只是简单的自己生成一个密钥对.

生成密钥对的命令如下:

```bash
keytool -genkey -alias apple -keyalg RSA -sigalg SHA256withRSA -keysize 1024 -validity 36500 -keystore ./keystore
```

<!--more-->

- keytool是java自带的工具. 可以在%JAVA_HOME%/bin目录里找到.
- \-alias指定证书的别名
- \-keyalg指定密钥算法名称, 这里使用RSA
- \-sigalg指定签名算法名称, 这里使用SHA256
- \-keysize指定秘钥位数
- \-validity指定有效期, 单位为天. 这里指定有效期为36500天, 也就是说大约100年以后会过期.
- \-keystore指定密钥库(也是秘钥存储的位置), 本次存储在当前目录的keystore文件中

输入上面的命令, 回车. 会提示如下内容. (注, 下面'#'号后面为解释)

```bash
输入密钥库口令: # 输入密钥库密码, 输入密码时不会回显.
再次输入新口令: # 重复输入上面的密码, 如果密钥库已经存在, 则没有这一步
您的名字与姓氏是什么?
  [Unknown]: localhost # 使用这个证书的域名或者IP地址
您的组织单位名称是什么?
  [Unknown]: Develop # 随意
您的组织名称是什么?
  [Unknown]: YH # 随意
您所在的城市或区域名称是什么?
  [Unknown]: Beijing # 随意
您所在的省/市/自治区名称是什么?
  [Unknown]: Beijing # 随意
该单位的双字母国家/地区代码是什么?
  [Unknown]: CN # 随意
CN=localhost, OU=Develop, O=YH, L=Beijing, ST=Beijing, C=CN是否正确?
  [否]: y # 如果上面有个地方写错了, 这里不输入内容直接回车, 会让你再重新输入一遍

输入 <apple> 的密钥口令
        (如果和密钥库口令相同, 按回车): # 密钥的口令, 这里使用上面密钥库的口令. 必须和密钥库的口令相同
```

提示输入名字与姓氏时最好输入域名或者IP, 其他虽然为随意输入, 但是还是建议输入真实的信息

至此, 密钥就已经保存到了前面指定的文件中. 下面我们修改tomcat的配置文件

## 修改tomcat配置
首先修改tomcat/conf/server.xml文件.
将其中port="8443"对应的标签的注释取消掉, 并将密钥文件路径和密码加到配置中. 如下所示:

```xml
<Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
   maxThreads="150" SSLEnabled="true" scheme="https" secure="true"
   clientAuth="false" sslProtocol="TLS" 
   keystoreFile="conf/keystore" 
   keystorePass="123456" 
 />
```

此时如果启动tomcat, 并访问`http://localhost:8443`, 应该出现如下界面:
![首次通过https访问页面](/images/2016/07/tomcat_https_first_visit.png)

这时我们点击"继续浏览此网站(不推荐)。", 即可看到tomcat的首页. 至此tomcat已经支持https方式访问了. 提示证书错误的原因我们后面再说.

## 自动切换为https协议
虽然上面我们已经让tomcat支持https方式访问了. 但是有时候我们还希望用户通过http访问时, 自动切换为https协议. 这个功能也很好实现, 只需要将下面一段xml加入到tomcat/conf/web.xml或者项目的WEB-INF/web.xml文件中即可

``` xml
<security-constraint>
  <web-resource-collection >
    <web-resource-name >SSL</web-resource-name>
    <url-pattern>/*</url-pattern>
  </web-resource-collection>

  <user-data-constraint>
    <transport-guarantee>CONFIDENTIAL</transport-guarantee>
  </user-data-constraint>
</security-constraint>
```

- 如果希望整个tomcat下的所有工程都自动切换为https协议, 那么就需要将上面那段xml放置到tomcat/conf/web.xml文件的`web-app`标签里
- 如果只是希望某个项目能自动切换https协议, 那么修改这个项目的web.xml文件即可

## 一些问题
### 浏览器提示"此网站出具的安全证书不是由受信任的证书颁发机构颁发的"
由于我们的证书只是我们自己生成的, 并没有提交给CA. 因此浏览器会认为我们的证书不安全. 要解决这个问题, 需要从CA机构购买证书. 或者我们可以向12306学习, 将证书导出, 然后交给用户, 让用户将证书加入到"受信任的根证书颁发机构"里即可. 
导出证书的步骤:

![导出证书第一步](/images/2016/07/tomcat_https_export_certy1.png)
![导出证书第二步](/images/2016/07/tomcat_https_export_certy2.png)

安装证书的过程很简单, 这里就不再赘述了. 如果遇到问题, 可以参见12306的安装证书的步骤.

### 浏览器提示"此网站出具的安全证书是为其他网站地址颁发的"
错误信息如下:

![此网站出具的安全证书是为其他网站地址颁发的](/images/2016/07/tomcat_https_domain_error.png)

原因: 生成密钥文件提示"您的名字与姓氏是什么?"时输入的不是域名. 需要重新生成密钥文件, 并重复执行导出, 安装的过程.

### chrome提示"您与xxx之间的连接采用了过时的加密技术。"
虽然SHA-1算法目前尚未发现严重的弱点，但伪造证书所需费用正越来越低。因此浏览器都已经不在建议使用SHA-1算法对证书进行签名了. 解决办法就是使用更为安全的SHA-2. 在生成密钥文件时添加`-sigalg SHA256withRSA`选项即可. 参见[keytool文档](http://docs.oracle.com/javase/7/docs/technotes/tools/windows/keytool.html "keytool文档")

目前还没有从CA机构申请过证书, 流程还不清楚. 等尝试过一次以后, 再更新本博客.

