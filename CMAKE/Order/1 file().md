### CMake 中 file() 命令的详细教程

CMake 的 `file()` 命令是一个功能强大的内置命令，用于处理文件系统操作，包括读取/写入文件、生成文件列表、复制/删除文件、创建目录、重命名、计算哈希、时间戳等。它是 CMake 脚本中处理文件和路径的核心工具，尤其适用于自动化生成配置文件、收集源文件或进行文件传输。`file()` 命令在配置阶段执行（非生成阶段），跨平台支持（Windows、Linux、macOS），但某些操作（如路径转换）已被更现代的 `cmake_path()` 命令取代（推荐用于纯路径操作）。

**注意**：`file()` 需要文件系统访问权限。如果文件不存在或权限不足，会静默失败或设置变量为空。官方文档（CMake 4.1.2+）强调，对于构建输入文件，优先用 `configure_file()` 以避免不必要的更新。

#### 1. file() 命令的基本语法
```
file(<command> [arguments...])
```
- `<command>`：子命令，指定操作类型（如 `READ`、`WRITE`、`GLOB` 等）。每个子命令有特定参数。
- `[arguments...]`：根据子命令的不同，包括文件名、变量名、内容、选项等。
- 返回值：大多数子命令将结果存入变量（如文件内容、列表），或直接执行操作（如写入）。
- 常见选项：许多子命令支持 `ENCODING <type>`（如 UTF-8，用于中文/特殊字符）和 `OFFSET/LIMIT`（用于二进制处理）。

`file()` 支持约 30 个子命令，按功能分类：读取、写入、文件系统操作、路径转换、传输、锁定、归档、运行时二进制等。下面按类别详细列出主要子命令（基于官方文档）。

#### 2. 子命令详细说明
##### 2.1 读取子命令（Reading）
这些用于从文件中提取内容。

- **READ**
  - 语法：`file(READ <filename> <variable> [OFFSET <offset>] [LIMIT <max-in>] [HEX] [ENCODING <encoding-type>])`
  - 描述：读取 `<filename>` 的内容（全部或部分）到 `<variable>`。支持二进制（用 `HEX` 转为十六进制字符串）。
  - 参数：
    - `<filename>`：文件路径（相对或绝对）。
    - `<variable>`：输出变量。
    - `OFFSET <offset>`：起始字节偏移（默认 0）。
    - `LIMIT <max-in>`：最大读取字节（默认全部）。
    - `HEX`：转为小写十六进制（a-f）。
    - `ENCODING <type>`：编码（如 UTF-8、UTF-16LE；CMake 3.1+）。
  - 示例：`file(READ "config.txt" CONTENT)` → `CONTENT` 包含文件内容。
  - 注意：文件不存在时，`<variable>` 为空。用于模板读取。

- **STRINGS**
  - 语法：`file(STRINGS <filename> <variable> [LENGTH_MINIMUM <min>] [LENGTH_MAXIMUM <max>] [LIMIT_COUNT <max-num>] [LIMIT_INPUT <max-in>] [LIMIT_OUTPUT <max-out>] [REGEX <regex>] [ENCODING <type>] [NEWLINE_CONSUME] [NO_HEX_CONVERSION])`
  - 描述：解析 `<filename>` 中的 ASCII 字符串（忽略二进制/控制字符），存入 `<variable>` 作为列表。过滤长度、数量、正则等。
  - 参数：
    - `LENGTH_MINIMUM/MAXIMUM`：字符串长度范围。
    - `LIMIT_COUNT`：最大独特字符串数。
    - `LIMIT_INPUT/OUTPUT`：输入/输出字节限。
    - `REGEX <regex>`：正则过滤（Perl 风格；CMake 3.29+ 支持捕获组）。
    - `ENCODING <type>`：如 UTF-8。
    - `NEWLINE_CONSUME`：保留换行作为内容部分。
    - `NO_HEX_CONVERSION`：禁用自动十六进制转换。
  - 示例：`file(STRINGS "versions.txt" VERSIONS REGEX "[0-9.]+")` → 提取版本号列表。
  - 注意：默认忽略 CR 字符，适合日志/配置解析。

- **HASH**
  - 语法：`file(<HASH> <filename> <variable>)`（`<HASH>` 如 MD5、SHA256）。
  - 描述：计算文件内容的哈希值，存入 `<variable>`。支持算法见 `string(<HASH>)`。
  - 示例：`file(SHA256 "file.bin" HASH_VAL)` → `HASH_VAL = e3b0c442...`。
  - 注意：用于校验文件完整性。

- **TIMESTAMP**
  - 语法：`file(TIMESTAMP <filename> <variable> [<format>] [UTC])`
  - 描述：获取文件修改时间戳字符串，存入 `<variable>`（格式见 `string(TIMESTAMP)`）。
  - 参数：`<format>` 如 `%Y-%m-%d`；`UTC` 用 UTC 时间。
  - 示例：`file(TIMESTAMP "src.cpp" BUILD_TIME "%Y-%m-%d %H:%M:%S")`。
  - 注意：文件不存在时为空。

