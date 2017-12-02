---
layout: post
title: "spring事务管理失效的原因"
date: 2016-01-11 15:06:23 +0800
comments: true
categories: 编程语言
tags: [java, spring]
keywords: spring事务, spring事务失效, spring事务无效
---

个人认为, spring的声明式事务是spring让人感觉用的最爽的功能之一. 
可是在有些时候, 我们使用spring的声明式事务时却并没有效果.
是spring的问题吗? 下面我们先大致说明一下spring声明式事务的原理, 然后再分析在什么情况下, spring的声明式事务会失效.
<!--more-->

## 代理模式
我们知道, spring的声明式事务是基于代理模式的. 那么说事务之前我们还是大致的介绍一下代理模式吧. 
其实代理模式相当简单, 就是将另一个类包裹在我们的类外面, 在调用我们创建的方法之前, 
先经过外面的方法, 进行一些处理, 返回之前, 再进行一些操作.
比如:
```java
public class UserService{
    ...
    public User getUserByName(String name) {
       return userDao.getUserByName(name);
    }
    ...
}
```
那么如果配置了事务, 就相当于又创建了一个类:
```java
public class UserServiceProxy extends UserService{
    private UserService userService;
    ...
    public User getUserByName(String name){
        User user = null;
        try{
            // 在这里开启事务
            user = userService.getUserByName(name);
            // 在这里提交事务
        }
        catch(Exception e){
            // 在这里回滚事务
            
            // 这块应该需要向外抛异常, 否则我们就无法获取异常信息了. 
            // 至于方法声明没有添加异常声明, 是因为覆写方法, 异常必须和父类声明的异常"兼容". 
            // 这块应该是利用的java虚拟机并不区分普通异常和运行时异常的特点.
            throw e;
        }
        return user;
    }
    ...
}
```
然后我们使用的是`UserServiceProxy`类, 所以就可以"免费"得到事务的支持:
```java
@Autowired
private UserService userService;    // 这里spring注入的实际上是UserServiceProxy的对象

private void test(){
    // 由于userService是UserServiceProxy的对象, 所以拥有了事务管理的能力
    userService.getUserByName("aa");
}
```

## 哪些情况下spring的事务管理会失效
### `private`方法, `final`方法 和 `static`方法不能添加事务
上面的东西并不难. 那么我们可以从上面知道些什么呢?
首先, 由于java继承时, 不能重写`private`, `final`, `static`修饰的方法. 所以, 所有的`private`方法, `final`方法 和 `static`方法
都无法**直接**添加spring的事务管理功能. 比如下面的代码(完整代码点击[这里][/downloads/code/2016/01/spring-transaction.zip]下载):
```java
/**
 * 保存两个user对象. 添加了spring事务注解
 */
@Transactional
public final void saveErrorFinal(User user1, User user2) {
    UserDao userDao = getUserDao(); // 此处需要使用getUserDao方法. 不能直接使用userDao
    userDao.save(user1);
    System.out.println(10 / 0); // 引发异常
    userDao.save(user2);
}

/**
 * 静态方法. 添加了spring事务注解
 */
@Transactional
public static void saveErrorStatic(UserDao userDao, User user1, User user2) {
    userDao.save(user1);
    System.out.println(10 / 0); // 引发异常
    userDao.save(user2);
}

/**
 * 私有方法保存方法. 添加了spring事务注解
 */
@Transactional
private void saveErrorPrivate(User user1, User user2) {
    userDao.save(user1);
    System.out.println(10 / 0); // 引发异常
    userDao.save(user2);
}
```
测试代码如下:
```java
/**
 * 检验user1是否插入成功, 并尝试删除数据. 如果没有插入, 则报错, 并退出.
 */
private void validateInsertSuccess() {
    User user = userService.getUserByName(user1.getName());
    userService.deleteByName(user1.getName()); // 删除用户数据
    assertNotEquals("插入失败!", -1, user.getId().intValue());
}

/**
 * 检验user1是否插入失败. 如果插入成功, 则删除数据, 并报错.
 */
private void validateInsertFail() {
    User user = userService.getUserByName(user1.getName());
    userService.deleteByName(user1.getName()); // 删除用户数据
    assertEquals("插入成功, 事务没有生效!" + user, -1, user.getId().intValue());
}

@Test
public void testSaveErrorFinal() {
    try {
        userService.saveErrorFinal(user1, user2);
    }
    catch (ArithmeticException e) {}    // 除零异常, 直接忽略
    validateInsertFail(); // 我们假设有事务支持, user1添加失败
}

@Test
public void testSaveErrorStatic() {
    try {
        UserService.saveErrorStatic(userDao, user1, user2);
    }
    catch (ArithmeticException e) {}
    validateInsertFail(); // 我们假设有事务支持, user1添加失败
}
```
由于`saveErrorPrivate`方法外面是无法调用的, 就暂时不去讨论了. 
我们直接看`testSaveErrorFinal`和`testSaveErrorStatic`方法的运行结果:<br/>
![testSaveErrorFinal的运行结果](/images/2016/01/spring-transaction-testSaveErrorFinal.png)
![testSaveErrorStatic的运行结果](/images/2016/01/spring-transaction-testSaveErrorStatic.png)<br/>
很明显, 事务并没有生效. 也就是说`private`方法, `final`方法 和 `static`方法都没有事务支持.

