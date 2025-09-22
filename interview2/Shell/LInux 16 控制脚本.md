# 16.1处理信号

## 16.1.1 重温Linux信号

- SIGHUP 挂起进程
- SIGINT 终止进程
- SIGQUIT 停止进程
- SIGKILL 无条件终止进程
- SIGTERM 尽可能终止程
- SIGSTOP 无条件停止进程，但不是终止进程
- SIGTSTP 停止或暂停进程，但不终止进程
- SIGCONT 继续运行停止的进程

默认情况下，bash shell 会忽略所有 SIGQUIT 和 SIGTERM 信号。但是bash shell 会接收 SIGHUP 和 SIGINT 信号。


bash shell在接收到 SIGINT 和 SIGHUP 信号，会将该信号传递给由该 shell 所启动的进程。

## 16.1.2 生成信号

1. 中断进程

>按下 ctrl + c 可以生成SIGINT信号，提前中断正在运行中的进程。

2. 暂停进程

>按下 Ctrl + z 可以生成 SIGTSTP 信号暂停运行中的进程，而不是终止进程。暂停进程之后，程序会保留在内存中，并从上次停止的位置继续运行。

当按下 Ctrl + z时，shell会通知进程已经被暂停。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ sleep 100
^Z
[1]+  Stopped                 sleep 100
```

方括号中的数字为作业号。shell将shell中运行的进程称为作业，shell会为每一个作业分配唯一的作业号。第一个作业分配的作业号为1，第二个分配的作业号为2，以此类推。

如果当前shell中有暂停的进程，在输入exit退出shell时，bash会提醒你。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ exit
exit
There are stopped jobs.
```

可以用ps命令查看停止的作业。

```shell
F S   UID     PID    PPID  C PRI  NI ADDR SZ WCHAN  TTY          TIME CMD
0 S  1000    9529    9522  0  80   0 - 60035 futex_ pts/0    00:00:00 fish
0 S  1000    9734    9529  0  80   0 -  3626 do_wai pts/0    00:00:00 bash
0 T  1000    9741    9734  0  80   0 -  2847 do_sig pts/0    00:00:00 sleep
0 R  1000    9767    9734  0  80   0 -  4222 -      pts/0    00:00:00 ps
```

在 S 列中，为 T 的进程，表示该进程被追踪或者停止。如果还想退出shell，可以再次输入exit命令退出。

也可以使用 kill -9 pid 的方式使用SIGKILL命令终止进程。杀死进程之后shell不会产生提示符。在下次输入会车时，shell会生成一个提示符，说明作业被终止了。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ kill -9 9741
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ 
[1]+  Killed                  sleep 100
```

## 16.1.3 捕获信号

trap命令可以将 shell 处理的信号，交给本地处理。

```shell
trap command signals
```

代码示例：

```shell
#!/bin/bash

trap "echo 'Sorry! I have trapped Ctrl-C'" SIGINT

echo This is a test script

count=1
while [ $count -le 10 ]
do
  echo "Loop #$count"
  sleep 1
  count=$[ $count + 1 ]
done

echo "This is the end of the test script"

```

运行结果:

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ bash test1.sh 
This is a test script
Loop #1
Loop #2
Loop #3
^CSorry! I have trapped Ctrl-C
Loop #4
Loop #5
Loop #6
Loop #7
^CSorry! I have trapped Ctrl-C
Loop #8
Loop #9
Loop #10
This is the end of the test script
```

该脚本捕获了 SIGINT 信号，使得脚本在接收到该信号时，不在执行信号默认的行为，而是执行脚本自定义的 echo 命令。

## 16.1.4 捕获脚本的退出

trap命令也捕获脚本的退出。

示例代码：

```shell
#!/bin/bash

trap "echo Goodbye..." EXIT

echo This is a test script

count=1
while [ $count -le 3 ]
do
  echo "Loop #$count"
  sleep 1
  count=$[ $count + 1 ]
done

```

结果：

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ bash test2.sh 
This is a test script
Loop #1
Loop #2
Loop #3
Goodbye...
```

## 16.1.5 修改或移除捕获

要想在脚本不同位置，捕获不同的信号，只需要重新使用带有新选项的trap命令就可以。

```shell
#!/bin/bash

