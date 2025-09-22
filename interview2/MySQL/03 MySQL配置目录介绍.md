## 查看mysql是否可以远程连接

mysql -h  -P 3306 -u root -p

*如何更改*

mysql -u root -p，登录mysql。

use mysql;（关于是否允许远程连接的配置在该数据库中）

## 04 MySQL数据类型

一般在项目中使用unix_timestamp来记录时间。

``` shell
select unix_timestamp(now());
```

# 05 MySQL运算符


# 07 MySQL完整约束

CREATE TABLE user(

)