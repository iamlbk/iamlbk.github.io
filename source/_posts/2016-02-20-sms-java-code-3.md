---
layout: post
title: "发送短信(三):限制日发送次数"
date: 2016-02-20 14:58:41 +0800
comments: true
categories: 编程语言
tags: [发送短信, java]
keywords: java, 发送短信, 限制日发送次数, quartz
---

在前两篇文章中, 我们实现了同步/异步发送短信以及限制发送短信频率.这一篇, 我们介绍一下限制每日向同一个用户(根据手机号和ip判断)发送短信的次数

## 数据表结构
由于需要记录整天的发送记录, 因此这里我们将数据保存到数据库中. 数据表结构如下:
{% img center /images/2016/02/sms-java-code-3-dbtable.png %}

<!--more-->

- type为验证码的类型, 比如注册, 重置密码等. 
- sendTime的默认值为当前时间.

## 限制日发送次数
我们这里需要用到[上一篇](/blog/20160219/sms-java-code-2/ "发送短信--限制发送频率")中提到的接口和实体类.

```java
public class DailyCountFilter implements SmsFilter {

    private int ipDailyMaxSendCount;
    private int mobileDailyMaxSendCount;
    private SmsDao smsDao;

    // 省略了部分无用代码

    @Override
    public boolean filter(SmsEntity smsEntity) {
        if (smsDao.getMobileCount(smsEntity.getMobile()) >= mobileDailyMaxSendCount) {
            return false;
        }
        if (smsDao.getIPCount(smsEntity.getIp()) >= ipDailyMaxSendCount) {
            return false;
        }
        smsDao.saveEntity(smsEntity);
        return true;
    }

}
```

主要代码很简单, 首先判断向指定的手机号发送的次数是否达到了日最大发送次数, 之后再判断指定的ip请求发送的次数是否达到了最大次数. 如果都没有, 则将本次发送的手机号, ip等信息保存到数据库中.

当然, 这个类存在一定的问题: 在判断是否超过最大次数到保存实体数据之间可能已经有其他线程保存了新的数据. 造成上面的两个判断并不是绝对的准确. 

我们可以使用序列化等级的事务保证不会发生错误, 但是代价太高. 因此我们这里不做处理. 因为我们前面已经实现了限制发送频率. 如果先使用`FrequencyFilter`过滤一次, 限制发送频率, 那么基本上不可能出现前面说的问题.

还有一个问题: 随着时间的推移, 这个表会越来越大, 造成查询的性能相当的差. 我们可以向上一篇中那样, 每隔一段时间就删除无用的数据; 也可以动态的创建表, 然后向新表中插入数据. 

