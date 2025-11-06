# 快照读和当前读 
### 1\. 💨 快照读 (Snapshot Read)

快照读读取的是数据的**历史版本快照**。它是一种**非锁定**的读取操作，不会阻塞其他事务的写入。

  * **隔离级别**：

      * 在 **Repeatable Read (RR)** 级别下，快照是在**事务开始时**创建的。事务期间无论其他事务如何提交，它读到的都是事务刚开始时的那个版本。
      * 在 **Read Committed (RC)** 级别下，快照是在**每条 `SELECT` 语句执行时**创建的。所以能读到其他事务已经提交的最新数据。

  * **SQL 语句示例**：

    > 就是最普通的 `SELECT` 语句，不带任何锁。

    ```sql
    -- 这是一个快照读
    SELECT * FROM users WHERE id = 1;
    ```

-----

### 2\. 🔒 当前读 (Current Read)

当前读读取的是数据的**最新提交版本**，并且会对读取到的记录**加锁**，以保证在事务提交前，其他事务不能修改这些记录。

  * **SQL 语句示例**：

    > 所有会修改数据的操作和显式加锁的查询都是当前读。

      * **显式加锁查询 (悲观锁)**：

        ```sql
        -- 加共享锁 (Shared Lock)
        -- 其他事务可以读，也可以加共享锁，但不能加排他锁 (不能修改)
        SELECT * FROM users WHERE id = 1 LOCK IN SHARE MODE;

        -- 加排他锁 (Exclusive Lock)
        -- 其他事务不能读 (加共享锁) 也不能写 (加排他锁)
        SELECT * FROM users WHERE id = 1 FOR UPDATE;
        ```

      * **数据修改操作 (DML)**：

        ```sql
        -- 这些操作在执行时，会先 "当前读" 找到最新的数据，然后加锁修改
        INSERT INTO users (id, name) VALUES (2, 'Bob');

        UPDATE users SET name = 'Charlie' WHERE id = 1;

        DELETE FROM users WHERE id = 1;
        ```

-----

### 💡 场景对比 (SQL 示例)

假设我们使用的是 MySQL 默认的 **Repeatable Read (RR)** 隔离级别。

**表结构和初始数据**：

```sql
CREATE TABLE users (
    id INT PRIMARY KEY,
    name VARCHAR(50)
);
INSERT INTO users VALUES (1, 'Alice');
```

#### 场景演示

| 时间 | 事务 A (Session 1) | 事务 B (Session 2) | 事务 A 读到的数据 |
| :--- | :--- | :--- | :--- |
| T1 | `START TRANSACTION;` | | |
| T2 | `SELECT * FROM users WHERE id = 1;` <br> **(快照读)** | | 'Alice' (在 T1 创建的快照) |
| T3 | | `START TRANSACTION;` | |
| T4 | | `UPDATE users SET name = 'Bob' WHERE id = 1;` <br> **(当前读 + 加锁)** | |
| T5 | | `COMMIT;` | |
| T6 | `SELECT * FROM users WHERE id = 1;` <br> **(快照读)** | | 'Alice' (事务A坚持读T1的快照) |
| T7 | `SELECT * FROM users WHERE id = 1 FOR UPDATE;` <br> **(当前读)** | | 'Bob' (读取最新提交版本并加锁) |
| T8 | `UPDATE users SET name = 'Charlie' WHERE id = 1;` | | |
| T9 | `COMMIT;` | | |

#### 总结：

  * **快照读 (T6)**：即使事务 B 已经提交了修改 (`name = 'Bob'`)，事务 A 的普通 `SELECT` 依然读取它在 T1 时刻创建的快照，结果是 'Alice'。这就是 RR 级别下的“可重复读”。
  * **当前读 (T7)**：当事务 A 使用 `SELECT ... FOR UPDATE` 时，它必须去读取**最新的已提交版本**，所以它读到了 'Bob'，并且会给这一行加上排他锁。


# 什么是幻读？

### 👻 什么是幻读 (Phantom Read)？

**幻读**（Phantom Read）是指在一个事务（T1）中，**两次执行同一个范围查询**（例如 `WHERE age > 20`），但这两次查询返回的**结果集（行数）不同**。

这是因为在 T1 两次查询的间隙，另一个事务（T2）\*\*插入（INSERT）或删除（DELETE）\*\*了符合该查询条件的数据，并成功提交了。