##### 2.2 写入子命令（Writing）
- **WRITE**
  - 语法：`file(WRITE <filename> <content>...)`
  - 描述：写入 `<content>` 到 `<filename>`（覆盖或创建）。自动创建父目录。
  - 示例：`file(WRITE "output.txt" "Hello World")`。
  - 注意：多行内容用 `\n` 分隔。优先用 `configure_file()` 处理模板。

- **APPEND**
  - 语法：`file(APPEND <filename> <content>...)`
  - 描述：追加 `<content>` 到文件末尾。
  - 示例：`file(APPEND "log.txt" "New entry\n")`。
  - 注意：用于日志记录。

- **CONFIGURE**
  - 语法：`file(CONFIGURE OUTPUT <output-file> CONTENT <content> [IMMEDIATE] [ENCODING <type>] [NEWLINE_STYLE <style>] [ESCAPE_QUOTES])`（CMake 3.0+）。
  - 描述：从 `<content>` 生成 `<output-file>`，替换 `${VAR}` 或 `@VAR@`。
  - 参数：`IMMEDIATE` 立即执行；`NEWLINE_STYLE` 如 UNIX/LF；`ESCAPE_QUOTES` 转义引号。
  - 示例：用于生成带变量的文件。

##### 2.3 文件系统操作（Filesystem）
- **COPY**
  - 语法：`file(COPY <files>... DESTINATION <dir> [FILE_PERMISSIONS <perms>...] [DIRECTORY_PERMISSIONS <perms>...] [FILES_MATCHING]) [FOLLOW_SYMLINK_CHAIN] [FILES_MATCHING_PATTERN <pattern> | REGEX <regex>] [NO_SOURCE_PERMISSIONS] [TIMESTAMP <time>]`
  - 描述：复制文件/目录到目标。支持权限、模式匹配。
  - 示例：`file(COPY "src/" DESTINATION "build/")`。

- **CREATE_LINK**
  - 语法：`file(CREATE_LINK <original> <linkname> [RESULT <result>] [COPY_ON_ERROR] [SYMBOLIC])`
  - 描述：创建硬链接或符号链接（`SYMBOLIC`）。
  - 示例：`file(CREATE_LINK "lib.so" "lib.so.1")`。

- **REMOVE** / **REMOVE_RECURSE**
  - 语法：`file(REMOVE <files>...)` / `file(REMOVE_RECURSE <files>...)`
  - 描述：删除文件（`REMOVE`）或递归删除目录（`REMOVE_RECURSE`）。
  - 示例：`file(REMOVE_RECURSE "build/")`。

- **RENAME**
  - 语法：`file(RENAME <oldname> <newname>)`
  - 描述：重命名文件/目录。
  - 示例：`file(RENAME "old.txt" "new.txt")`。

- **MAKE_DIRECTORY**
  - 语法：`file(MAKE_DIRECTORY <dir>...)`
  - 描述：创建目录（多级）。
  - 示例：`file(MAKE_DIRECTORY "build/generated")`。

- **GLOB** / **GLOB_RECURSE**
  - 语法：`file(GLOB <variable> <globbing-expressions>... [RELATIVE <path>] [CONFIGURE_DEPENDS])` / `file(GLOB_RECURSE <variable> <globbing-expressions>... [RELATIVE <path>] [CONFIGURE_DEPENDS] [FOLLOW_SYMLINKS])`
  - 描述：生成匹配 `*` 通配的文件列表到 `<variable>`（分号分隔）。`RECURSE` 递归子目录。
  - 示例：`file(GLOB SOURCES "src/*.cpp")`。
  - 注意：`CONFIGURE_DEPENDS` 使文件变化时重新配置（3.12+）。

- **SIZE**
  - 语法：`file(SIZE <filename> <variable>)`
  - 描述：获取文件大小（字节）到 `<variable>`。
  - 示例：`file(SIZE "data.bin" FILE_SIZE)`。

##### 2.4 路径转换（Path Conversion，部分已弃用）
- **RELATIVE_PATH**、`TO_CMAKE_PATH`、`TO_NATIVE_PATH`：转换为相对路径、CMake 风格路径（/ 分隔）、原生路径（\ 分隔）。CMake 3.20+ 推荐用 `cmake_path()` 替代。

