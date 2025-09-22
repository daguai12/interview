# CORO_BENCHMARK3

好的，这个宏是作者为了简化 Google Benchmark 测试代码而创建的一个“快捷方式”。它本身不是 Google Benchmark 的标准功能，而是 `tinycoro` 项目自定义的一个宏，定义在 `bench_helper.hpp` 文件中。

我们来逐行解释这个宏的作用：

```cpp
#define CORO_BENCHMARK3(bench_name, para, para2, para3)       \
    BENCHMARK(bench_name)                                    \
        ->MeasureProcessCPUTime()                            \
        ->UseRealTime()                                      \
        ->Unit(benchmark::TimeUnit::kMillisecond)            \
        ->Arg(para)                                          \
        ->Arg(para2)                                         \
        ->Arg(para3)
```

当您在代码中这样写：

```cpp
CORO_BENCHMARK3(threadpool_stl_latch, 100, 100000, 100000000);
```

C++ 预处理器会把它**展开**成下面这样一段完整的 Google Benchmark 代码：

```cpp
BENCHMARK(threadpool_stl_latch)
    ->MeasureProcessCPUTime()
    ->UseRealTime()
    ->Unit(benchmark::TimeUnit::kMillisecond)
    ->Arg(100)
    ->Arg(100000)
    ->Arg(100000000);
```

现在，我来解释展开后的每一行的具体含义：

1.  **`BENCHMARK(threadpool_stl_latch)`**

      * 这是最核心的注册宏，告诉 Google Benchmark：“`threadpool_stl_latch` 这个函数是一个需要进行性能测试的基准。”

2.  **`->MeasureProcessCPUTime()`**

      * 这是一个**配置选项**。它告诉测试框架，在测量真实时间（墙上时钟时间）的同时，也请**测量并报告进程消耗的CPU时间**。这有助于分析代码是受限于CPU计算，还是受限于等待（如I/O等待）。

3.  **`->UseRealTime()`**

      * 这个选项**让测试基于真实时间来运行**。Google Benchmark 默认就是这样，但这里明确写出来可以增强代码的可读性。

4.  **`->Unit(benchmark::TimeUnit::kMillisecond)`**

      * 这个选项**设置了报告结果时使用的时间单位**。这里指定了**毫秒（ms）**。这样，您在报告中看到的 `Time` 和 `CPU` 列的数值单位就是毫秒。

5.  **`->Arg(100)`**, **`->Arg(100000)`**, **`->Arg(100000000)`**

      * 这三行是参数化测试的关键。它们告诉 Google Benchmark，对于 `threadpool_stl_latch` 这同一个测试函数，需要**独立地运行三次**：
          * 第一次运行时，将 `100` 作为参数传入。
          * 第二次运行时，将 `100000` 作为参数传入。
          * 第三次运行时，将 `100000000` 作为参数传入。
      * 在函数内部，代码通过 `state.range(0)` 来获取这些传入的参数值，从而在不同的负载下测试性能。

### 总结

所以，`CORO_BENCHMARK3` 这个宏的本质是：**用一种简洁的方式，注册一个需要用三种不同参数来运行的、以毫秒为单位、同时测量CPU时间和真实时间的性能测试用例。**

作者定义这个宏，是为了避免在每个测试文件中都重复写后面那一长串的配置代码，让代码更加整洁和易于维护。