---
layout: post
title: "发送短信(四):使用Redis限制发送频率和日发送次数"
date: 2016-03-02 17:26:33 +0800
comments: true
categories: 编程语言
tags: [发送短信, java, redis]
keywords: java, 发送短信, 限制发送频率, redis
---

在前几篇文章中, 我们介绍了限制发送短信频率, 限制日发送次数等功能. 但是后来[z-oneC][]说用Redis实现会更简单. 于是这几天我大致学了一下Redis, 然后使用Redis重新实现了一次. 当然由于刚接触Redis, 或许有些地方并不合适, 还请您在留言区留言, BK在这里先谢过了.

其实使用Redis确实挺简单, 至少没有过于复杂的概念, 庞大的命令集. 基本上入门挺快的. 剩下的就是创造力和经验了. 这里我们使用Redis来完成前两篇:《[发送短信--限制发送频率][sms2]》、《[发送短信--限制日发送次数][sms3]》完成的功能.

当然, 如果读者并没有学过Redis, 可以参见《[The Little Redis Book][the-little-redis-book]》快速入门,这本"书"基本上半个上午就可以看完.

<!--more-->
## 思路
这里我们就是简单用Redis限制"访问"频率: 

- 首先根据用户手机号/IP拼凑出一个字符串的关键字. 
- 然后判断该字符串的值是否为空.
    - 如果为空, 则设置该字符串的值为1, 并设置生存时间. 并允许"访问".
    - 如果不为空, 则将值加一, 然后判断值是否超过使用期限时间内的最大"访问"次数
        - 如果没有超过, 则允许"访问"
        - 否则拒绝"访问"


## 编写脚本

***注: 该脚本摘自《Redis入门指南》***

``` lua ratelimiting.lua
--[[
实现访问频率的脚本.
参数:
    KEY[1] 用来标识同一个用户的id
    ARGV[1] 过期时间
    ARGV[2] 过期时间内可以访问的次数
返回值: 如果没有超过指定的频率, 则返回1; 否则返回0
]]
local times = redis.call('incr', KEYS[1])

if times == 1 then
    -- 说明刚创建, 设置生存时间
    redis.call('expire', KEYS[1], ARGV[1])
end

if times > tonumber(ARGV[2]) then
    return 0
end

return 1
```

该脚本也比较直观: 

- 首先将指定的键加一. 由于Redis的特性, 如果指定的键并不存在, 则默认为0, 并加一. 这一步相当于判断指定的键是否存在, 如果不存在, 则置指定的键为1; 否则加一
- 接着判断是否是第一次访问, 如果是, 则设置生存时间
- 最后判断是否超过了访问频率, 如果超过了访问频率, 则返回0; 否则返回1

## 使用Jedis调用脚本
在Redis的[官网][Redis]上有许多Redis的[Java客户端的库][Redis client]. 这里我们使用[Jedis][].

我们来看看代码. **该程序中的`ClassPathResource`和`FileCopyUtils`类为Spring中的类, 因此这里的示例程序依赖于Spring**

``` java RateLimit.java
public class RateLimit {

    private JedisPool jedisPool;
    private String script;
    // 省略了构造方法
    public void init() throws Exception {
        ClassPathResource resource = new ClassPathResource("script/ratelimiting.lua");
        script = FileCopyUtils.copyToString(new EncodedResource(resource, "UTF-8").getReader());
    }

    /**
     * 提供限制速率的功能
     *
     * @param key        关键字
     * @param expireTime 过期时间
     * @param count      在过期时间内可以访问的次数
     * @return 没有超过指定次数则返回true, 否则返回false
     */
    public boolean isExceedRate(String key, long expireTime, int count) {
        List<String> params = new ArrayList<>();
        params.add(Long.toString(expireTime));
        params.add(Integer.toString(count));
        try(Jedis jedis = jedisPool.getResource()) {
            List<String> keys = new ArrayList<>(1);
            keys.add(key);
            Long canSend = (Long) jedis.eval(script, keys, params);
            return canSend == 0;
        }
    }

}
```

这里的`init`方法的作用就是将刚才我们写的脚本读取到`script`变量中, 以便以后使用.

`isExceedRate`方法将关键字和参数(过期时间和发送次数)分别封装到`List`里, 之后使用Jedis调用脚本. 获取返回值, 判断频率是否过高. 

## 使用示例
下面我们使用上面的代码完成限制发送频率的功能(部分接口和类的声明请参见《[发送短信--限制发送频率][sms2]》). 限制日发送次数的代码基本相同, 这里就不贴了, 请[下载][download code]源码查看.

``` java FrequencyFilter
public class FrequencyFilter implements SmsFilter {
    private static final String KEY_PREFIX = "rate.frequency.limiting:";

    private RateLimit rateLimit;
    private int sendInterval;

    // 省略了部分代码

    @Override
    public void filter(Sms sms) throws FrequentlyException {
        if(rateLimit.isExceedRate(KEY_PREFIX+sms.getMobile(), sendInterval, 1)
                || rateLimit.isExceedRate(KEY_PREFIX+sms.getIp(), sendInterval, 1)){
            throw new FrequentlyException("发送短信过于频繁");
        }
    }
}
```

到这里我们的主要代码就完成了, 可以看出使用Redis后代码确实非常的简单. 

由于我现在还不会性能测试, 所以只是简单的使用`for`循环测试了一下性能, 虽然可能不是很准确, 但是也有一定的可信度. 在限制发送频率时, 使用`ConcurrentMap`的性能更高, 貌似比例还不小, 只是由于基数并不大, 所以并没有多费多少时间(十万条记录只多花费了十五秒).
但是在限制日发送次数时, 剩下了n多时间. 综合来看, 还是只使用Redis更省时省事.
而且, 个人猜测, 在扩展到集群时, 使用Redis应该会简单些. 

[z-oneC]: http://my.csdn.net/zzg1229059735 "z-oneC在CSDN上的个人主页"
[sms2]: http://iamlbk.github.io/blog/20160219/sms-java-code-2/ "发送短信--限制发送频率"
[sms3]: http://iamlbk.github.io/blog/20160220/sms-java-code-3/ "发送短信--限制日发送次数"
[Redis]: http://redis.io "Redis官网"
[Redis client]: http://redis.io/clients#java "Reids的Java客户端库"
[Jedis]: https://github.com/xetorthio/jedis "Jedis下载"
[download code]: /downloads/code/2016/03/sms4.zip "下载源码"
[the-little-redis-book]: https://github.com/JasonLai256/the-little-redis-book/blob/master/cn/redis.md "The Little Redis Book"
