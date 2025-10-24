下面把 `std::make_shared` / `std::make_unique` 与直接用 `new` + 智能指针构造（例如 `std::shared_ptr<T>(new T(...))`、`std::unique_ptr<T>(new T(...))`）的**差别、优缺点、实现细节与常见陷阱**讲清楚——带示例、适用建议和必要的实现/标准要点引用。

# 1 概要结论（先看要点）

* `make_shared`：通常**把对象和 control-block 一次性分配**（单次堆分配），因此更省内存、分配次数少、缓存局部性好，也是常推荐的 `shared_ptr` 创建方式。但不能直接指定自定义删除器，且因为对象和控制块在同一块内存，**长寿命的 `weak_ptr` 会延长整个块（包括对象本身）的寿命**。([Stack Overflow][1])
* `shared_ptr<T>(new T(...))`：通常会**分别分配**对象与 control-block（两次分配），允许自定义删除器或其他特殊行为（也可用 `allocate_shared` 指定 allocator 来实现合并分配）。在某些表达式/多参数场景下使用裸 `new` 可能带来异常时的窃取 / 泄漏风险（见下文）。([Cppreference][2])
* `make_unique`：比 `unique_ptr<T>(new T(...))` 更**异常安全**（避免短暂裸指针在复杂表达式中被遗忘），写法更简洁，推荐用 `make_unique`（C++14 起提供）。([ISO C++][3])

---

# 2 `make_shared` vs `shared_ptr(new T(...))` — 详细对比

## a) 内存分配（单次 vs 两次）

* `make_shared<T>(...)` 通常在一次堆分配中同时分配：**control block + 被管理对象** 放在同一内存块（所以只有一次 `operator new`）。这减少了分配/释放次数并提升缓存局部性，性能通常更好。
* `shared_ptr<T>(new T(...))` 常见实现会单独为对象 `new T` 分配，再为 control block 分配另一块内存（两次分配）。因此开销更大。([Stack Overflow][1])

## b) 对 `weak_ptr` / 控制块生存期的影响

* 因为 `make_shared` 把对象和控制块合并，一旦 control block 由于 `weak_ptr` 存在而不能释放，**对象本身也会被延长生存**（即长寿命的 `weak_ptr` 会让对象的内存块一直存在，直到最后一个 `weak_ptr` 被销毁）。在某些内存/生命周期策略下，这可能不是你想要的。相反，分开分配时（`new` + control-block 分开），当最后一个 `shared_ptr` 释放对象后，对象的内存会被释放，而 control block（足够小）由 `weak_ptr` 维持。([Microsoft for Developers][4])

## c) 自定义删除器（和 allocator）

* `shared_ptr(ptr, deleter)` 可以显式传入自定义删除器。**`make_shared` 不支持传自定义删除器**（有 `allocate_shared` 可用于定制 allocator，但不是直接传删 除器的替代）。如果你必须使用特殊删除方式（例如对象来自 `malloc`、或需要特殊清理），`make_shared` 不是合适选择。([Cppreference][2])

## d) 异常安全细节（什么时候会泄漏）

* 单独写 `std::shared_ptr<T> p(new T(...));` 本身在多数实现/场景下是**不会在 shared\_ptr 构造失败时泄漏该裸指针**（实现会在控制块分配失败时释放传入的裸指针），但存在更细微/实际的危险场景：

  * 当你把 `new` 直接写入更大表达式（例如作为函数多个参数中的一个）时，**参数求值顺序**和中途抛出异常可能使临时裸指针来不及被智能指针接管，造成泄漏（例如 `foo(shared_ptr<T>(new T), …other args… )`，如果 other args 的某个计算抛出，可能导致泄漏）。`make_shared`（或 `make_unique`）可以让你避免这类“裸 `new` 暂时裸露在表达式中”的风险。相关讨论与静态分析工具也有类似告警。([Stack Overflow][5])

> 实务建议：不要在复杂表达式里直接写裸 `new`，尽量先用 `make_shared/make_unique` 或先把智能指针名绑定到局部变量再传参。

## e) 类特定 `operator new` 的差异

* `make_shared` 使用全局 `::new` 来分配组合块（control block + object），因此如果类对 `operator new` 做了重载/自定义，`make_shared` 的分配行为可能与 `shared_ptr<T>(new T(...))` 不同（后者直接调用类的 `operator new`），这在非常罕见但需要严格控制分配策略的情形下很重要。([Cppreference][2])

---

# 3 `make_unique` vs `unique_ptr<T>(new T(...))` — 要点