## 使用动态表
这里我们采用第二种方案: 数据表的名字为"sms\_四位年\_两位月", 比如"sms\_2016\_02". 插入数据时根据现在的时间获得表名, 然后再插入. 另外使用[Quartz](http://www.quartz-scheduler.org/ "Quartz官网")在每月的20号2点生成下个月以及下下个月的数据表:

我们首先修改`DailyCountFilter`类, 在这个类中添加任务计划, 定时生成数据表:

```java
// 在上面代码的基础上, 再添加如下代码
public class DailyCountFilter implements SmsFilter {

    private Scheduler sched;

    @Override
    public void init() throws SchedulerException {
        smsDao.createTable(0);  // 创建这个月的数据表
        smsDao.createTable(1);  // 创建下个月的数据表
        
        SchedulerFactory sf = new StdSchedulerFactory();
        sched = sf.getScheduler();  // 创建Quartz容器
        
        JobDataMap jobDataMap = new JobDataMap();
        jobDataMap.put("smsDao", smsDao);   // 创建运行任务时需要使用的数据map 

        // 创建job对象, 该对象执行实际的任务
        JobDetail job = JobBuilder.newJob(CreateSmsTableJob.class)
                .usingJobData(jobDataMap)
                .withIdentity("create sms table job").build(); 

        // 创建trigger对象, 该对象用来描述触发执行job的时间规则
        // 比如这里的每月20号2点
        CronTrigger trigger = TriggerBuilder.newTrigger()
                .withIdentity("create sms table trigger")
                .withSchedule(CronScheduleBuilder.cronSchedule("0 0 2 20 * ?"))// 每月的20号2点
                .build(); 

        sched.scheduleJob(job, trigger);    // 注册任务和触发规则
        sched.start();  // 启动调度
    }

    @Override
    public void destroy() {
        try {
            sched.shutdown();
        }
        catch (SchedulerException e) {}
    }

    public static class CreateSmsTableJob implements Job {
        @Override
        public void execute(JobExecutionContext context) throws JobExecutionException {
            JobDataMap dataMap = context.getJobDetail().getJobDataMap();
            SmsDao smsDao = (SmsDao) dataMap.get("smsDao"); // 获得传过来的smsDao对象
            smsDao.createTable(1);  // 创建下个月的数据表
            smsDao.createTable(2);  // 创建下下个月的数据表
         }
    }
}
```

接下来, 我们看看`SmsDao`的部分代码:

```java
public class SmsDao {

    /**
     * 创建新的日志表
     *
     * @param monthExcursion 偏移的月数
     */
    public void createTable(int monthExcursion){
        String sql = "CREATE TABLE IF NOT EXISTS " 
            + getTableName(monthExcursion) + " LIKE sms";
        // 执行sql语句
    }

    /**
     * 保存SmsEntity实体对象
     */
    public void saveEntity(SmsEntity smsEntity){
        String sql = "INSERT INTO " 
            + getNowTableName() + " (mobile, ip, type) VALUES(?, ?, ?)";
        // 执行sql语句
    }

    /**
     * 获得指定手机号今天请求发送短信的次数
     *
     * @param mobile 用户手机号
     * @return 今天请求发送短信的次数
     */
    public long getMobileCount(String mobile){
        String sql = "SELECT count(id) FROM "
            + getNowTableName() + " WHERE mobile=? AND send_time >= CURDATE()";
        // 执行sql语句, 返回查询结果
    }

    // 省略了getIPCount方法

    /**
     * 获得现在使用的表的名字
     */
    private String getNowTableName() {
        return getTableName(0);
    }

    private DateFormat dateFormat = new SimpleDateFormat("yyyy_MM");
    
    /**
     * 获得相对现在偏移monthExcursion月的表名
     *
     * @param monthExcursion 偏移的月数
     * @return 对应月的表名
     */
    private String getTableName(int monthExcursion) {
        Calendar calendar = Calendar.getInstance();
        calendar.add(Calendar.MONTH, monthExcursion);
        Date date = calendar.getTime();
        return "sms_" + dateFormat.format(date);
    }
    
}
```

`SmsDao`中的`createTable`方法成功运行有个前提, 就是存在`sms`数据表. `createTable`方法会复制`sms`表的结构创建新的数据表.

我们保留发送短信的数据(手机号, ip, 时间等), 而不是直接删除, 是因为以后可能需要分析这些数据, 获取我们想要的信息, 比如判断服务商短信的到达率、是否有人恶意发送短信等. 甚至可能获得意外的"惊喜". 

最后, 示例代码可以在[这里](/downloads/code/2016/02/sms3.zip "下载源码")下载.

发送短信文章:

- [发送短信--同步/异步发送短信](/blog/20160219/sms-java-code-1/ "发送短信--同步/异步发送短信"): http://www.iamlbk.com/blog/20160219/sms-java-code-1/
- [发送短信--限制发送频率](/blog/20160219/sms-java-code-2/ "发送短信--限制发送频率"):  http://www.iamlbk.com/blog/20160219/sms-java-code-2/
- [发送短信--限制日发送次数](/blog/20160219/sms-java-code-3/ "发送短信--限制日发送次数"): http://www.iamlbk.com/blog/20160219/sms-java-code-3/