对于 T1 来说，这些“凭空出现”或“凭空消失”的行就像“幻影”一样，因此得名“幻读”。

-----

### 💡 关键区别：幻读 vs 不可重复读

这是最容易混淆的地方，我帮你澄清一下：

>   * **不可重复读 (Non-Repeatable Read):**
>
>       * **重点是：修改 (UPDATE)**
>       * 事务 T1 读取了**同一行**数据两次，但两次读到的**内容**不一样了。
>       * *例如：* T1 读到 `id=1` 的 `name='Alice'`，T2 将其 `UPDATE` 为 `name='Bob'` 并提交，T1 再次读取 `id=1`，读到 `name='Bob'`。
>
>   * **幻读 (Phantom Read):**
>
>       * **重点是：新增 (INSERT) 或 删除 (DELETE)**
>       * 事务 T1 执行了**同一个范围查询**两次，但两次读到的**行数**不一样了。
>       * *例如：* T1 查询 `age > 20` 得到 5 行，T2 `INSERT` 了一条 `age=25` 的新数据并提交，T1 再次查询 `age > 20`，得到了 6 行。

**简单记：不可重复读是“数据内容变了”，幻读是“行数变了”。**

-----

### SQL 场景示例

我们以一个**未解决幻读**的隔离级别（例如 **Read Committed (RC)**）为例：

**表结构和初始数据**：

```sql
CREATE TABLE employees (
    id INT PRIMARY KEY,
    name VARCHAR(50),
    age INT
);
INSERT INTO employees VALUES (1, 'Alice', 20);
INSERT INTO employees VALUES (2, 'Bob', 30);
```

| 时间 | 事务 A (隔离级别: Read Committed) | 事务 B | 事务 A 读到的数据 |
| :--- | :--- | :--- | :--- |
| T1 | `START TRANSACTION;` | | |
| T2 | `SELECT * FROM employees WHERE age > 25;` | | (1 行数据: 'Bob') |
| T3 | | `START TRANSACTION;` | |
| T4 | | `INSERT INTO employees (id, name, age) VALUES (3, 'Charlie', 40);` | |
| T5 | | `COMMIT;` | |
| T6 | `SELECT * FROM employees WHERE age > 25;` | | (2 行数据: 'Bob', 'Charlie') |
| T7 | `COMMIT;` | | |

**分析**：
在 T6 时刻，事务 A 再次执行**完全相同**的 `SELECT` 语句，但发现结果集里多了一个 "Charlie"。对于事务 A 来说，"Charlie" 这条记录就像一个“幻影”，这就是幻读。

-----

### MySQL (InnoDB) 如何解决幻读？

你可能会问：为什么我用 MySQL 默认的 **Repeatable Read (RR)** 级别时，好像没有幻读？

这是因为 InnoDB 在 **RR** 级别下，通过两种方式“**在很大程度上**”解决了幻读问题：

**1. 针对“快照读” (普通 SELECT)：**

  * **使用 MVCC**：事务 A 在 T1 开始时创建了一个快照。即使 T2 在 T5 提交了 'Charlie'，事务 A 在 T6 执行的**快照读**（普通 `SELECT`）仍然读取 T1 时刻的快照，因此它**看不见** 'Charlie'。
  * *结果：* 对于快照读，RR 级别避免了幻读。

**2. 针对“当前读” (SELECT ... FOR UPDATE / UPDATE / DELETE)：**

  * **使用间隙锁 (Gap Lock) 和 Next-Key Lock**：
  * 如果事务 A 在 T2 执行的是**当前读**，例如 `SELECT * FROM employees WHERE age > 25 FOR UPDATE;`
  * InnoDB 不仅会锁住 'Bob' (age=30) 这行，还会**锁住 (25, 30) 之间**以及 **(30, 正无穷)** 之间的“**间隙 (Gap)**”。
  * 当事务 B 试图在 T4 执行 `INSERT ... (age = 40)` 时，它会发现 `(30, 正无穷)` 这个间隙已经被 T1 锁住了。
  * 事务 B 的 `INSERT` 操作会被**阻塞**，直到事务 A (T1) 提交或回滚。
  * *结果：* 对于当前读，通过 Gap Lock 阻止了其他事务的 `INSERT`，从而避免了幻读。

需要我为你详细解释一下“间隙锁”(Gap Lock) 是如何工作的吗？

# 快照读是如何避免幻读的？

# 当前读是如何避免幻读的？

# 幻读被完全解决了吗？

