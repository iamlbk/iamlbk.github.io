---
layout: post
title: "java多线程中变量的可见性"
date: 2016-01-09 18:52:48 +0800
comments: true
categories: "编程语言"
tags: [java, 多线程]
keywords: java多线程, 变量可见性, 生产者消费者
---

之所以写这篇博客, 是因为在csdn上看到一个帖子问的就是这个问题. 废话不多说, 我们先看看他的代码(为了减少代码量, 我将创建线程并启动的部分修改为使用方法引用).
<!--more-->
## 源程序
```java
public class ProductAndComsuer {

    private int i = 0;
    private Object lock = new Object();  //锁
    private boolean created = false;   //用以判断是否有产品被消费

    public void create(){
        while(true){
            if(!created){  //说明没有产品了，需要生产
                synchronized(lock){
                    System.out.println(Thread.currentThread().getName() + ":生产线程-->" + i++);
                    created = true;
                    System.out.println("created-->" + created);
                }
            }
        }
    }

    public void consume(){
        while(true){
            if(created){
                synchronized(lock){
                    System.out.println(Thread.currentThread().getName() + ":消费线程-->" + i);
                    created = false;
                    System.out.println("created-->" + created);
                }
            }
        }
    }

    public static void main(String[] args) {
        final ProductAndComsuer pClass = new ProductAndComsuer();
        new Thread(pClass::create).start();
        new Thread(pClass::consume).start();

    }

}
```
这是学习多线程非常典型的生产者消费者. 那么这段代码有问题吗? 
为什么输出几行以后就不动了呢?是死锁了吗? 
这里我们先复习一下死锁的定义和产生条件.
> 死锁是指两个或两个以上的进程在执行过程中，由于竞争资源或者由于彼此通信而造成的一种阻塞的现象，若无外力作用，它们都将无法推进下去。

而出现死锁必然满足四个条件:

- 互斥条件.
- 请求和保持条件
- 不剥夺条件
- 环路等待条件

再看看这个程序, 第二条就不满足: 一个线程同一时间只会处于保持锁或者请求锁的状态, 
根本就没有出现请求和保持同时出现的情况. 换(shuo)句(ju)话(ren)说(hua), 这里只有一个锁, 怎么可能发生死锁呢?
要证明这一点很简单, 只需要在两个线程的`while`和`if`之间加一句打印的语句就知道了. 比如`create`方法中:
```java
while(true) {
    System.out.println("create方法, created=" + created + ", 是否满足条件?" + (!created) );
    if(!created) {
        synchronized(lock) {
            // 为了方便查看信息, 这里的输出语句注释掉
            // System.out.println(Thread.currentThread().getName()+":生产线程-->"+i++);
            created = true;
            // System.out.println("created-->"+created);
        }
    }
}
```
在编译运行程序, 就会发现程序并没有死锁, 那么为什么程序就是不执行同步块中的程序呢? 仔细看一下刚才程序的输出就知道原因了
```plain
create方法, created=true, 是否满足条件?false
create方法, created=true, 是否满足条件?false
consume方法, created=false, 是否满足条件?false
consume方法, created=false, 是否满足条件?false
```
我们发现不管是`create`方法还是`consume`方法, 都不满足进入`if`语句的条件. 怎么会这样呢? `create`方法明明将`created`赋值为`true`了.
其实, 单独看`create`方法和`consume`方法是看不出问题的. 这两个方法很正确. 问题其实是出在多线程中变量的可见性上.
在《[JAVA并发编程实践](http://book.douban.com/subject/2148132/ )》(点击查看豆瓣评价)3.1节中说:
> 在没有同步的情况下, 编译器, 处理器, 运行时安排操作的执行顺序可能完全出人意料. 在没有进行适当同步的多线程程序中, 尝试推断那些"必然"发生在内存中的动作时, 你总是会判断错误.

换句话说, 即使`create`方法将`created`赋值为`true`, 如果没有适当的同步, 那么`consume`方法中看见的**可能**还是以前的`false`. 
同样, `create`方法看到的也可能是以前的值. 结果, 两个方法就都无法进入自己的`if`语句块了.

更糟糕的是, 过期情况并不一定会马上发生, 也不一定会发生在所有的变量上, 当然也不会完全不出现. 所以就有可能被忽略. 

要解决这个问题, 其中一个方法是使用`volatile`关键字修饰`create`字段. 那么`volatile`关键字是干什么的呢? 上面也说了, 过期情况只会发生在没有适当同步的多线程程序中. 
说道同步, 首先想到的应该就是加锁了吧. 但是加锁的开销太大, 
而且不合适的锁会导致基本上线性执行的多线程程序(就像这个例子中的程序). 那么有没有其他的方法呢? 那就得靠`volatile`了.

《[JAVA并发编程实践][java-concurrency-in-practice]》中是这样说的:
> Java语言也提供了其他的选择, 及一种同步的弱形式: volatile变量. 它确保对一个变量的更新会以可预见的方式告知其他的线程.<br/>
...<br/>
所以, 读一个volatile类型的变量时, 总会返回由某一线程所写入的最新值.

也就是说, 我们只需要将`create`变量的声明前添加`volatile`关键字即可解决问题:
```java    
private volatile boolean created = false; 
```

另外, 需要注意《[JAVA并发编程实践][java-concurrency-in-practice]》里面还说到:
> 当验证正确性必须推断可见性问题时, 应该避免使用volatile变量. 正确使用volatile变量的方式包括: 用于确保他们所引用的对象状态的可见性, 或者用于标示重要的生命事件(比如初始化或者关闭)的方法

也就是说, `volatile`虽好, 但不能到处随意的使用. 可能是因为`volatile`容易用错, 所以这个关键字比较低调, 很多地方都没有提过这个关键字. 简单的说, 因为`volatile`不能提供原子性, 所以使用`volatile`的变量的所有读取/修改必须是原子修改, 比如`x++`就不是, 因为是先读取又写入. 这里我们就不深入说了, 要了解更多信息可以翻翻《[JAVA并发编程实践][java-concurrency-in-practice]》或者看看这篇"文档"《[Java 理论与实践: 正确使用 Volatile 变量][java-volatile]》.

最后, 我们再说说如何使用同步块解决这个问题. 其实很简单, 只需要将同步块和`if`语句对调即可:
```java
 private int i = 0;
    private Object lock = new Object();  //锁
    private boolean created = false;   //用以判断是否有产品被消费

    public void create(){
        while(true){
            synchronized(lock){ // 先加锁, 再判断
                if(!created){
                    ...
                }
            }
        }
    }

    public void consume(){
        while(true){
            synchronized(lock){
                if(created){
                    ...
                }
            }
        }
    }
```

[java-concurrency-in-practice]:http://book.douban.com/subject/2148132/ JAVA并发编程实践
[java-volatile]: http://www.ibm.com/developerworks/cn/java/j-jtp06197.html Java 理论与实践: 正确使用 Volatile 变量