### 没有通过代理对象调用添加事务的方法
仔细看看代理模式中的代码, 就会发现不通过代理对象调用方法也会导致spring事务管理失效.
绕过代理对象最直接的方法就是自己`new`一个对象, 虽然这种可能性非常小:
```java
new UserService().save(user);
```
当然, 前面也说了, 这种可能性非常小. 那么我们看看第二种情况, 这种情况的可能性也不大:
```java
/**
 * 保存两个user对象, 中间产生异常. 验证spring的事务是否可以正常工作
 */
@Transactional
public void saveError(User user1, User user2) {
    userDao.save(user1);
    System.out.println(10 / 0); // 引发异常
    userDao.save(user2);
}

/**
 * 通过{@link #saveError(User, User)}保存数据, 该方法本身并没有添加事务注解. 
 * 而是通过{@link #saveError(User, User)}方法使用事务
 */
public void saveByCallMethod(User user1, User user2) {
    //saveErrorPrivate(user1, user2);  // 或者调用saveErrorPrivate方法
    saveError(user1, user2);
}
```
由于测试的代码基本上和上面一样, 所以这里我们就不贴测试的代码了. 再说一次, 点击[这里](/downloads/code/2016/01/spring-transaction.zip)下载完整代码).
实际上, 上面的`saveByCallMethod`方法还是无法获得spring的事务支持. 因为它的调用堆栈如下图所示(从下向上):</br>
![saveByCallMethod的调用堆栈](/images/2016/01/spring-transaction-saveByCallMethod-stack.png)<br/>
最终结果就是spring的事务管理没有生效. 这是或许你会想了, 那为啥不直接给`saveByCallMethod`方法添加事务支持呢? 所以我说这种情况的可能性也不大.
下面我们再看看事务管理和多线程缠在一起时的情况:
```java
/**
 * 通过创建一个新的线程, 调用{@link #saveError(User, User)}方法来保存用户, 该方法和
 * {@link #saveError(User, User)}方法都添加了事务注解
 */
@Transactional
public void saveByThread(User user1, User user2) {
    new Thread(() -> {
        try {
            Thread.sleep(1000); //耗时操作
            saveError(user1, user2);
        }
        catch (Exception e) {
            e.printStackTrace();
        }
        System.out.println("保存完成");
    }).start();
}
```
测试代码请参见我提供的完整代码.
这样的代码已经有可能了吧? 那么事务管理会生效吗? 我们再看看调用堆栈就知道了.
![saveByThread的调用堆栈](/images/2016/01/spring-transaction-saveByThread-stack.png)<br/>
结果和我们想的一样, spring的事务管理并没有生效.

## 总结
好了, 现在我们来回顾一下, 在那些情况下spring的事务管理会失效:

- `private`方法无法添加事务管理.
- `final`方法无法添加事务管理.
- `static`方法无法添加事务管理.
- 当绕过代理对象, 直接调用添加事务管理的方法时, 事务管理将无法生效.