* `make_unique<T>(...)`（C++14 起）主要优势是**异常安全和简洁**：在构造多个临时 `unique_ptr` 作为参数时，`make_unique` 可以避免裸指针瞬时存在导致的泄漏风险。`make_unique` 也能推断模板参数，代码更清爽。([ISO C++][3])
* `unique_ptr` 支持自定义删除器（构造时传入），而 `make_unique` 只能用于常规 delete 场景（不过你可以直接构造 `unique_ptr<T,Deleter>(new T, deleter)` 当需要时）。
* `make_unique<T[]>` 支持数组版本（`unique_ptr<T[]>`），而 `make_shared` 没有数组版本。（注：`make_unique` 是 C++14 标准补充; C++11 中没有它，不过可以自行实现简单模板替代。）([GeeksforGeeks][6])

---

# 4 常见使用建议（实战）

1. **优先 `make_unique`**（C++14 起）替代 `unique_ptr<T>(new ...)`，因为更安全、简洁。([ISO C++][3])
2. **需要 `shared_ptr` 时优先考虑 `make_shared`**（如果不需自定义删除器/特定分配行为），因为性能与异常安全优势。([Stack Overflow][1])
3. **若有长寿命的 `weak_ptr` 或需要单独控制对象与 control-block 的释放**，考虑使用 `shared_ptr<T>(new T(...))` 或 `allocate_shared`（更细粒度控制）。（`make_shared` 合并分配会使弱引用延长对象内存的存在）([Microsoft for Developers][4])
4. **需要自定义删除器时**：不能用 `make_shared`（用 `shared_ptr<T>(new T, deleter)` 或 `allocate_shared` + custom allocator），对于 `unique_ptr` 可在类型中或构造时传 deleter。([Cppreference][2])
5. **避免把 `new` 直接写在复杂表达式中**（传参、临时构造等），因为可能产生意外的异常安全问题；改用 `make_*` 或先建临时命名变量再传。([MathWorks][7])

---

# 5 代码示例（一目了然）

```cpp
#include <memory>
#include <vector>

// 推荐（优先）
auto sp = std::make_shared<MyType>(args...);   // single alloc, efficient

// 如果需要 custom deleter:
std::shared_ptr<MyType> sp2(new MyType(args...), [](MyType* p){ custom_delete(p); });

// allocate_shared 可以用自定义 allocator（合并分配 + allocator）
auto sp3 = std::allocate_shared<MyType>(alloc, args...);

// unique_ptr 推荐
auto up = std::make_unique<MyType>(args...);

// 不该在参数列表里直接 new：
foo(std::shared_ptr<A>(new A(...)), std::shared_ptr<B>(new B(...))); // 不推荐：在某种执行顺序下可能有风险
// 改为：
auto a = std::make_shared<A>(...);
auto b = std::make_shared<B>(...);
foo(a, b);
```

---

# 6 小结（一句话）

* `make_unique` / `make_shared` 的设计目标是**更安全、更高效、写法更清晰**。默认首选 `make_unique`（表示独占）和 `make_shared`（需要共享时），仅在确有理由（自定义删除器、特殊分配、控制 control-block 行为或避免合并分配的弱引用副作用）时使用 `new` + 智能指针构造或 `allocate_shared`。([ISO C++][3])

---

如果你愿意，我可以：

* 帮你把项目里所有 `new` -> `make_unique/make_shared` 的替换点列成 `clang-tidy` / `grep` 风格的检查清单；或
* 给出一个小测试程序演示“make\_shared 合并分配导致 weak\_ptr 延长对象生存” 的行为（并测量内存占用/释放时刻）。

想要哪一个？

[1]: https://stackoverflow.com/questions/20895648/difference-in-make-shared-and-normal-shared-ptr-in-c?utm_source=chatgpt.com "Difference in make_shared and normal shared_ptr in C++"
[2]: https://en.cppreference.com/w/cpp/memory/shared_ptr/make_shared.html?utm_source=chatgpt.com "std::make_shared, std::make_shared_for_overwrite"
[3]: https://isocpp.org/blog/2019/06/quick-q-differences-between-stdmake-unique-and-stdunique-ptr-with-new?utm_source=chatgpt.com "Quick Q: Differences between std::make_unique and ..."
[4]: https://devblogs.microsoft.com/oldnewthing/20230815-00/?p=108602&utm_source=chatgpt.com "Inside STL: The shared_ptr constructor vs make_shared"
[5]: https://stackoverflow.com/questions/20053504/stdshared-ptr-exception-safety?utm_source=chatgpt.com "std::shared_ptr Exception Safety - c++"
[6]: https://www.geeksforgeeks.org/cpp/cpp-14-make_unique/?utm_source=chatgpt.com "std::make_unique in C++ 14"
[7]: https://la.mathworks.com/help/bugfinder/ref/misracpp2023rule23.11.1.html?utm_source=chatgpt.com "MISRA C++:2023 Rule 23.11.1"
