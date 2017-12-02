---
layout: post
title: 从N个数中取M个和为指定值的数
date: 2016-01-29 11:14:26 +0800
comments: true
categories: 算法
tags: [分而治之]
keywords: 指定和, 取子集合
---

有一个比较常见的问题: 从n个数中取出m个数, 要求这m个数之和是一个固定值. 在n和m比较小时我们直接使用穷举就可以解决这个问题, 但是在n和m比较大时这种方法并不可行. 本文尝试着给出n和m比较大时的解决办法. 当然, 由于本人的水平有限, 无法完全解决这个问题. 所以这种方法有它的局限性, 而且效率也并没有提高太多, 在遇到过大的n和m时仍旧无法使用.

写这篇博客, 同样是因为csdn上的一个帖子. 这个帖子中要求从125个数中挑选出21个数. 这两个数字对于许多问题来说并不是很大. 但是如果这里采用穷举的方法解决的话, 需要尝试的次数大家可以计算一下...这里我们首先给出穷举法的实现, 之后针对这个题目进行改进, 使程序的运行时间在可以接受的范围内.

<!--more-->

## 穷举法
要使用穷举法解决这个问题, 就太简单了(虽然运行时间长的不能忍受). 我最先想到的就是使用递归. 废话不多说, 看代码:
```java ArraySum.java
private boolean calNextNumber(int start, int sum, int count) {
    if(sum == 0 && count ==0){  // 符合条件
        return true;
    }
    // 剩余的数字不足 或者 选择的数的和已经超过了总和
    if (start + count > array.length || sum <= 0) {
        return false;
    }
    for (int i=start; i<array.length; i++) {
        int nextSum = sum - array[i];
        calResult.offerLast(array[i]);  // 将可能的结果压入结果栈中
        if(calNextNumber(i + 1, nextSum, count - 1)){
            return true;
        }
        calResult.pollLast();   // 不符合要求, 从结果栈中弹出
    }
    return false;
}
```
这里只给出了关键的代码, 完整代码可以在[这里](/downloads/code/2016/01/getArrayBySum.zip "下载源码")下载. 帖子中的数据太长了, 也没有贴出来, 各位可以在源码中看到, 或者到《[求解求哪几个数字之和等于一个固定值](http://bbs.csdn.net/topics/391897373 "求解求哪几个数字之和等于一个固定值")》里面查看.

如果使用我自己随便输入的测试数据, 几乎一瞬间就可以计算出来, 而如果用这个程序去计算那个帖子中给的数据, 在我的电脑上跑了两个小时, 还没有计算出来...

## 针对帖子中数据的优化
首先感谢[kinkon007](http://my.csdn.net/kinkon007 "kinkon007的csdn主页")的提醒: 
> 可以看到sum的尾数是7，那只有几种情况存在，0+7,1+6,2+5,3+4，先固定匹配好两个尾数，然后再选择其他的数来凑和。

根据这个提示, 我们大致可以想到分而治之的思想. 把数据分成两组:  一组(a组)低三位至少有一个不为0, 一组(b组)低三位都是0. 那么, 我们就可先计算a组, 使计算的结果的低三位和目标的第三位一致. 具体来说就是计算结果为: \*\*\*127. 但是个人感觉这样数据量还是很大(没有去数, 纯属感觉). 那么我们就多分几组吧! 一组个位均不为0, 一组个位为0, 十位不为0, 一组个位和十位为0, 百位不为0...
然后依次计算.

## 代码实现
这里我就在上面那个穷举程序的基础上改进. 首先需要修改穷举程序, 使其不是精确到达某个值, 而是低位相等即可.
其次, 需要支持"迭代", 就是说, 调用一次`calNextNumber`方法获得一组可能的结果, 再调用一次`calNextNumber`方法, 可以获得下一组可能的结果. 主要代码如下:
```java ArraySum1.java 
private boolean calNextNumber(int start, int sum, int maxCount) {
    if (sum <= 0 || maxCount <= 0) {
        return false;
    }
    Integer prevEnd = prevStack.pollLast(); // 取出上一次成功时的状态
    start = prevEnd == null ? start : Math.max(start, prevEnd);
    for (int i = start; i < array.length; i++) {
        int nextSum = sum - array[i];
        calResult.offerLast(array[i]);
        // 完全满足 或者 低位一致
        if ((nextSum == 0 && maxCount - 1 == 0) || nextSum % lowDigit == 0) {
            prevStack.clear(); // 清除可能残余的上次的状态
            prevStack.offerLast(i + 1); // 保存下次迭代时开始的起点
            return true;
        }
        if (calNextNumber(i + 1, nextSum, maxCount - 1)) {
            prevStack.offerLast(i);
            return true;
        }
        calResult.pollLast();
    }
    return false;
}
```
接下来, 再通过另外一个类去将数据分组, 调用上面的方法计算. 主要代码如下:
```java ArraySum2.java
private void splitArray(Map<Integer, List<Integer>> map) {
    for (int i = 0; i < array.length; i++) {
        int digit = 0;
        int temp = array[i];
        for (; temp % 10 == 0; temp /= 10) {
            digit++;
        }
        List<Integer> tempList = map.get(digit);
        if (tempList == null) {
            tempList = new ArrayList<>();
            map.put(digit, tempList);
        }
        tempList.add(array[i]);
    }
}

private void createArraySum(Map<Integer, List<Integer>> map) {
    Integer[] keys = map.keySet().toArray(new Integer[0]);
    Arrays.sort(keys);
    for (Integer key : keys) {
        arraySums.add(new ArraySum1(map.get(key).toArray(new Integer[0]), 0, 0, (int) Math.pow(10, key + 1)));
    }
}

private boolean calNextArray(int index, int sum, int count) {
    if (sum == 0 && count == 0) { // 计算完成
        return true;
    }
    if (index >= arraySums.size()) { // 没有更多分组了
        return false;
    }
    ArraySum1 sum1 = arraySums.get(index);
    sum1.setSum(sum);
    sum1.setMaxCount(count);
    while (sum1.calNextCollection()) { // 计算下一个低位符合条件的集合
        // 递归下一组, 寻找符合条件的集合
        if (calNextArray(index + 1, sum - sum1.getResultSum(),
                count - sum1.getResultCount())) {
            return true;
        }
    }
    return false;
}
```
同样, 这里只有主要代码, 完整代码在[这里](/downloads/code/2016/01/getArrayBySum.zip "下载源码")下载.

## 这种方法的限制
这种方法并不是可以使用所有的情况. 

首先, 所有的数字需要可以大致均匀的分解成较多的组, 至少不能全部都在一个或者两个组中, 那样的话, 我们进行分组就有没意义了. 

其次, 由于这里可以分得组并不是太多, 所以如果数字过多, 即使可以均匀的分组, 但是如果一个组的数字过多, 同样不适用. 这也是需要改进的地方. 

当然, 还有一个缺点: 这里的代码有点饶. 尤其是`ArraySum1`中的`calNextNumber`方法. 或许可以在《[从N个数中取出任意个数，求和为指定值的解](http://blog.csdn.net/min_jie/article/details/3966867 "从N个数中取出任意个数，求和为指定值的解")》的基础上进行修改. 由于这篇博客中精巧的设计, 记录上一次的状态非常简单, 可以让程序简单许多. 这里就不提供代码了, 各位可以试试.

