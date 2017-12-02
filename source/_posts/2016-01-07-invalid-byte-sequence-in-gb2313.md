---
layout: post
title: "使用Octopress搭建博客时遇到invalid byte sequence in GB2313的解决办法"
date: 2016-01-07 09:33:03 +0800
comments: true
categories: 工具
tags: [octopress, github page]
keywords: octopress, github page, invalid byte sequence in gb2313
---

我是参考《[windows7上面使用Octopress搭建GitHub博客](http://yidao620c.github.io/2015/03/18/octopress-blog.html)》和《[Octopress安装和配置](http://www.jianshu.com/p/1a117ef0e534)》搭建自己的Github博客的.基本上是大事没有,小事不断.其中出现次数最多的是编码问题:
```plain
Liquid Exception: invalid byte sequence in GB2312
```
或者
```plain
jekyll 2.5.3 | Error:  invalid byte sequence in GB2312
```
<!-- more -->

我的错误信息在这个时候出现的: 按《[windows7上面使用Octopress搭建GitHub博客](http://yidao620c.github.io/2015/03/18/octopress-blog.html)》上的步骤, 到中文化的时候, 修改source/\_includes/custom/navigation.html和source/\_includes/custom/footer.html时都没有问题, 但是修改source/\_includes/asides/recent\_posts.html之后就会出现该错误信息.

上网查了N多解决办法,无奈大多数都是针对jekyll 1.4.x版本的, 而我的是2.5.3, 基本没有用, 最后在《[ruby中in `split': invalid byte sequence in UTF-8 (ArgumentError)解决方法](http://blog.csdn.net/jiedushi/article/details/8529110)》上看到了这样一段话:
>将arr=arr = url.split("&")修改为<br/>
arr = url.force_encoding("gb2312").split("&")  即可

就抱着最后一次的心态试了一下, 使用`rake generate --trace`生成页面, 后面的`--trace`是用来打印错误的堆栈信息的. 最后发现错误是在"ruby安装目录\lib\ruby\gems\1.9.1\gems\liquid-2.6.3\lib\liquid\template.rb"的第147行发生的. 然后按照《[ruby中in `split': invalid byte sequence in UTF-8 (ArgumentError)解决方法](http://blog.csdn.net/jiedushi/article/details/8529110)》上面的说法, 将
```ruby
tokens = source.split(TemplateParser)
```
改成
```ruby
tokens = source.force_encoding("gb2313").split(TemplateParser)
```
错误依旧...

然后猛然间发现人家提示的是"invalid byte sequence in utf-8", 而我的提醒的是"invalid byte sequence in GB2313", 所以改成
```ruby
tokens = source.force_encoding("utf-8").split(TemplateParser)
```
问题成功解决.我没学过ruby, 但是看这个路径修改的应该是ruby系统或者是ruby某个库的系统文件代码, 这并不是一个好习惯. 但也只能这样做了.

ps: 今天写这篇博客时, 为了还原"现场", 又将那行改了回去:
```ruby
tokens = source.split(TemplateParser)
```
然后惊奇的发现, 又没有问题了...这是个未解之谜.
