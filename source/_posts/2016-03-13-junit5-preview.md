---
layout: post
title: "junit5预览"
date: 2016-03-13 17:49:35 +0800
comments: true
categories: 编程语言
tags: [junit, 单元测试, java]
keywords: junit, 单元测试, junit5
---

junit是最常用的java单元测试框架之一. 目前junit5已经推出了5.0.0 Alpha版, 那么junit5相对于junit4有什么变化呢? 有什么新特性呢? 在这里我们聊一下junit5的变化和新特性.

## 概述
### junit 5主页
在介绍junit 5的新特性之前先给出几个链接. 有兴趣的朋友可以去看看:

- junit 5主页: <http://junit.org/junit5/>
- junit 5用户指南: <http://junit.org/junit5/docs/current/user-guide/>
- junit 5示例: <https://github.com/junit-team/junit5-samples>

<!--more-->
### Java版本
junit 5只支持java 8及以上. 按照《[junit 5用户指南](http://junit.org/junit5/docs/current/user-guide/ "junit 5用户指南")》的说法, junit 5也可以测试低版本jdk编译的java类.

### Maven坐标
junit 5已经不再是单个库了, 而是模块化结构的集合. 所有的模块可以参见《[junit 5用户指南](http://junit.org/junit5/docs/current/user-guide/ "junit 5用户指南")》. 这里我们给出一般情况下需要依赖的junit 5的包的Maven坐标:

Group ID: org.junit <br/>
Artifact ID: junit5-api <br/>
Version: 5.0.0-SNAPSHOT

## 包/类变化

- 注解移动到了`org.junit.gen5.api`包中
- 断言移动到了`org.junit.gen5.api.Assertions`类中
- 假设移动到了`org.junit.gen5.api.Assumptions`类中

## 注解变化

- `@Test`注解已经不再包含任何的属性了.
- `@Before`和`@After`已经删除了, 与之对应的替代注解分别是`@BeforeEach`和`@AfterEach`
- `@BeforeClass`和`@AfterClass`也不存在了, 可以使用`@BeforeAll`和`@AfterAll`代替
- `@Ignore`被`@Disabled`代替
- `@Category`使用`@Tag`代替
- `@RunWith`使用`@ExtendWith`代替
- 更多的信息请参见《[junit 5用户指南](http://junit.org/junit5/docs/current/user-guide/ "junit 5用户指南")》

## 第一个测试方法

下面我们用junit 5编写一个最简单的单元测试:

```java Junit5FirstTest.java
class Junit5FirstTest{
    @Test
    void myFirstTest() {
        assertEquals(2, 1 + 1);
    }
}
```

注意到了吗? 我们的测试类和方法都没有用`public`修饰. 在junit 5中只要测试方法没有用`private`修饰就可以.

## Lambda表达式
由于junit 5需要的jre版本为java 8. 自然就可以在特定地方使用Lambda表达式. 这里我们在断言中使用一次Lambda表达式:

``` java Junit5FirstTest.java
@Test
void testLambda(){
    assertTrue(1 == 1, () -> "1竟然不等于1...");
}
```

我们可以看一下`assertTrue`方法的签名就清楚是怎么回事了:

```java
public static void assertTrue(boolean condition)

// 我们调用的是下面的方法
public static void assertTrue(boolean condition, Supplier<String> messageSupplier)

public static void assertTrue(BooleanSupplier booleanSupplier)

public static void assertTrue(BooleanSupplier booleanSupplier, String message)

public static void assertTrue(boolean condition, String message)

public static void assertTrue(BooleanSupplier booleanSupplier, Supplier<String> messageSupplier)
```
注: 其中的`Supplier`和`BooleanSupplier`都在`java.util.function`包中, 是java 8引入的接口. 这两个接口都是函数式接口, 所以可以使用Lambda表达式简化调用.

## 断言分组
断言分组可以执行一组短信, 之后一起报告. 这样我们或许可以省掉不少的错误信息字符串.

```java
@Test
void testGroup(){
    int[] array = {1, 2};
    assertAll("分组测试失败",
        () -> assertTrue(array.length == 2),
        () -> assertTrue(array[0] == 1),
        () -> assertTrue(array[1] == 2));
}
```

## 异常断言
在junit 4中如果想要判断异常, 就需要在`@Test`注解中添加expected属性或者使用try-catch包裹. 但是try-catch太繁琐, 而有时候第一种方法又不是很合适. 在Junit 5可以使用异常断言解决:

```java
@Test
void testException(){
    assertThrows(Exception.class, () -> {
        throw new NullPointerException();
    });
}
```

## 假设、标签以及禁用测试
在Junit 5中假设使用`org.junit.gen5.api.Assumptions`类中的方法完成, 如果假设的条件没有满足, 那么就会跳过测试方法. `@Tag`注解用来对测试分组, 之后可以方便的指定需要执行那个分组的测试方法. 禁用测试使用`@Disabled`注解实现, 被该注解标注的方法/类将直接跳过执行.

``` java
@Test
void testAssumption() {
    assumeTrue(System.getenv("OS").startsWith("Windows"), "跳过测试");
    // 只有在Windows下才会执行下面的代码
    // 在其他平台下将会跳过该方法, 也不会报错
}

@Test
@Tag("tag1")
void testTag() {
}

@Test
@Disabled
void testWillBeSkipped() {
}
```

## 其他

- 扩展模型: junit 5修改了扩展模型, 新的扩展模型允许类上注册多种扩展.
- 嵌套测试: junit 5中允许在一个测试类中创建一个内部测试类
- 方法参数: junit 5中测试方法可以拥有特定类型的参数, junit将进行依赖注入.

junit 5还有一些有趣的新特性, 这里限于篇幅就不再说了, 感兴趣的朋友可以参见《[junit 5用户指南](http://junit.org/junit5/docs/current/user-guide/ "junit 5用户指南")》.
