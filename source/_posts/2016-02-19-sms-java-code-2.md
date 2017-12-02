---
layout: post
title: "发送短信(二):限制发送频率"
date: 2016-02-19 15:07:25 +0800
comments: true
categories: 编程语言
tags: [发送短信, java]
keywords: java, 发送短信, 限制发送频率
---

本篇是发送短信的第二部分, 这里我们介绍一下如何限制向同一个用户(根据手机号和ip)发送短信的频率

## 使用session
如果是web程序, 那么在session中记录上次发送的时间也可以, 但是可以被绕过去. 最简单的, 直接重启浏览器 或者 清除cache等可以标记session的数据, 那么就可以绕过session中的记录. 虽然很多人都不是计算机专业的, 也没学过这些. 但是我们需要注意的是, 之所以限制发送频率, 是为了防止"短信炸弹", 也就是有人恶意的频繁的请求向某个手机号码发送短信. 所以这个人是有可能懂得这些知识的.

<!--more-->

下面我们使用"全局"的数据限制向同一个用户发送频率. 我们先做一些"准备"工作

## 定义接口、实体类
我们需要的实体类如下:

```java
public class SmsEntity{
    private Integer id;
    private String mobile;
    private String ip;
    private Integer type;
    private Date time;
    private String captcha;

    // 省略构造方法和getter、setter方法
}
```

过滤接口如下:

```java
public interface SmsFilter {

    /**
     * 初始化该过滤器
     */
    void init() throws Exception;

    /**
     * 判断短信是否可以发送.
     * @param smsEntity 将要发送的短信内容
     * @return 可以发送则返回true, 否则返回false
     */
    boolean filter(SmsEntity smsEntity);

    /**
     * 销毁该过滤器
     */
    void destroy();

}
```

## 主要代码
限制发送频率, 需要记录某个手机号(IP)及上次发送短信的时间. 很适合`Map`去完成, 这里我们先使用`ConcurrentMap`实现:

```java
public class FrequencyFilter implements SmsFilter {
    /**
     * 发送间隔, 单位: 毫秒
     */
    private long sendInterval;
    private ConcurrentMap<String, Long> sendAddressMap = new ConcurrentHashMap<>();

    // 省略了部分无用代码

    @Override
    public boolean filter(SmsEntity smsEntity) {
        if(setSendTime(smsEntity.getMobile()) && setSendTime(smsEntity.getIp())){
            return true;
        }
        return false;
    }

    /**
     * 将发送时间修改为当前时间.
     * 如果距离上次发送的时间间隔大于{@link #sendInterval}则设置发送时间为当前时间. 否则不修改任何内容.
     *
     * @param id 发送手机号 或 ip
     * @return 如果成功将发送时间修改为当前时间, 则返回true. 否则返回false
     */
    private boolean setSendTime(String id) {
        long currentTime = System.currentTimeMillis();

        Long sendTime = sendAddressMap.putIfAbsent(id, currentTime);
        if(sendTime == null) {
            return true;
        }

        long nextCanSendTime = sendTime + sendInterval;
        if(currentTime < nextCanSendTime) {
            return false;
        }

        return sendAddressMap.replace(id, sendTime, currentTime);
    }
}
```

这里, 主要的逻辑在`setSendTime`方法中实现:

- 第25-28行: 首先假设用户是第一次发送短信, 那么应该把现在的时间放到`sendAddressMap`中. 如果`putIfAbsent`返回`null`, 那么说明用户确实是第一次发送短信, 而且现在的时间也已经放到了map中, 可以发送.
- 第30-33行: 如果用户不是第一次发送短信, 那么就需要判断上次发送短信的时间和现在的间隔是否小于发送时间间隔. 如果小于发送间隔, 那么不能发送.
- 第35行: 如果时间间隔足够大, 那么需要尝试着将发送时间设置为当前时间. 
    - 如果替换成功, 那么可以发送短信. 
    - 如果替换失败, 说明有另外一个线程在本线程执行26-35行之间已经进行了替换, 也就是说在刚才已经发送了一次短信.
        -  那么可以再重复执行25-35行, 确保绝对正确.
        -  也可以直接认为不能发送, 因为虽然理论上"执行26-35行"的时间可能大于"发送间隔", 但是概率有多大呢? 基本上可以忽略了吧.

这段代码算是实现了频率的限制, 但是如果只有"入"而没有"出"那么`sendAddressMap`占用的内容会越来越大, 直到产生`OutOfMemoryError`异常. 下面我们再添加代码定时清理过期的数据.

## 清理过期数据

