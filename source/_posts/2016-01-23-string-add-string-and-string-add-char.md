---
layout: post
title: "java中String+String和String+char的区别"
date: 2016-01-23 15:59:34 +0800
comments: true
categories: 编程语言
tags: [java]
keywords: java String, java, java char, javap
---
今天我们来考虑一个关于java中String的问题:  `"abc" + '/'`和 `"abc" + "/"`的区别. 通过这个例子, 我们可以顺便练习一下JDK工具中javap的用法. 
这个问题是以前在csdn论坛中看到的. 原问题是这样的:
> 把斜杠/当作字符或字符串有什么区别呢？<br/>
一个是当作基本数据类型char，一个是对象String。具体有什么区别呢？<br/>
当作字符效率会更高吗？<br/>
`String str = "abc" + '/';`<br/>
和<br/>
`String str = "abc" + "/";`<br/>

<!--more-->
## 编译器优化
首先大家应该知道, 上面那两句效果是一样的, 因为编译器会把上面那两句都优化成下面的样子:
```java
String str = "abc/";
```
我们可以通过javap证明这一点. 关于javap, 可以参考《[每个Java开发者都应该知道的5个JDK工具](http://www.csdn.net/article/2014-11-20/2822750-5-JDK-Tools-Every-Java-Developer-Should-Know?reload=1)》. 
我们首先创建一个类: `StringOne`, 在主方法中填入下面的代码([下载源码](/downloads/code/2016/01/StringAddString.zip "下载源码")):
```java StringOne.java
String str1 = "abc" + '/';
String str2 = "abc" + "/";
System.out.println(str1 == str2);
```
编译并运行, 输出结果为`true`. 接下来, 该我们的javap登场了, 在命令行中输入下面的命令:
```sh
javap -v -l StringOne.class > StringOne.s
```
然后查看生成的StringOne.s文件. 就会发现其中有这么几行(注：javap生成文件中指令的含义可以参考这几篇博客:《[Java栈和局部变量操作（一）](http://www.cnblogs.com/chenqiangjsj/archive/2011/04/02/2003892.html "Java栈和局部变量操作（一）")》,《[Java栈和局部变量操作（二）](http://www.cnblogs.com/chenqiangjsj/archive/2011/04/03/2004231.html "Java栈和局部变量操作（二）")]》,《[java指令集](http://blog.163.com/hfut_quyouhu/blog/static/7847183520127214559314/ "java指令集")》):
```plain StringOne.s
&#35;2 = String             #20            // abc/
...
&#35;20 = Utf8               abc/
...
0: ldc           #2                  // String abc/
2: astore_1
3: ldc           #2                  // String abc/
5: astore_2
```
说明`str1`和`str2`都引用字符串`"abc\"`.
## 使用javap分析差异
现在我们换一个问法, 下面的代码中`stringAddString`和`stringAddChar`方法有什么区别?
```java StringTwo
public static String stringAddString(String str1, String str2){
    return str1 + str2;
}

public static String stringAddChar(String str, char ch){
    return str + ch;
}
```
这次再使用javap进行反编译, 生成文件的部分内容如下所示
```plain StringTwo.s
public java.lang.String stringAddString(java.lang.String, java.lang.String);
  descriptor: (Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
  flags: ACC_PUBLIC
  Code:
    stack=2, locals=3, args_size=3
       0: new           #2                  // class java/lang/StringBuilder
       3: dup
       4: invokespecial #3                  // Method java/lang/StringBuilder."<  init>":()V
       7: aload_1
       8: invokevirtual #4                  // Method java/lang/StringBuilder.  append:(Ljava/lang/String;)Ljava/lang/StringBuilder;
      11: aload_2
      12: invokevirtual #4                  // Method java/lang/StringBuilder.  append:(Ljava/lang/String;)Ljava/lang/StringBuilder;
      15: invokevirtual #5                  // Method java/lang/StringBuilder.  toString:()Ljava/lang/String;
      18: areturn

public java.lang.String stringAddChar(java.lang.String, char);
  descriptor: (Ljava/lang/String;C)Ljava/lang/String;
  flags: ACC_PUBLIC
  Code:
    stack=2, locals=3, args_size=3
       0: new           #2                  // class java/lang/StringBuilder
       3: dup
       4: invokespecial #3                  // Method java/lang/StringBuilder."<init>":()V
       7: aload_1
       8: invokevirtual #4                  // Method java/lang/StringBuilder.append:(Ljava/lang/String;)Ljava/lang/StringBuilder;
      11: iload_2
      12: invokevirtual #6                  // Method java/lang/StringBuilder.append:(C)Ljava/lang/StringBuilder;
      15: invokevirtual #5                  // Method java/lang/StringBuilder.toString:()Ljava/lang/String;
      18: areturn
```
现在, 我们已经可以很清楚的看出这两个方法执行的流程了:

**stringAddString**

- 创建一个`StringBuilder`对象
- 使用`append`方法, 依次将两个参数添加到刚才创建的`StringBuilder`中.
- 调用`toString`方法.
- `return` `toString`方法的返回值.

`stringAddChar`的过程和`stringAddString`一样, 只是在第二次调用`append`方法时`stringAddString`的参数是`String`类型, 而`stringAddChar`的参数是`char`类型.

## StringBuilder类的append(char)方法和append(String)方法
这里，我们直接查看源码就好了（我的是jdk1.8.0_60附带的源码）。
**注意，虽然文档上显示`StringBuilder`继承自`Object`, 但是从源码来看, 它是继承自抽象类`AbstractStringBuilder`的。而且`append`方法是由`AbstractStringBuilder`实现的。**

```java AbstractStringBuilder.java
public AbstractStringBuilder append(char c) {
    ensureCapacityInternal(count + 1);    // 确保数组能够容纳count+1个字符
    value[count++] = c;
    return this;
}

public AbstractStringBuilder append(String str) {
    if (str == null)
        return appendNull();
    int len = str.length();
    ensureCapacityInternal(count + len);
    str.getChars(0, len, value, count);  // 拷贝字符串中的字符数组到本对象的字符数组中
    count += len;
    return this;
}
```
剩下的就不再贴出来了。`String.getChars(int, int, char[], int)`最终依赖于`public static native void arraycopy(Object, int, Object, int, int)`。也就是说有可能是C语言写的，在拷贝大型数组时效率应该会比java写的程序好一些。
那么，现在说说我的理解：

- 从直接内存来说, 由于`String`中包含char数组, 而数组应该是有长度字段的, 同时`String`类还有一个`int hash`属性, 再加上对象本身会占用额外的内存存储其他信息，所以字符串会多占用一些内存. 但是如果字符串非常长, 那么这些内存开销差不多就可以忽略了; 而如果像`"/"`这种情况, 字符串比较(非常)短,那么就很可能有许多个共享引用来分担这些内存开销, 那么多余的内存开销还是可以忽略的.
- 从调用堆栈上, 由于这里`String`只比`char`多了一两层函数调用，所以如果不考虑函数调用开销(包括时间和空间), 应该差不多;考虑函数调用开销, ***应该*** **`"abc" + '/'`**更好一些; 但是当需要连接若干个字符时(感觉这种情况应该更常见吧?), 由于使用`char`需要循环好多次才能完成连接, 调用的函数次数只会比使用`String`更多. 同时拷贝也不会比`String`直接拷贝一个数组更快. 所以这个时候就变成了**`"abc" + "/"`**吞吐量更大.

现在感觉这个问题像是在问: 读写文件时使用系统调用效率高, 还是使用标准函数库中的IO库效率高. 个人感觉, 虽然标准IO库最后还得调用系统调用, 而且这之间会产生一些临时变量, 以及更深层次的调用堆栈, 但是由于IO库的缓冲等机制, 所以IO库的吞吐量会更大, 而系统调用的实时性会好一些. 同样, 虽然`String`类会多几个字段, 有更深层次的函数堆栈, 但是由于缓存以及更直接的拷贝, 吞吐量应该会更好一些.

## 新的问题
从上面javap的反编译代码来看, 两个`String`相加, 会变成向`StringBuilder`中`append`字符串. 那么理论上, 下面哪段代码的效率好呢?
```java
String str1 = "abc" + "123";    // 1

StringBuilder stringBuilder = new StringBuilder();  // 2
stringBuilder.append("abc");
stringBuilder.append("123");
String str2 = stringBuilder.toString();
```
