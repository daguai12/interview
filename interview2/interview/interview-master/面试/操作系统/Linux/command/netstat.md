netstat ：显示网络状态



怎样看某端口是否被占用

1. netstat -anp |grep 端口号
   ![image](https://pic1.zhimg.com/80/v2-f3fdfffcb8570780870ed2f1cc19ee0c_1440w.png)
   图中主要看监控状态为LISTEN表示已经被占用，最后一列显示被服务mysqld占用，查看具体端口号，只要有如图这一行就表示被占用了。
2. netstat -nultp（此处不用加端口号）
   该命令是查看当前所有已经使用的端口情况，如图
   ![image](https://pic2.zhimg.com/80/v2-ef8708d28dd7c71aae7ae54c8d5dde95_1440w.jpg)

