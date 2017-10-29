---
layout: post
title: "简易缓存实现(java语言版)"
date: 2016-04-02 19:45:53 +0800
comments: true
categories: 算法
tags: [java, 缓存]
keywords: java, 缓存
---

在合适的地方使用缓存可以 简化程序逻辑 或者 提高程序的效率. 比如前面的[发送短信][sms]部分中[限制发送频率][sms2]和[限制日发送次数][sms3]就可以使用缓存机制实现.这里我们自己实现一个简易版的缓存类. 该类提供如下功能:

- 可以添加键值对
- 根据键获取对应的值
- 超时的键值对会被删除
- 可以限制缓冲区的大小

<!--more-->

## 数据结构
在动手实现之前, 我们首先需要选择合适的数据结构来存储数据. 为了存储键值对, Map是最合适. 为了在删除过期数据时不用遍历整个Map, 我们需要一个优先队列来按照过期时间排序存储键值对. 

但是使用Java提供的`PriorityQueue`并不合适. 因为虽然`PriorityQueue`类的`remove()`方法提供了O(log(n))的时间效率. 但是`remove(Object)`的效率是O(n)的. 而我们使用优先队列就是为了避免删除时O(n)的时间复杂度.

这里我们自己实现一个超级简化版的"优先队列", 如果有更复杂的需求, 使用红黑树, 堆等数据结构可能会更合适一点.

## 数据节点
既然需要实现一个简单的优先队列, 那么就需要先定义一个存储元素的类型. 由于我们不需要随机访问, 而需要方便的扩充容量, 所以使用链表的方式实现. 下面给出我们的优先队列需要存储的数据节点的定义:

``` java Entity
// 该类是内部类, 所以可以用static关键字修饰
public static class Entity<K, V> {
    private K key;
    private V value;
    private long timeout;
    Entity<K, V> next;
    Entity<K, V> prev;

    public Entity(K key, V value, long liveTime) {
        this.key = key;
        this.value = value;
        updateTimeout(liveTime);
    }

    // 省略了getter, setter方法

    public boolean isTimeout() {
        return timeout < System.currentTimeMillis();
    }

    void updateTimeout(long liveTime) {
        this.timeout = System.currentTimeMillis() + liveTime;
    }
    
    // 省略了hashCode, equals方法

}
```

## 优先队列
我们的"优先队列"需要提供那些功能呢? 

首先需要有添加功能, 并且添加后队列中的元素是按照过期时间排序的. 考虑到一般而言, 一个缓冲区中所有的元素的生存周期都是一样的(比如都是20分钟). 所以后面加入的元素的过期时间更靠后, 因此我们只需要提供一个 追加方法 即可.

需要有删除功能. 由于队列是按照过期时间排序的, 所以在删除时, 我们需要从头开始删除, 因此需要有 获取头部元素 和 删除头部元素 的功能.

还需要一个更新功能. 当用户使用了某个元素时, 我们需要修改该元素的过期时间, 然后把该元素放到队列的队尾. 当用户更新了和某个key关联的value后我们需要更新`Entity`中的`value`和`timeout`字段, 然后放到队列的队尾. 而这两个需求都可以使用删除再添加实现. 所以我们需要提供一个 删除指定元素 的功能.

最后, 为了方便, 顺带再提供一个清空功能.

总结一下. 我们需要的功能有: 追加, 获取头部元素, 删除头部元素, 删除指定元素, 清空. 下面是实现代码:

``` java Queue
// 该类同样是内部类
private static class Queue<K, V> {
    private Entity<K, V> head;
    private Entity<K, V> tail;

    public Queue() {
        head = null;
        tail = null;
    }

    /**
     * 获得第一个元素.
     */
    public Entity<K, V> getFirst() {
        return head;
    }

    /**
     * 向队列末尾添加元素.
     */
    public void append(Entity<K, V> entity) {
        if (head == null) {
            head = entity;
            tail = entity;
            entity.prev = null;
        }
        else {
            entity.prev = tail;
            tail.next = entity;
            tail = entity;
        }
        entity.next = null;
    }

    /**
     * 移除第一个元素.
     */
    public Entity<K, V> removeFirst() {
        // 没有元素
        if (head == null) {
            return null;
        }
        Entity<K, V> entity = head;

        // 只有一个元素
        if (head == tail) {
            head = null;
            tail = null;
        }
        else {
            head = entity.next;
            head.prev = null;
        }
        return entity;
    }

    /**
     * 从队列中移除指定的元素. 该元素必须在队列中, 否则会出现无法预期的结果.
     */
    public Entity<K, V> remove(Entity<K, V> entity) {
        // 只有一个元素 或者 没有元素
        if (head == tail) {
            head = null;
            tail = null;
            return entity;
        }

        if (entity.prev != null) {
            entity.prev.next = entity.next;
        }
        else {
            head = entity.next;
        }

        if (entity.next != null) {
            entity.next.prev = entity.prev;
        }
        else {
            tail = entity.prev;
        }
        return entity;
    }

    public void clear() {
        head = null;
        tail = null;
    }
}
```

## 简易缓存实现

终于到了实现缓存类的时候了. 其实经过上面的准备, 我们的缓存实现起来并不麻烦. 首先给出该类的属性以及构造方法:

``` java SimpleCache构造方法
private long liveTime;
private int limit;
private Map<K, Entity<K, V>> map;
private Queue<K, V> queue;

public SimpleCache(long liveTime) {
    this(liveTime, 0);
}

public SimpleCache(long liveTime, int limit) {
    this.liveTime = liveTime;
    this.limit = limit > 0 ? limit : 0;
    int initialCapacity = limit == 0 ? 16 : (int) (limit * 0.8);
    this.map = new HashMap<>(initialCapacity);
    this.queue = new Queue<>();
}
```

接下来我们先实现删除过期数据的方法:
``` java SimpleCache.removeTimeOut
private synchronized void removeTimeOut() {
    Entity<K, V> head = queue.getFirst();
    while (head != null && head.isTimeout()) {
        removeFirst();
        head = queue.getFirst();
    }
}
```

`removeFirst`方法的实现就更简单了:
``` java SimpleCache.removeFirst
// 注意, 调用该方法之前需要保证缓冲区中有元素
private synchronized void removeFirst(){
    map.remove(queue.removeFirst().getKey());
}
```

接着我们实现添加键值对功能. 该功能将一对键值对添加到缓冲区. 如果提供的键已经有与之关联的值了, 那么就用新值将旧值替换掉:
``` java SimpleCache.add
public synchronized V add(K key, V value) {
    removeTimeOut();

    Entity<K, V> entity = new Entity<>(key, value, liveTime);
    Entity<K, V> oldEntity = map.put(key, entity);

    if (oldEntity != null) {
        queue.remove(oldEntity);
    }
    queue.append(entity);

    // 删除多余的缓存
    if (limit != 0 && map.size() > limit) {
        removeFirst();
    }
    return oldEntity == null ? null : oldEntity.getValue();
}
```

获取方法. 获取与指定键关联的值, 并更新该键值对的过期时间:
``` java SimpleCache.get
public synchronized V get(K key) {
    removeTimeOut();
    Entity<K, V> entity = map.get(key);
    if (entity != null) {
        access(entity);
        return entity.getValue();
    }
    return null;
}
```

`access`方法用于更新实体的过期时间, 并调整该实体在队列中的位置:
``` java SimpleCache.access
private synchronized void access(Entity<K, V> entity) {
    queue.remove(entity);
    entity.updateTimeout(liveTime);
    queue.append(entity);
}
```

最后再提供两个工具方法:
``` java SimpleCache.clear&size
public synchronized void clear() {
    map.clear();
    queue.clear();
}

public synchronized int size() {
    removeTimeOut();
    return map.size();
}
```

至此, 我们的简易版缓存类就算是完成了. 需要完整代码的朋友可以点击[这里][download code]下载代码.

[sms]: /blog/tags/fa-song-duan-xin/ "发送短信"
[sms2]: /blog/20160219/sms-java-code-2/ "发送短信(二):限制发送频率"
[sms3]: /blog/20160220/sms-java-code-3/ "发送短信(三):限制日发送次数"
[download code]: /downloads/code/2016/04/simpleCache.zip "下载代码"