```java
/**
 * 在上面代码的基础上, 再添加如下代码
 */
public class FrequencyFilter implements SmsFilter {
    private long cleanMapInterval;
    private Timer timer = new Timer("sms_frequency_filter_clear_data_thread");

    @Override
    public void init() {
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                cleanSendAddressMap();
            }
        }, cleanMapInterval, cleanMapInterval);
    }

    /**
     * 将sendAddressMap中的所有过期数据删除
     */
    private void cleanSendAddressMap() {
        long currentTime = System.currentTimeMillis();
        long expireSendTime = currentTime - sendInterval;

        for(String key : sendAddressMap.keySet()) {
            Long sendTime = sendAddressMap.get(key);
            if(sendTime < expireSendTime) {
                sendAddressMap.remove(key, sendTime);
            }
        }
    }

    @Override
    public void destroy() {
        timer.cancel();
    }
}
```

这段程序不算复杂, 启动一个定时器, 每隔`cleanMapInterval`毫秒执行一次`cleanSendAddressMap`方法清理过期数据.

`cleanSendAddressMap`方法中首先获取当前时间, 根据当前时间获得一个时间值: 所有在这个时间之后发送短信的, 现在不可以再次发送短信. 然后从整个map中删除所有value小于这个时间值的键值对.

当然, 添加上面的代码后, 最开始的代码又有bug了: 当最后一行`sendAddressMap.replace(id, sendTime, currentTime)`执行失败时不一定是其他线程进行了替换, 也有可能是清理线程把数据删了. 所以我们需要修改`setSendTime`方法最后几行:

```java
private boolean setSendTime(String id) {
    // 省略前面的代码
    if(sendAddressMap.replace(id, sendTime, currentTime)) {
        return true;
    }
    return sendAddressMap.putIfAbsent(id, currentTime) == null;
}
```

- 这里如果替换成功, 那么直接返回true.
- 如果替换不成功. 那么可能是其他线程先替换了(第一种情况); 也可能是被清理线程删除了(第二种情况); 甚至可以能是先被清理线程删除了, 又有其他线程插入了新的时间值(第三种情况). 
    - 如果是第一种情况 或者 第三种情况, 那么情况和最开始分析的一样, 可以直接认为不能发送. 
    - 如果是第二种情况, 那么应该是可以发送的.
    - 为了确认是哪种情况, 我们可以执行一次`putIfAbsent`, 如果成功, 说明是第二种情况, 可以发送; 否则是第一种或者第三种情况, 不能发送.

至此, 限制发送时间的代码就算是完成了. 当然, 这段程序还有一个小bug或者说"特性": 

假如, IP为"192.168.0.1"的客户请求向手机号"12345678900"发送短信, 然后在`sendInterval`之内又在IP为"192.168.0.2"的机器上请求向手机号"12345678900"发送短信. 那么短信将不会发出去, 而且手机号"12345678900"的上次发送时间被置为当前时间.

## 使用实例
下面我们提供一个Server层, 展示如何将上一篇以及这一篇中的代码整合到一起:

```java
public class SmsService{
    private Sms sms;
    private List<SmsFilter> filters;
    private Properties template;
   
    // 省略了部分代码

    /**
     * 发送验证码
     *
     * @param smsEntity 发送短信的基本数据
     * @return 如果提交成功, 返回0. 否则返回其他值.
     */
    public int sendCaptcha(SmsEntity smsEntity){
        for(SmsFilter filter : filters) {
            if(!filter.filter(smsEntity)){
                return 1;
            }
        }
        if(SmsEntity.REGISTER_TYPE.equals(smsEntity.getType())) {
            sendRegisterSms(smsEntity);
        }
        else{
            return 2;
        }
        return 0;
    }

    /**
     * 发送注册验证码
     *
     * @param smsEntity 发送短信的基本数据
     */
    private void sendRegisterSms(SmsEntity smsEntity) {
        sms.sendMessage(smsEntity.getMobile(),
                template.getProperty("register").replace("{captcha}", smsEntity.getCaptcha()));
    }

}
```

之后将`FrequencyFilter`以及上一篇中的`AsyncSmsImpl`通过set方法"注入"进去即可.

最后, 点击[这里](/downloads/code/2016/02/sms2.zip "下载源码")下载代码.

发送短信文章:

- [发送短信--同步/异步发送短信](/blog/20160219/sms-java-code-1/ "发送短信--同步/异步发送短信"): http://www.iamlbk.com/blog/20160219/sms-java-code-1/
- [发送短信--限制发送频率](/blog/20160219/sms-java-code-2/ "发送短信--限制发送频率"):  http://www.iamlbk.com/blog/20160219/sms-java-code-2/
- [发送短信--限制日发送次数](/blog/20160219/sms-java-code-3/ "发送短信--限制日发送次数"): http://www.iamlbk.com/blog/20160219/sms-java-code-3/