trap "echo 'Sorry! I have trapped Ctrl-C'" SIGINT

echo This is a test script

count=1
while [ $count -le 3 ]
do
  echo "Loop #$count"
  sleep 1
  count=$[ $count + 1 ]
done

echo
trap "echo 'I modified the trap!'" SIGINT



count=1
while [ $count -le 3 ]
do
  echo "Loop #$count"
  sleep 1
  count=$[ $count + 1 ]
done

```

如果想要移除捕获列表中的某个信号，可以使用 trap -- signals，来移除该信号。

```shell
#!/bin/bash

trap "echo 'Sorry! I have trapped Ctrl-C'" SIGINT

echo This is a test script

count=1
while [ $count -le 3 ]
do
  echo "Loop #$count"
  sleep 1
  count=$[ $count + 1 ]
done

echo
trap "echo 'I modified the trap!'" SIGINT



count=1
while [ $count -le 3 ]
do
  echo "Loop #$count"
  sleep 1
  count=$[ $count + 1 ]
done

```

如果想要恢复默认的捕获列表，只需要使用 trap -- 或者 trap - 命令。

# 16 以后台模式运行脚本

在命令行模式运行脚本时，有些脚本的运行时间会很长，导致这段时间内，我们无法去做其他事情。通过 ps 命令我们可以看到，会有许多进程，但这些进程都不是运行在我们的终端显示器上。这些进程被称为*后台进程* 。后台进程不会和终端会话中的 STDIN ，STDOUT ,STDERR相关联。

## 16.2.1 后台运行脚本

以后台模式运行脚本非常简单，只需要在命令后面加一个 &。

```shell
./test4.sh &
```

以后台模式运行后，shell会返回 作业号 和 进程id

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ ./test4.sh &
[1] 12534
```

后台进程完成后，终端会显示一条消息：

```shell
[1]+  Done                    ./test4.sh

这表明了作业的作业号以及作业状态（Done),还有用于启动作业的命令。
后台进程运行时，仍然会使用终端显示器来显示STDOUT 和 STDERR消息。
```

在后台运行的脚本，最好将 STDOUT 和 STDERR进程重定向，避免杂乱输出。

## 16.2.2 运行多个后台作业

通过ps命令，可以看到所有脚本处于运行状态

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ ps
    PID TTY          TIME CMD
   9529 pts/0    00:00:00 fish
   9734 pts/0    00:00:00 bash
  13048 pts/0    00:00:00 ps

```

通过查看ps命令的输出结果，可以看到每一个后台进程都和终端会话（pts/0) 联系在一起。如果终端会话退出，每一个后台进程也会随之退出。

>本章之前曾经提到过当你要退出终端会话时，要是存在被停止的进程，会出现警告信息。 但如果使用了后台进程，只有某些终端仿真器会在你退出终端会话前提醒你还有后台作 业在运行。

# 16.3 在非控制台下运行脚本

有时你希望以后台模式运行到结束，即使退出终端。这时候可以使用nohup指令。

nohup命令可以运行其他命令来阻断所有发给进程的SIGHUP信号。这会在退出终端会话时阻止进程退出。

```shell
$ nohup ./test1.sh &
[1] 3856
```

与普通后台进程一样，Linux系统会为该进程分配作业号和进程号。不同之处在于，当你使用nohup指令之后，脚本会忽略终端发过来的 SIGHUP 信号。

由于nohup指令会解除终端与进程之间的关系，解除与STDOUT和STDERR之间的联系。nohup指令会自动将输出内容重定向到nohup.out文件中。

# 16.4 作业控制

在作业停止之后，Linux系统会让你选择时终止还是继续运行。你可以通过kill命令来终止进程，也可以给进程发送SIGCONT信号来进行运行程序。

启动，终止，停止以及恢复作业的这些功能统称为作业控制。

### 16.4.1 查看作业

jobs命令可以查看shell当前正在处理的作业：

```shell
#!/bin/bash

echo "Script Process ID: $$"

count=1
while [ $count -le 10 ]
do 
  echo "Loop #$count"
  sleep 10
  count=$[ $count + 1]
done

