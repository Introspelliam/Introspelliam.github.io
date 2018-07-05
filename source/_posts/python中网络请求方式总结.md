---
title: python中网络请求方式总结
date: 2017-09-01 16:39:10
categories: web
tags: python
---



python中能够发请求的包有很多种，有urllib、urllib2、urllib3、requests等，而且仅这几个python库，就能衍生出上百种请求方法，一一赘述明显不合适，这里仅仅讲述基础方法以及我所遇到的问题。



#### 发送`multipart/form-data; ` 数据

有许多种情形下需要发送multipart/form-data数据，如文件上传、网络验证等

##### 方法一：用urllib2请求

```python
# -*- coding: utf-8 -*-
import urllib
import urllib2

header={
    "Host": "api.surfeasy.com",
    "Connection": "keep-alive",
    "SE-Client-Locale": "zh-CN",
    "Origin": "chrome-extension://odiddbcijempnhhobijfbggjogofdlgl",
    "SE-Client-Type": "se0210",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36",
    "SE-Client-Name": "odiddbcijempnhhobijfbggjogofdlgl",
    "SE-Operating-System": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36",
    "SE-Client-API-Key": "DCF8EF2E5C791C25797F4F862EEF60DA7510BB4847058A8CE6357EFB4E692C79",
    "SE-Client-Version": "1.3.6",
    "Accept-Encoding": "gzip, deflate, br",
    "Accept-Language": "zh-CN,zh;q=0.8",
    "Cookie": "api_session=BAhJIgGvZXlKcFpDSTZNVGt3TXpZNE1qVXNJbTltSWpvM056YzJNREF3TENKMGF5STZJbU01TW1ObU1UbGtOakppCk1qSXdNekZqWXpjd04yVmlNMlZtTUdWak9Ua3dOR1UwTVRGbFpUWXdNamxoWWpNNFl6QmpNbUptTURKaApNelZtWldWa04yRWlMQ0owYlNJNklqSXdNVGN0TVRFdE16QlVNRFU2TXpnNk1EaGFJbjA9CgY6BkVG--8d2bd7b8fab0d29ff09569e326d806e3d8b5ab22; api_session=BAhJIgGvZXlKcFpDSTZNVGt3TXpZNE1qVXNJbTltSWpvM056YzJNREF3TENKMGF5STZJakZtWlRZMVltRTJZV016Ck1HVXhNMlZtTkRSalpEWTJOMll5WkRJd1l6VmxObVkzTVRoaU4yRXhOakE1WVRWbVkyWTNNMk0wWm1ZMApPVFJqTXpRM1lqVWlMQ0owYlNJNklqSXdNVGN0TVRFdE16QlVNRGM2TURnNk5UUmFJbjA9CgY6BkVG--48a4f3899a63984d4061a64ae9864c8f9ecf2ad6"
    }
data = '''--123456\r
Content-Disposition: form-data; name="device_id"\r
\r
ab197fb4782f20bd5808133bdd8121ecd422ffb6\r
--123456--\r
'''
#print requests.post("https://api.surfeasy.com/v3/geo_lookup", verify=False, headers=header, data=data).text
req = urllib2.Request(url="https://api.surfeasy.com/v2/geo_list", headers=header)
req.add_header('Content-type', "multipart/form-data; boundary=123456")
req.add_header('Content-length', len(data))
req.add_data(data)

print urllib2.urlopen(req).read() #读取指定网站的内容
```

<font color=#f00>你会发现，我们竟然用post的方法进行了相应的请求！但是这里面有几处十分坑爹的地方</font>

1. boundary所包含的字符串一定是data中分界的字符串，并且一般以--boundary开头，以--boundary--结尾
2. 注意data数据换行用\r\n或者\x0d\x0a来分割，最后结尾处也有\r\n
3. header头中的Content-type一定得有，但是Content-length却不是必须的
4. 一般Content-Disposition: form-data;数据会先空一行，然后才是数据

本内容参考的是:[https://gist.github.com/zhenyi2697/5252801](https://gist.github.com/zhenyi2697/5252801)

##### 方法二：用requests请求

可能大家会说，requests多简单啊，其实确实是这样的，毕竟requests是专门为黑客开发的一套工具

>  当然，我们仍然可以利用上述的方法进行请求，我尝试过，仍然可以得到需要的结果！

现在讲讲另外一种方法

在官方网站上，requests模拟一个表单数据的格式如下：

> files = {'name': (<filename>, <file object>,<content type>, <per-part headers>)}
>
> 如果有多条内容，就在字典中加入多个内容。

```
files = {
  'device_id':(None,None,"ab197fb4782f20bd5808133bdd8121ecd422ffb6")
}
```



然后发送请求

>  response=requests.post(url,files=files)