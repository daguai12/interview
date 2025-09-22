在 CMake 中，`file()` 是一个**核心命令**，用于处理文件和目录的各种操作，包括创建、删除、复制、读取、写入文件，以及目录遍历等。它是 CMake 脚本中操作文件系统的主要工具。

`file()` 命令的功能非常丰富，常见用法包括：


### 1. 文件读写操作
- **读取文件内容**：将文件内容读取到变量中
  ```cmake
  file(READ "config.txt" config_content)  # 读取 config.txt 到变量 config_content
  ```

- **写入文件内容**：将变量内容写入文件（覆盖原有内容）
  ```cmake
  file(WRITE "output.txt" "${config_content}")  # 将变量内容写入 output.txt
  ```

- **追加内容到文件**：在文件末尾添加内容，不覆盖原有内容
  ```cmake
  file(APPEND "log.txt" "Build started at ${CMAKE_CURRENT_TIME}\n")
  ```


### 2. 文件/目录复制、重命名、删除
- **复制文件或目录**：
  ```cmake
  # 复制单个文件
  file(COPY "src/file.txt" DESTINATION "dest/")
  
  # 复制目录（递归复制所有内容）
  file(COPY "src/dir/" DESTINATION "dest/dir/")
  ```

- **重命名/移动文件或目录**：
  ```cmake
  file(RENAME "oldname.txt" "newname.txt")  # 重命名文件
  file(RENAME "old_dir" "new_dir")          # 移动/重命名目录
  ```

- **删除文件或目录**：
  ```cmake
  file(REMOVE "temp.txt")                  # 删除单个文件
  file(REMOVE_RECURSE "build/" "logs/")    # 递归删除目录及其内容
  ```


### 3. 目录操作
- **创建目录**：递归创建目录（类似 `mkdir -p`）
  ```cmake
  file(MAKE_DIRECTORY "build/bin" "build/lib")  # 创建多个目录
  ```

- **获取目录下的文件列表**：
  ```cmake
  # 列出 src 目录下所有 .cpp 文件（存储到变量 src_files 中）
  file(GLOB src_files "src/*.cpp")
  
  # 递归列出所有子目录中的 .h 文件
  file(GLOB_RECURSE header_files "include/*.h")
  ```


### 4. 路径处理
- **获取文件绝对路径**：
  ```cmake
  file(REAL_PATH "relative/path" abs_path)  # 将相对路径转换为绝对路径
  ```

- **获取文件名/目录名**：
  ```cmake
  file(RELATIVE_PATH rel_path "/base/dir" "/base/dir/sub/file.txt")  # 计算相对路径
  file(GET_FILENAME_COMPONENT filename "/path/to/file.txt" NAME)     # 获取文件名（file.txt）
  ```


### 5. 其他常用功能
- **下载文件**：从 URL 下载文件到本地
  ```cmake
  file(DOWNLOAD "https://example.com/config.tar.gz" "downloads/config.tar.gz")
  ```

- **计算文件哈希值**：
  ```cmake
  file(SHA256 "binary.exe" exe_hash)  # 计算文件的 SHA256 哈希值
  ```


### 总结
`file()` 命令是 CMake 中处理文件系统的“瑞士军刀”，几乎所有与文件/目录相关的操作都可以通过它完成。在实际项目中，常用于：
- 管理源文件列表（如通过 `GLOB` 收集代码文件）
- 复制资源文件到构建目录
- 生成配置文件（结合 `configure_file()`）
- 清理临时文件或目录
- 处理跨平台的路径兼容问题

使用时需注意路径的相对/绝对关系（通常结合 `PROJECT_SOURCE_DIR`、`CMAKE_CURRENT_SOURCE_DIR` 等变量使用更可靠）。