# 配置vscode+clangd 的开发环境：

总体可以参考这个文章：

https://blog.csdn.net/ludaoyi88/article/details/135051470

改进点：

* 安装的时候：不需要去下载，一般只需要执行下面两个命令

```c
sudo apt-get update
sudo apt-get install clangd-12
```

* 设置命令的时候：注意 这里一定是"--"。是对应clangd 命令的。

```shell
--compile-commands-dir=${workspaceFolder}
--background-index
--completion-style=detailed
--header-insertion=never
-log=info
```



