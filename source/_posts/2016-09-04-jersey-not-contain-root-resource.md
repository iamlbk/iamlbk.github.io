---
layout: post
title: "jersey The ResourceConfig instance does not contain any root resource classes"
date: 2016-09-04 21:17:17 +0800
comments: true
categories: 工具
tags: [java, jersey, restful]
keywords: jersey, the resourceConfig instance does not contain any root resource classes
---

使用jersey框架时遇到了如下错误"The ResourceConfig instance does not contain any root resouce classes". 下面是这个错误的几种解决办法.

1. 确认要发布出去的类被`@Path`注解修饰.
2. 确认这些在类加载路径里.
3. 确认web.xml中配置的包名正确.
4. 这些类需要以class文件的方式放到类路径里, 而不是jar包的方式. 否则可能在Windows上可以正常运行, 到Linux上就无法正常运行了.

ps: 其实官方文档有这方面的描述, 但是目前还没有看出来需要对jar包做怎样的特殊处理. 等试出来之后再添加上来.