##### 2.5 传输/下载（Transfer/Download）
- **DOWNLOAD** / **UPLOAD**
  - 语法：`file(DOWNLOAD <url> <file> [SHOW_PROGRESS] [TIMEOUT <seconds>] [STATUS <status>] [LOG <log>] [EXPECTED_HASH <algo>=<hash_value>] [EXPECTED_MD5 <md5>] [TLS_VERIFY ON|OFF] [TLS_CAINFO <file>] [NETRC <level>] [NETRC_FILE <file>] [HTTPHEADER <header>] [HTTPAUTH <type>] [HTTPUSERNAME <user>] [HTTPPASSWORD <pass>] [HTTPPROXY <host>] [HTTPPROXYUSER <user>] [HTTPPROXYPASSWORD <pass>] [HTTPSERVERAUTH <type>] [HTTPSERVERUSERNAME <user>] [HTTPSERVERPASSWORD <pass>] [INACTIVITY_TIMEOUT <seconds>] [FAIL_ON_ERROR])`
  - 描述：从 URL 下载到文件（`DOWNLOAD`）或上传（`UPLOAD`）。支持进度、哈希验证、代理、认证。
  - 示例：`file(DOWNLOAD "https://example.com/data.txt" "local.txt" STATUS DL_STATUS)`。

##### 2.6 其他（Locking, Archiving, Runtime Binaries）
- **LOCK**：文件锁定（`file(LOCK <path> [GUARD <var>] [RELEASE])`）。
- **ARCHIVE_CREATE** / **ARCHIVE_EXTRACT**：创建/提取 ZIP/TAR 归档（CMake 3.15+）。
- **GENERATE**：生成导出文件（`file(GENERATE OUTPUT <file> ...)`，CMake 3.18+，用于运行时二进制）。

#### 3. 案例选择：一个简单的配置文件生成器
我们用一个 C++ 项目示例：从 `version.txt` 读取版本，生成 `config.h`（替换模板），复制到构建目录，并生成源文件列表。演示 `READ`、`WRITE`、`GLOB`、`COPY`、`MAKE_DIRECTORY`。

**项目结构**：
```
my_project/
├── CMakeLists.txt
├── version.txt  # 内容: "Version: 1.2.3"
└── src/
    └── main.cpp  # #include "config.h" \n int main() { return 0; }
```

- `config.h.in`（模板，在 include/）：`#define VERSION "@VER@"`

**完整的 CMakeLists.txt**：
```cmake
cmake_minimum_required(VERSION 3.10)
project(MyProject)

set(CMAKE_CXX_STANDARD 11)

# 1. READ 读取版本
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/version.txt" VERSION_CONTENT)
string(REGEX MATCH "Version: ([0-9.]+)" _ "${VERSION_CONTENT}")
set(PROJECT_VER "${CMAKE_MATCH_1}")

# 2. GLOB 生成源列表
file(GLOB SOURCES "src/*.cpp")

# 3. MAKE_DIRECTORY 创建目录
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/generated")

# 4. COPY 复制模板
file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/include/config.h.in"
     DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/generated")

# 5. RENAME 重命名
file(RENAME "${CMAKE_CURRENT_BINARY_DIR}/generated/config.h.in"
     "${CMAKE_CURRENT_BINARY_DIR}/generated/config.h")

# 6. READ 模板 + REPLACE（用 string()）
file(READ "${CMAKE_CURRENT_BINARY_DIR}/generated/config.h" TEMPLATE)
string(REPLACE "@VER@" "${PROJECT_VER}" TEMPLATE "${TEMPLATE}")
# 7. WRITE 生成最终文件
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/generated/config.h" "${TEMPLATE}")

# 8. 添加目标
add_executable(MyApp ${SOURCES})
target_include_directories(MyApp PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/generated")
```

#### 4. 逐步详细解释
- **file(READ ...)**：读取 `version.txt`，用 `string(REGEX)` 提取 "1.2.3" 到 `PROJECT_VER`。
- **file(GLOB ...)**：收集 `src/*.cpp`，存入 `SOURCES`。
- **file(MAKE_DIRECTORY ...)**：创建 `generated/`。
- **file(COPY ... DESTINATION ...)**：复制模板，支持 `FILES_MATCHING` 过滤。
- **file(RENAME ...)**：简单重命名。
- **file(READ) + string(REPLACE) + file(WRITE)**：读取模板、替换、写入（等价于 `configure_file()`）。
- **add_executable**：用列表构建。

#### 5. 如何运行这个案例
1. 创建目录/文件。
2. `mkdir build && cd build`
3. `cmake ..`（配置，生成文件）。
4. `make`（构建）。
5. 预期：`generated/config.h` 含 `#define VERSION "1.2.3"`；运行 `./MyApp` 无错。

#### 6. 常见错误与注意事项
- **路径**：用 `${CMAKE_CURRENT_SOURCE_DIR}` 避免相对路径问题。
- **编码**：中文文件加 `ENCODING UTF-8`。
- **性能**：`GLOB` 在大目录慢；用 `CONFIGURE_DEPENDS` 优化。
- **安全**：`WRITE` 覆盖文件，小心；用 `STATUS <var>` 检查 `DOWNLOAD` 错误。
- **版本**：CMake 3.0+ 支持 `CONFIGURE`；3.15+ 归档。
- **替代**：路径用 `cmake_path()`；模板用 `configure_file()`。

这个教程覆盖官方文档核心。如果你想特定子命令案例或扩展，告诉我！