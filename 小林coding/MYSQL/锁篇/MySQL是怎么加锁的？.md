# 什么SQL语句会加行级锁？

在 MySQL (InnoDB 引擎) 中，行级锁是实现并发控制的关键。会触发“当前读” (Current Read) 的 SQL 语句都会加行级锁。

这些语句主要分为两大类：

### 1\. 🔒 加排他锁 (Exclusive Locks, X 锁)

排他锁（X 锁）会**阻塞**其他事务对这一行（或间隙）**所有的**读锁（S 锁）和写锁（X 锁）请求。简单说：**我正在用，谁也别碰（不能读也不能写）**。

会加 X 锁的 SQL 语句包括：

  * **`UPDATE`**

    ```sql
    -- 对 id=10 的行加 X 锁
    UPDATE users SET age = 30 WHERE id = 10;
    ```

  * **`DELETE`**

    ```sql
    -- 对 id=10 的行加 X 锁
    DELETE FROM users WHERE id = 10;
    ```

  * **`INSERT`**

    ```sql
    -- 对新插入的这行 (id=11) 加 X 锁
    INSERT INTO users (id, name) VALUES (11, 'David');
    ```

    *（`INSERT` 还会使用“插入意向锁”来检查间隙，这是一种特殊的间隙锁）*

  * **`SELECT ... FOR UPDATE`**

    ```sql
    -- 显式地对 id=10 的行加 X 锁
    -- 其他事务不能修改它，也不能加S锁
    SELECT * FROM users WHERE id = 10 FOR UPDATE;
    ```

### 2\. 🤝 加共享锁 (Shared Locks, S 锁)

共享锁（S 锁）会**阻塞**其他事务对这一行（或间隙）的**写锁（X 锁）请求，但允许**其他事务**也来加共享锁（S 锁）**。简单说：**大家可以一起读，但谁都不能改**。

会加 S 锁的 SQL 语句包括：

  * **`SELECT ... LOCK IN SHARE MODE`**
    ```sql
    -- 显式地对 id=10 的行加 S 锁
    -- 其他事务可以一起读 (也加S锁)，但不能修改它
    SELECT * FROM users WHERE id = 10 LOCK IN SHARE MODE;
    ```
  * *(在 MySQL 8.0+ 中，推荐使用 `FOR SHARE`，它是 `LOCK IN SHARE MODE` 的别名)*
    ```sql
    SELECT * FROM users WHERE id = 10 FOR SHARE;
    ```

-----

### ⚠️ 特别注意：索引的重要性

InnoDB 的行锁是**通过锁定索引记录**来实现的。

  * **如果你的 `WHERE` 子句命中了索引（主键、唯一索引、普通索引）**：
    InnoDB 会使用我们之前讨论过的 **Record Lock**（记录锁）、**Gap Lock**（间隙锁）或 **Next-Key Lock**（临键锁）来精确地锁定相关的索引条目。

  * **如果你的 `WHERE` 子句没有使用任何索引**：
    这是一个非常危险的操作！InnoDB 将**无法**使用行锁。
    它有两种可能的（都很糟糕的）行为：

    1.  **退化为表锁**：直接锁定整张表。
    2.  **全表扫描并锁住每一行**：InnoDB 会扫描表中的**每一条聚簇索引记录**（每一行数据），并给**每一行都加上 X 锁**。

**结论：** 在执行 `UPDATE`, `DELETE`, 或 `SELECT ... FOR UPDATE/SHARE` 时，**一定要确保 `WHERE` 子句中的条件字段上有可用的索引**，否则你的高并发系统会因为行锁“升级”为表锁而瞬间瘫痪。


