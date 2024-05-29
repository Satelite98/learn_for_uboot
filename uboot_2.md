# 从头理清uboot（3）-main_loop 及 CMD实现

[toc]

## 1. main—loop 函数

上篇引导启动的分析最后会调用`run_main_loop`,在其中会循环调用`main_loop()`函数。见下方：

```c
static int run_main_loop(void)
{
	for (;;)
		main_loop();
	return 0;
}
```

而在`main_loop`中，执行的语句如下：

```c
void main_loop(void)
{
	const char *s;
	bootstage_mark_name(BOOTSTAGE_ID_MAIN_LOOP, "main_loop"); //打印启动进度
	cli_init();							/*初始化 hash shell 相关  */
	run_preboot_environment_command();	/*获取 preboot 环境变量  */
	s = bootdelay_process();			/*读取环境变量 bootdelay和bootcmd 的内容*/
	if (cli_process_fdt(&s))			/* 此次uboot 直接返回uboot */
		cli_secure_boot_cmd(s);			
	autoboot_command(s);/* 如果延时到了，没有打断就执行默认的boot-arg */
	cli_loop();							/* 命令执行函数 */
}
```

  * bootdelay_process 函数解析：初始化好了`bootdelay`的参数，并且返回的命令是`bootcmd` 环境变量。

    ```c
    const char *bootdelay_process(void)
    {
    	char *s;
    	int bootdelay;
        s = getenv("bootdelay");
    	bootdelay = s ? (int)simple_strtol(s, NULL, 10) : CONFIG_BOOTDELAY;
    
    #if !defined(CONFIG_FSL_FASTBOOT) && defined(is_boot_from_usb)
    	if (is_boot_from_usb()) {
    		disconnect_from_pc();
    		printf("Boot from USB for mfgtools\n");
    		bootdelay = 0;
    		set_default_env("Use default environment for \
    				 mfgtools\n");
    	} else {
    		printf("Normal Boot\n");
    	}
    #endif
        bootretry_init_cmd_timeout();
        s = getenv("bootcmd");
    #if !defined(CONFIG_FSL_FASTBOOT) && defined(is_boot_from_usb)
    	if (is_boot_from_usb()) {
    		s = getenv("bootcmd_mfg");
    		printf("Run bootcmd_mfg: %s\n", s);
    	}
    #endif    
       	process_fdt_options(gd->fdt_blob);
    	stored_bootdelay = bootdelay;
    	return s;
    } 
    ```

    其中的`get_env`函数：可见这个函数根据命令的不同，从**哈希表**和**遍历**两种方式，去现有得环境变量中查找对应命令。

    ```c
    char *getenv(const char *name)
    {
         /* after import into hashtable */
    	if (gd->flags & GD_FLG_ENV_READY) {
    		ENTRY e, *ep;
    
    		WATCHDOG_RESET();
    
    		e.key	= name;
    		e.data	= NULL;
    		hsearch_r(e, FIND, &ep, &env_htab, 0);
    
    		return ep ? ep->data : NULL;
    	}
    	/* restricted capabilities before import */
    	if (getenv_f(name, (char *)(gd->env_buf), sizeof(gd->env_buf)) > 0)
    		return (char *)(gd->env_buf);
    	return NULL;
    }
    ```



* autoboot_command的函数代码精简如下，可见有三个参数，`stored_bootdelay`是刚刚初始化好的`bootdelay`环境变量的值，S 是`bootcmd`的值，这两个都条件成立。

	```c
	void autoboot_command(const char *s)
	{
    debug("### main_loop: bootcmd=\"%s\"\n", s ? s : "<UNDEFINED>");
      if (stored_bootdelay != -1 && s && !abortboot(stored_bootdelay)) {
  		run_command_list(s, -1, 0); 
  	}
  }
  ```
  
  * 进一步分析`abortboot(stored_bootdelay)`发现里面会每次delay 1000ms 就会把传入的`stored_bootdelay`参数减一，所以当`stored_bootdelay `递减到0的时候，会执行`run_command_list(s, -1, 0)`。
  
  * 但是其中有个函数是`tstc()`有效的话，就会导致提前break ,不再执行`run_command_list(s, -1, 0)`。进入指令处理流程。
  
  ```c
  	while ((bootdelay > 0) && (!abort)) {
  		--bootdelay;
  		/* delay 1000 ms */
  		ts = get_timer(0);
  		do {
  			if (tstc()) {	/* we got a key press	*/
  				abort  = 1;	/* don't auto boot	*/
  				bootdelay = 0;	/* no more delay	*/
  				(void) getc();  /* consume input	*/
  				break;
  			}
  			udelay(10000);
  		} while (!abort && get_timer(ts) < 1000);
  
  		printf("\b\b\b%2d ", bootdelay);
  	}
  ```
  
  
  