echo "End of script..."
```

- “\$\$" 可以查看Linux系统分配给该进程的pid

jobs命令可以查看当前分配给shell的作业：

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ jobs
[1]+  Stopped                 bash test10.sh
[2]-  Running                 bash test10.sh > test10file &
```

jobs添加 -l 选项可以查看作业的 pid

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ jobs -l
[1]+ 14276 Stopped                 bash test10.sh
[2]- 14278 Running                 bash test10.sh > test10file &
```

jobs命令不同的命令行参数

- -l 列出进程的pid和作业号
- -n 列出上次shell发出通知后改变的作业
- -p 只列出作业的pid
- -r 列出正在运行中的作业
- -s 列出已停止的作业

在列出的作业列表中，+ 表示该作业为默认作业，所有的作业操作都是在该作业上进行（如果未在命令行前指定任何作业号）。如果该作业完成，则前面有 - 的作业将变为默认作业。无论什么时候，都只有一个带+和-的作业。

## 16.4.2 重启停止的作业

使用 fg + 作业号，可以重启暂停的作业，并以后台模式运行。

使用 fg + 作业号，可以重启暂停的作业，并以前台模式运行。

如果只使用fg ，会将默认的作业以前台模式运行。

# 16.5 调整谦让度

在多任务操作系统中，内核负责将CPU时间分配给系统上运行的每一个进程。调度优先级是内核分配给进程的CPU时间（相对于其他进程）。在LINUX系统中，由shell启动的所有进程的调度优先级默认是相同的。

调度的优先级是个整数值，取值范围是从 -20(最高优先级）到 19(最低优先级)。默认情况下，bash shell以优先级0来启动所有进程。

## 16.5.1 nice命令

用户可以通过nice命令，在脚本启动的命令中修改脚本的优先级。

```shell
$ nice -n 10 ./test4.sh &
```

查看进程的优先级是否发送了修改

```shell
ps -p pid -o pid,ppid,ni,cmd
```

nice命令阻止普通用户提高进程的优先级运行。但是作业会继续运行。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ nice -n -10 ./test4.sh > test4.out &
[1] 14709
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ nice: cannot set niceness: Permission denied
```

nice命令的-n选项不是必须的，只要在破折号后面加上优先级就可以了。

## 16.5.2 renice命令

可以通过renice来修改正在运行的作业的优先级。它可以通过指定正在运行的进程的PID来改变它的优先级。

```shell
$ ./test11.sh 
& [1] 5055 
$ 
$ ps -p 5055 -o pid,ppid,ni,cmd 
PID PPID NI CMD 
5055 4721 0 /bin/bash ./test11.sh $ $ renice -n 10 -p 5055 5055: old priority 0, new priority 10
$ 
$ ps -p 5055 -o pid,ppid,ni,cmd PID PPID NI CMD 
5055 4721 10 /bin/bash ./test11.sh $
```

renice和nice一样有着限制

- 只能对属于自己的进程执行renice
- 只能降低进程的优先级
- root用户可以通过renice来任意调整进程的优先级

# 16.6 定时运行作业

## 16.6.1 用at命令来计划执行作业

at命令会将作业提交到一个作业队列中，指定shell何时运行该作业。at的守护进程atd会以后台模式运行，定时检查作业队列来运行作业。大多数linux发行版会在启动时默认运行该守护进程。

atd守护进程会检查系统上的一个特殊目录（/var/spool/at）来获取用at命令提交的作业。默认情况下，atd守护进程会每隔60检查一次该目录。有作业时，atd守护进程会检查作业设置运行的时间。如果时间配置，atd守护进程会运行此作业。

1. at命令的基本格式

```bash
at [-f 脚本文件] 执行时间
``` 

- -f脚本文件：指定要执行的脚本
- 执行时间：可写now、noon、midnight、teatime，也能用 10:15、10:15PM 或者 now + 10 minutes这中写法

2. 时间格式写法

- `10:15`、`10:15 PM`
    
- `now`、`noon`、`midnight`、`teatime`（下午4点）
    
- `now + 25 minutes`
    
- `tomorrow 10:15`
    
- `10:15 + 7 days`
    
- `MMDDYY`、`MM/DD/YY`、`DD.MM.YY` 或 `Jul 4`、`Dec 25` 形式日期

3. 作业队列

- Linux 中 at 作业会进入**作业队列**
    
