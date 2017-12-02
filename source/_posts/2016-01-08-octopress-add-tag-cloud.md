---
layout: post
title: "为octopress添加标签"
date: 2016-01-08 13:33:03 +0800
comments: true
categories: 工具
tags: [octopress, github page]
keywords: octopress, github page, octopress tag cloud, octopress标签, 定制octopress
---
octopress默认只有分类,没有标签.这让习惯使用三四个分类, 无数个标签管理博客的我很不习惯.
于是在网上找为octopress添加标签的方式. 这篇博客的部分内容参考:《[为octopress添加tag cloud](http://codemacro.com/2012/07/18/add-tag-to-octopress)》.
<!--more-->

## 下载
首先, 下载需要的插件: [octopress-tag-pages](https://github.com/robbyedwards/octopress-tag-pages)和[octopress-tag-cloud](https://github.com/robbyedwards/octopress-tag-cloud). 使用git clone或者直接下载压缩包都行.

## 安装
安装其实很简单, 只需要将下面几个文件复制到octopress中相应的目录中即可:

octopress-tag-pages中的

- plugins/tag\_generator.rb
- source/\_layouts/tag\_index.html
- source/\_includes/custom/tag\_feed.xml

octopress-tag-cloud中的

- plugins/tag\_cloud.rb
- source/\_includes/custom/asides/tags.html(如果需要汉化, 直接修改这里面的内容即可)

例如, 把octopress-tag-pages中的plugins/tag\_generator.rb复制到octopress安装目录下的plugins文件夹中.

最后, 修改\_config.xml中的default_asides, 将custom/asides/tags.html添加进去:
```yaml
default_asides: [custom/asides/category_list.html, custom/asides/tags.html, ...]
```

至此, 已经安装完毕. 可能已经有读者迫不及待的想要看看效果了. 可是执行`rake generate`却发生了错误(这个错误并不是所有人都会遇到)
```plain
Liquid Exception: comparison of Array with Array failed in _layouts/page.html
```

## 排错
### 第一个错误: comparison of Array with Array failed in \_layouts/page.html
我们就是按照文档写的. 那么到底哪里错了? 我们看看刚才安装的两个插件的源码就知道了(没学过ruby没关系, 这两个插件的注释写的很完整, 我也没学过ruby, 但是也大致看得懂这个程序). 在tag_cloud.rb中第74行是这么写的:
```ruby
if @limit > 0 and @sort != 'rand'
    # sort the tag pairs by frequency in descending order
    weighted.sort! { |a,b| b[1] <=> a[1] }

    # then slice off the top @limit tag pairs
    weighted = weighted[0,@limit]
end
```
`weighted = weighted[0,@limit]`应该就是取指定数目的标签. 如果你的标签数量少于`@limit`, 那么就会报错. 所以我们修改第74行为:
```ruby
if @limit > 0 and @sort != 'rand' and @limit < weighted.length
```
同样的, 将第95行修改为:
```ruby
if @limit > 0 and @limit < weighted.length
```
这时再执行`rake generate`就不会报错了. 但是又出现了几条警告:
```plain
Build Warning: Layout 'nil' requested in tags/github page/atom.xml does not exist.exist.
```
### 又一个警告:Layout 'nil' requested in tags/标签名/atom.xml does not exist.
这个警告让人很摸不着头脑, 而且并不影响使用, 但是让人感觉很不爽, 所以继续在源码中查找问题.
然后无意间发现tag_generator.rb中的代码结构和category_generator.rb中的代码结构一模一样. 
而category_generator.rb是用来生成类别信息的. 那么为什么生成类别信息时没有警告, 而生成标签信息时就会有警告呢?
仔细对比之后也没有发现什么问题. 后来发现tag_generator.rb中加载了我们安装时复制过来的tag_feed.xml文件. tag_feed.xml里面有这么一句话:
```yaml
layout: nil
```
而category_generator.rb加载了category_feed.xml文件. category_feed.xml里面对应的位置是:
```yaml
layout: null
```
是不是这里呢? 改过来试试吧. 好吧, 就是这里.

### 基本不会遇见的问题
到现在侧边栏的标签已经能正常使用了. 但是, 如果你跟我一样, 刚刚开始使用octopress, 只有一两篇博客, 而且所有的标签的博客数量都一样, 那么就会发现左侧的标签的源码是这样:
```html
<a style="font-size: NaN%" href="/tags/github-page/">github page</a>
```
这并不影响使用, 而且相当的罕见. 所以我们直接说解决方案吧.
将tag_cloud.rb第69行改为:
```ruby
if max == min
  weight = (100 - size_min) / (size_max - size_min)
else
  weight = (Math.log(count) - Math.log(min))/(Math.log(max) - Math.log(min))
end
```
这时就可以正常使用了.

## 配置
### 中文化
如果用户点击边栏上的标签, 会跳转到标签页. 而标签页的默认标题为:`Tag: 标签名`. 
如果想将其中的"Tag:"换成中文的, 可以在\_config.yml中添加下面的内容:
```yaml
tag_title_prefix: "标签--"
```
重新生成一下, 标题就会变成`标签--标签名`

### 配置边栏中标签的数量
[octopress-tag-cloud][]的文档上说可以使用limit限制显示标签的数量(刚开始遇到的错误也是因为配置的limit太大了造成的). 直接修改source/\_includes/custom/asides/tags.html中的limit后面的数字即可:
```plain
{% tag_cloud font-size: 60-165%, limit: 15 %}
```
### 在文章列表中显示标签
效果如图:
{% img center /images/2016/01/archives-list-tags.png %}
将octopress-tag-pages插件中的source/\_includes/archive\_post.html复制到octopress中的source/\_includes/目录下, 该文件本来已经有了, 直接覆盖就可以.

或者如果你已经修改过octopress中的source/\_includes/archive\_post.html文件了, 那么可以参考插件中的文件, 直接将
```plain
&#123;% if tag != '0' %}
  <span class="tags">tagged with &#123;{ post.tags | tag_links }}</span>
&#123;% endif %}
```
复制到octopress下的文件中的特定位置即可.

### 在博客下面或者上面显示标签
还是先上个图:
{% img center /images/2016/01/archives-tags.png %}
参考octopress-tag-pages插件中的source/\_layouts目录中的post.html, 修改octopress下的post.html, 比如我的post.html中相应的部分是这样的:
```plain
<p class="meta">
    &#123;% include post/categories.html %}
    &#123;% include post/tags.html %}
    <br/>
    &#123;% include post/author.html %}
    &#123;% include post/date.html %}
    &#123;{ time }}
    &#123;% if updated %} 
        &#123;{ updated }}
    &#123;% endif %}
</p>
```