* 正常的autoboot流程-- run_command_list 函数分析：

  ```c
  会调用：rcode = parse_string_outer(buff, FLAG_PARSE_SEMICOLON);
  	进而调用：rcode = parse_stream_outer(&input, flag);
  ```

* 有按键输入，执行解析命令-cli_loop函数：

  ```c
  parse_file_outer();
  	->调用：parse_stream_outer(&input, FLAG_PARSE_SEMICOLON);
  ```

* 所以这种方式都会把接收到的命令交给`parse_stream_outer`函数执行。

  ```c
  -> 调用: rcode = parse_stream(&temp, &ctx, inp, flag & FLAG_CONT_ON_NEWLINE ? -1 : '\n'); /* 解析输入的命令 */
  -> 调用: code = run_list(ctx.list_head); /* 执行命令*/
  	->run_list_real(pi);
  		->run_pipe_real(pi);
  			->cmd_process(flag, child->argc, child->argv,
  				   &flag_repeat, NULL); /* 实际的处理流程*/
  ```

  

## 2. cmd_process 函数分析

​		在看函数处理之前，可以先了解uboot  cmd 结构体的组成，其中参数见下图注释

```c
struct cmd_tbl_s {
	char		*name;		/* Command Name			*/
	int		maxargs;	/* maximum number of arguments	*/
	int		repeatable;	/* autorepeat allowed?		*/
					/* Implementation function	*/
	int		(*cmd)(struct cmd_tbl_s *, int, int, char * const []);/*调用函数*/
	char		*usage;		/*简短提示信息*/
};
```

​		cmd_process 的处理流程如下所示， 可见主要流程为：查找命令->判断参数数量->回调函数调用。

```c
enum command_ret_t cmd_process(int flag, int argc, char * const argv[],
			       int *repeatable, ulong *ticks)
{
	enum command_ret_t rc = CMD_RET_SUCCESS;
	cmd_tbl_t *cmdtp;

	/* Look up command in command table */
	cmdtp = find_cmd(argv[0]);
	if (cmdtp == NULL) {
		printf("Unknown command '%s' - try 'help'\n", argv[0]);
		return 1;
	}

	/* found - check max args */
	if (argc > cmdtp->maxargs)
		rc = CMD_RET_USAGE;

#if defined(CONFIG_CMD_BOOTD)
	/* avoid "bootd" recursion */
	else if (cmdtp->cmd == do_bootd) {
		if (flag & CMD_FLAG_BOOTD) {
			puts("'bootd' recursion detected\n");
			rc = CMD_RET_FAILURE;
		} else {
			flag |= CMD_FLAG_BOOTD;
		}
	}
#endif
	/* If OK so far, then do the command */
	if (!rc) {
		if (ticks)
			*ticks = get_timer(0);
		rc = cmd_call(cmdtp, flag, argc, argv);/*利用回调函数执行*/
		if (ticks)
			*ticks = get_timer(*ticks);
		*repeatable &= cmdtp->repeatable;
	}
	if (rc == CMD_RET_USAGE)
		rc = cmd_usage(cmdtp);
	return rc;
}
```



## 3. cmd 定义流程

*  uboot 命令分析，在`include/command.h`中有定义：

```asm
#define U_BOOT_CMD_MKENT_COMPLETE(_name, _maxargs, _rep, _cmd,		\
				_usage, _help, _comp)			\
		{ #_name, _maxargs, _rep, _cmd, _usage,			\
			_CMD_HELP(_help) _CMD_COMPLETE(_comp) }

#define U_BOOT_CMD_MKENT(_name, _maxargs, _rep, _cmd, _usage, _help)	\
	U_BOOT_CMD_MKENT_COMPLETE(_name, _maxargs, _rep, _cmd,		\
					_usage, _help, NULL)

#define U_BOOT_CMD_COMPLETE(_name, _maxargs, _rep, _cmd, _usage, _help, _comp) \
	ll_entry_declare(cmd_tbl_t, _name, cmd) =			\
		U_BOOT_CMD_MKENT_COMPLETE(_name, _maxargs, _rep, _cmd,	\
						_usage, _help, _comp);

#define U_BOOT_CMD(_name, _maxargs, _rep, _cmd, _usage, _help)		\
	U_BOOT_CMD_COMPLETE(_name, _maxargs, _rep, _cmd, _usage, _help, NULL)

```

可以看出有以下几点：

1. `U_BOOT_CMD`就是`U_BOOT_CMD_COMPLETE`的宏参数最后一个为**NULL**