- 队列用 a~~z 和 A~~Z 表示，默认是 `a` 队列
    
- 越靠后的字母优先级越低（nice 值高）

4. 获取作业的输出

- 默认输出通过`sendmail`发邮件给当前用户（如果没有配置sendmail就无法看到）
- 常用方法：
	- 重定向输出到文件
	- 或者用`-M`参数阻止邮件输出

5. 查看等待的作业

```shell
atq
```

6. 删除等待的作业

```shell
atrm 作业号
```


## 16.6.2 安排需要定期执行的脚本

1. cron时间表

cron时间采用了一种特别的格式来指定作业何时运行。格式如下：

```bash
min hour dayofmonth moth dayofweek command
```

如果你想要每天的 10:15 运行一个命令，可以用 cron时间表条目:

```bash
15 10 * * * command
```

如果想要每周一4:15 PM运行的命令：

```bash
15 16 * * 1 command
```

在每个月的第一天中午12点执行命令。
可以用三字符的文本值（mon、tue、wed、thu、fri、sat、sun）或数值（0为周日，6为周六） 来指定dayofweek表项。

```shell
00 12 1 * * command
```

命令列表必须指定要运行的命令或脚本的全路径名。你可以像在普通的命令行中那样，添加 任何想要的命令行参数和重定向符号。 

```shell
15 10 * * * /home/rich/test4.sh > test4out 
```

cron程序会用提交作业的用户账户运行该脚本。因此，你必须有访问该命令和命令中指定的 输出文件的权限。

2. 构建cron时间表

每一个系统用户（包括root用户）都可以用自己的cron时间表来运行安排好的人物。linux提供了crontab命令来处理cron时间表。要列出已有的cron时间表，可以用-l选项。

```shell
crontab -l
```

默认情况下cron时间表并不存在，可以时用-e选项为cron时间表添加条目。

3. 浏览cron目录

如果创建的脚本对于精确的时间执行要求不高，可以使用预配置的cron脚本目录会更加方便。有四个基本目录：hourly, daily, monthly和weekly。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ ls /etc/cron.*ly
/etc/cron.daily:
0anacron  apport  apt-compat  dpkg  logrotate  man-db  plocate  sysstat

/etc/cron.hourly:

/etc/cron.monthly:
0anacron

/etc/cron.weekly:
0anacron  man-db

/etc/cron.yearly:

```

如果脚本需要每天执行，只要将脚本复制到daily目录，cron就会每天执行它。

4. anacron程序

 📖 cron 的特点

- 适合 **7×24 小时运行的系统**（如服务器）。
    
- 依据预定时间执行作业，但如果系统关机，**错过的作业不会补跑**。
    

 📖 anacron 的特点

- 适合 **不保证全天候开机的系统**（如个人电脑、普通工作站）。
    
- 如果作业在关机时错过，系统下次开机时 **自动补跑**。
    

📖 anacron 的工作原理

- 只管理 **以天为单位** 的周期任务（不处理小于一天的，如 `/etc/cron.hourly`）。
    
- 依赖 **时间戳文件**（位于 `/var/spool/anacron/`）判断上次执行时间。
    
- 根据时间表文件 `/etc/anacrontab` 中的配置决定：
    
    - **多长时间运行一次（以天为单位）**
        
    - **开机后延迟多少分钟再执行**
        
    - **作业标识符**
        
    - **具体执行命令**
        

 📖 `/etc/anacrontab` 配置示例

```bash
# 配置说明：
# period   delay   identifier     command
1          5       cron.daily      nice run-parts /etc/cron.daily
7         25       cron.weekly     nice run-parts /etc/cron.weekly
@monthly  45       cron.monthly    nice run-parts /etc/cron.monthly
```

- **period**：执行周期（单位：天，可用 `@monthly` 等特殊值）
    
- **delay**：开机后延迟时间（单位：分钟）
    
- **identifier**：作业标识符（便于日志记录和邮件通知）
    
- **command**：执行命令（一般用 `run-parts` 运行目录下所有脚本）
    

 📖 其他参数

- `RANDOM_DELAY`：为作业增加随机延迟，防止同时执行太多任务。
    
- `START_HOURS_RANGE`：限制作业只在某个时间段内执行。
    
