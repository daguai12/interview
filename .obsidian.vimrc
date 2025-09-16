" ======================
" 基础导航与快捷键
" ======================
" 使用 j/k 导航实际行（而非逻辑行）
nmap j gj
nmap k gk

" 快速跳转到行首/行尾
nmap H ^    " 行首（非空格行首）
nmap L $    " 行尾

" 清除搜索高亮（需加 <CR>）
nmap <F9> :nohl<CR>

" ======================
" 系统剪贴板集成
" ======================
" 启用系统剪贴板（替代默认寄存器）
set clipboard=unnamed  " unnamedplus 支持更复杂场景

" ======================
" Obsidian 命令映射（需 exmap 中转）
" ======================
" 后退/前进（需先移除 Obsidian 自带快捷键）
exmap back obcommand app:go-back
nmap <C-o> :back<CR>    " Ctrl+O 后退

exmap forward obcommand app:go-forward
nmap <C-i> :forward<CR>  " Ctrl+I 前进

" 插入链接（快速创建 [[链接]]）
exmap insertLink obcommand editor:insert-link
nmap <C-l> :insertLink<CR>  " Ctrl+L 插入链接

" ======================
" 代码块与文本环绕（类似 vim-surround）
" ======================
" 定义环绕命令
exmap surround_wiki  surround [[ ]]    " 环绕 [[WikiLink]]
exmap surround_code  surround ``` ``   " 环绕代码块（```内容```）
exmap surround_quote surround " "       " 环绕双引号

" 映射快捷键（normal 模式）
" s + 符号 = 环绕选中内容或单词
map s[ :surround_wiki<CR>    " s[ 生成 [[...]]
map sc :surround_code<CR>    " sc 生成 ```...```
map s" :surround_quote<CR>   " s" 生成 "..."

" 可视化模式下直接使用 s 触发环绕
vmap s :<C-U>surround<CR>    " 可视化模式选中文本后按 s 输入环绕符号

" ======================
" 折叠与标签页导航
" ======================
" 折叠/展开当前块
exmap togglefold obcommand editor:toggle-fold
nmap zo :togglefold<CR>    " zo 展开
nmap zc :togglefold<CR>    " zc 折叠

" 切换标签页
exmap tabnext obcommand workspace:next-tab
nmap gt :tabnext<CR>       " gt 下一个标签页

exmap tabprev obcommand workspace:previous-tab
nmap gT :tabprev<CR>       " gT 上一个标签页

" ======================
" 自定义快捷键（示例）
" ======================
" 快速切换预览模式（需安装 "Toggle Preview" 插件）
exmap togglePreview obcommand toggle-preview:toggle
nmap <F10> :togglePreview<CR>  " F10 切换预览

" 快速打开命令面板
nmap <C-p> :obcommand show-overview<CR>  " Ctrl+P 打开命令面板

" ======================
" 映射 jj 替代 ESC（Normal/Insert/Visual 模式）
" ======================
" Normal 模式下 jj 退出到 Normal 模式（等效于 ESC）
nmap jj <Esc>

" Insert 模式下 jj 退出到 Normal 模式
imap jj <Esc>

" Visual 模式下 jj 退出到 Normal 模式
vmap jj <Esc>

set timeoutlen=500  " 设置按键间隔为 500ms（可根据打字速度调整）