2. `U_BOOT_CMD_COMPLETE`会继续调用`ll_entry_declare`和`U_BOOT_CMD_MKENT_COMPLETE`函数。分别显示如下

   * ```asm
     #define ll_entry_declare(_type, _name, _list)				\
     	_type _u_boot_list_2_##_list##_2_##_name __aligned(4)		\
     			__attribute__((unused,				\
     			section(".u_boot_list_2_"#_list"_2_"#_name)))
     ```

   * ```asm
     #define U_BOOT_CMD_MKENT_COMPLETE(_name, _maxargs, _rep, _cmd,\
     				_usage, _help, _comp)			\
     		{ #_name, _maxargs, _rep, _cmd, _usage,			\
     			_CMD_HELP(_help) _CMD_COMPLETE(_comp) }
     ```

3. 其中再次调用了`_CMD_HELP(_help) _CMD_COMPLETE(_comp)`这两部分定义如下(相关宏已经定义了)：

   ```c
   #ifdef CONFIG_AUTO_COMPLETE
   //# define _CMD_COMPLETE(x) x,
   #else
   //# define _CMD_COMPLETE(x)
   //#endif
   #ifdef CONFIG_SYS_LONGHELP
   # define _CMD_HELP(x) x,
   #else
   //# define _CMD_HELP(x)
   //#endif
   ```

* 利用一个CMD来分析

```c
U_BOOT_CMD(
	spibootldr, 2, 0, do_spibootldr,
	"boot ldr image from spi",
	"[offset]\n"
	"    - boot ldr image stored at offset into spi\n");
```

经过上述的分析，此命令可以被解析为：

```c
--ll_entry_declare(_type, _name, _list)
  ->  cmd_tbl_t _u_boot_list_2_spibootldr_2_spibootldr __aligned(4)		\
			__attribute__((unused,				\
			section(".u_boot_list_2_do_spibootldr_2_spibootldr)))

--{ "spibootldr", 2, 0, do_spibootldr," boot ldr image from spi",			\
			"[offset]\n""- boot ldr image stored at offset into spi\n", NULL, }               
```

`##` 连接符:表示后面直接链接

`#` 字符串化：表示将传来的参数字符串化。

所以最后实现的语句如下所示：

```c
cmd_tbl_t _u_boot_list_2_spibootldr_2_spibootldr __aligned(4)		\
__attribute__((unused, section(".u_boot_list_2_do_spibootldr_2_spibootldr"))) 
                               = { "spibootldr", 2, 0, do_spibootldr,
                                  " boot ldr image from spi",
                                  "[offset]\n""- boot ldr image stored at offset into spi\n",
                                  NULL, } 
```

4字节对齐定义了一个`cmd_tbl_t`的结构体变量`_u_boot_list_2_spibootldr_2_spibootldr`，且被划分到了`u_boot_list_2_do_spibootldr_2_spibootldr` section。

* 其中对于`cmd_tbl_t` 有以下定义: 

```c
struct cmd_tbl_s {
	char		*name;		/* Command Name	  		*/          
	int		maxargs;	/* maximum number of arguments	*/
	int		repeatable;	/* autorepeat allowed?		*/
					/* Implementation function	*/
	int		(*cmd)(struct cmd_tbl_s *, int, int, char * const []);  /* 函数指针 */
	char		*usage;		/* Usage message	(short)	*/
#ifdef	CONFIG_SYS_LONGHELP
	char		*help;		/* Help  message	(long)	*/
#endif
#ifdef CONFIG_AUTO_COMPLETE
	/* do auto completion on the arguments */
	int		(*complete)(int argc, char * const argv[], char last_char, int maxv, char *cmdv[]);
#endif
};
```

* section 在内存中的存储位置如下所示：四字节对齐之后存储在rodata 段之后。

```c
 .rodata : { *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.rodata*))) }
 . = ALIGN(4);
 .data : {
  *(.data*)
 }
 . = ALIGN(4);
 . = .;
 . = ALIGN(4);
 .u_boot_list : {
  KEEP(*(SORT(.u_boot_list*)));
 }
```

**注意：**这里有一次`SORT`排序，结合下面的代码，就会发现能够获取板子的整个命令段。函数内部静态定义也会存在全局变量中。

```asm
#define ll_entry_start(_type, _list)\
({\
	static char start[0] __aligned(4) __attribute__((unused,	\
		section(".u_boot_list_2_"#_list"_1")));			\
	(_type *)&start;						\
})
#define ll_entry_end(_type, _list)\
({									\
	static char end[0] __aligned(4) __attribute__((unused,		\
		section(".u_boot_list_2_"#_list"_3")));			\
	(_type *)&end;							\
})
```

