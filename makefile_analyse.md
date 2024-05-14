# 从头理清uboot（1）-makefile 分析

[toc]

## 1.简单介绍及背景

## 2. makefile分析

### 2.1 执行make mx6ull_14x14_ddr512_emmc_defconfig 之后会发生什么？

在uboot的编译中，我们会先利用`make mx6ull_14x14_ddr512_emmc_defconfig`类似指令去生成一个默认的`.config`文件，之后uboot 会根据这个`.config`文件编译成`uboot.bin`。

执行这个命令，在顶层makefile中会有下面这个规则和其匹配，可以看出其依赖于scripts_basic  outputmakefile FORCE 这三个变量。

```makefile
%config: scripts_basic outputmakefile FORCE
	$(Q)$(MAKE) $(build)=scripts/kconfig $@
```

其中需要处理的变量分别如下：

##### 1. scripts_basic  :

```makefile
scripts_basic:
	$(Q)$(MAKE) $(build)=scripts/basic
	$(Q)rm -f .tmp_quiet_recordmcount
```

​	分析其中几个变量的初始化值：

  1. `$(Q)`在开头有如下定义，其中`$(origin V)`是判断V 的来源是不是输入的`command line`。在编译config 的时候，我们没有定义`v`于是`KBUILD_VERBOSE =0`进而quiet 和Q 都不是空

     * 会有什么影响：在makefile中 @ 和 quiet_ 都是用于抑制输出。**加载命令行前就不会输出对应的makefile命令行**

     ```makefile
     ifeq ("$(origin V)", "command line")
       KBUILD_VERBOSE = $(V)
     endif
     ifndef KBUILD_VERBOSE
       KBUILD_VERBOSE = 0
     endif
     ifeq ($(KBUILD_VERBOSE),1)
       quiet =
       Q =
     else
       quiet=quiet_
       Q = @
     endif
     ```

		2.  `$(make)` 一般为对应的make 指令,为make 或者gmake.
	
		3.  `$(build)` buiild 在顶层makefile 没有被调用，在`scripts/Kbuild.include`的文件中有定义如下：

      ```makefile
      ###
      # Shorthand for $(Q)$(MAKE) -f scripts/Makefile.build obj=
      # Usage:
      # $(Q)$(MAKE) $(build)=dir
      build := -f $(srctree)/scripts/Makefile.build obj
      ```

      那么有以下问题：

      * 怎么会包含这个Kbuild.include？ R: 因为主makefile 包含了这个文件：`include scripts/Kbuild.include`。

      * $(srctree)的值是多少？R:见下面的makefile语法，由于变量`KBUILD_SRC`没有被定义，所以`srctree := .`，其中`:=`  表示立即赋值，在尽显赋值时机会被计算展开，否则采用`=`时，只会在使用时展开。

        ```makefile
        ifeq ($(KBUILD_SRC),)
                # building in the source tree
                srctree := . 
        else
                ifeq ($(KBUILD_SRC)/,$(dir $(CURDIR)))
                        # building in a subdirectory of the source tree
                        srctree := ..
                else
                        srctree := $(KBUILD_SRC)
                endif
        endif
        ```

      由此我们可以 知道：`build := -f ./scripts/Makefile.build obj`

由此我们可以知道`scripts_basic`的最后定义为：

```makefile
scripts_basic:
   @make -f ./scripts/Makefile.build obj=scripts/basic
	@rm -f .tmp_quiet_recordmcount
```



##### 2. outputmakefile

由于变量`KBUILD_SRC` 没有定义，所以此项为空。

```makefile
outputmakefile:
ifneq ($(KBUILD_SRC),)
	$(Q)ln -fsn $(srctree) source
	$(Q)$(CONFIG_SHELL) $(srctree)/scripts/mkmakefile \
	    $(srctree) $(objtree) $(VERSION) $(PATCHLEVEL)
endif
```

##### 3.FORCE

FORCE 的值为常空，**由此，FORCE是没有依赖的，每次重新编译，都会更新**，由此所有依赖FORCE的编译选项也都会重新更新。

```makefile
PHONY += FORCE
FORCE:
```

经过上面三点的分析，我们回溯一下，makefile 实际上执行了这两个步骤：

```makefile
scripts_basic:
	@make -f ./scripts/Makefile.build obj=scripts/basic
	
%config: scripts_basic outputmakefile FORCE
	@make -f ./scripts/Makefile.build obj=scripts/kconfig \ mx6ull_14x14_ddr512_emmc_defconfig
# 在makefile 中 $@ 会被替换为当前正在构建的目标的名称
```



### 2.2 对于实际命令的进一步分析

由上文的命令分析可知，其实最后就是分析上面两条命令，由此分别分析如下：

#### 2.2.1 @make -f ./scripts/Makefile.build obj=scripts/basic