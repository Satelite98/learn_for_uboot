https://www.cnblogs.com/liangliangge/p/12549087.html  cortex-A7 的中断处理流程

```c

//程序入口
_start:

#ifdef CONFIG_SYS_DV_NOR_BOOT_CFG
	.word	CONFIG_SYS_DV_NOR_BOOT_CFG
#endif

	b	reset	//strart 会 直接跳转到reset 地址去
	ldr	pc, _undefined_instruction	//发生异常时，会跳到该指令处，然后执行指令ldr	pc, _undefined_instruction ，便会跳转到_undefined_instruction 这个符号地址去了。
	ldr	pc, _software_interrupt
	ldr	pc, _prefetch_abort
	ldr	pc, _data_abort
	ldr	pc, _not_used
	ldr	pc, _irq
	ldr	pc, _fiq
```

* 全局配置的结构体

  ```c
  typedef struct global_data {
  	bd_t *bd;
  	unsigned long flags;
  	unsigned int baudrate;
  	unsigned long cpu_clk;	/* CPU clock in Hz!		*/
  	unsigned long bus_clk;
  	/* We cannot bracket this with CONFIG_PCI due to mpc5xxx */
  	unsigned long pci_clk;
  	unsigned long mem_clk;
  #if defined(CONFIG_LCD) || defined(CONFIG_VIDEO)
  	unsigned long fb_base;	/* Base address of framebuffer mem */
  #endif
  #if defined(CONFIG_POST) || defined(CONFIG_LOGBUFFER)
  	unsigned long post_log_word;  /* Record POST activities */
  	unsigned long post_log_res; /* success of POST test */
  	unsigned long post_init_f_time;  /* When post_init_f started */
  #endif
  #ifdef CONFIG_BOARD_TYPES
  	unsigned long board_type;
  #endif
  	unsigned long have_console;	/* serial_init() was called */
  #ifdef CONFIG_PRE_CONSOLE_BUFFER
  	unsigned long precon_buf_idx;	/* Pre-Console buffer index */
  #endif
  	unsigned long env_addr;	/* Address  of Environment struct */
  	unsigned long env_valid;	/* Checksum of Environment valid? */
  
  	unsigned long ram_top;	/* Top address of RAM used by U-Boot */
  
  	unsigned long relocaddr;	/* Start address of U-Boot in RAM */
  	phys_size_t ram_size;	/* RAM size */
  #ifdef CONFIG_SYS_MEM_RESERVE_SECURE
  #define MEM_RESERVE_SECURE_SECURED	0x1
  #define MEM_RESERVE_SECURE_MAINTAINED	0x2
  #define MEM_RESERVE_SECURE_ADDR_MASK	(~0x3)
  	/*
  	 * Secure memory addr
  	 * This variable needs maintenance if the RAM base is not zero,
  	 * or if RAM splits into non-consecutive banks. It also has a
  	 * flag indicating the secure memory is marked as secure by MMU.
  	 * Flags used: 0x1 secured
  	 *             0x2 maintained
  	 */
  	phys_addr_t secure_ram;
  #endif
  	unsigned long mon_len;	/* monitor len */
  	unsigned long irq_sp;		/* irq stack pointer */
  	unsigned long start_addr_sp;	/* start_addr_stackpointer */
  	unsigned long reloc_off;
  	struct global_data *new_gd;	/* relocated global data */
  
  #ifdef CONFIG_DM
  	struct udevice	*dm_root;	/* Root instance for Driver Model */
  	struct udevice	*dm_root_f;	/* Pre-relocation root instance */
  	struct list_head uclass_root;	/* Head of core tree */
  #endif
  #ifdef CONFIG_TIMER
  	struct udevice	*timer;	/* Timer instance for Driver Model */
  #endif
  
  	const void *fdt_blob;	/* Our device tree, NULL if none */
  	void *new_fdt;		/* Relocated FDT */
  	unsigned long fdt_size;	/* Space reserved for relocated FDT */
  	struct jt_funcs *jt;		/* jump table */
  	char env_buf[32];	/* buffer for getenv() before reloc. */
  #ifdef CONFIG_TRACE
  	void		*trace_buff;	/* The trace buffer */
  #endif
  #if defined(CONFIG_SYS_I2C)
  	int		cur_i2c_bus;	/* current used i2c bus */
  #endif
  #ifdef CONFIG_SYS_I2C_MXC
  	void *srdata[10];
  #endif
  	unsigned long timebase_h;
  	unsigned long timebase_l;
  #ifdef CONFIG_SYS_MALLOC_F_LEN
  	unsigned long malloc_base;	/* base address of early malloc() */
  	unsigned long malloc_limit;	/* limit address */
  	unsigned long malloc_ptr;	/* current address */
  #endif
  #ifdef CONFIG_PCI
  	struct pci_controller *hose;	/* PCI hose for early use */
  	phys_addr_t pci_ram_top;	/* top of region accessible to PCI */
  #endif
  #ifdef CONFIG_PCI_BOOTDELAY
  	int pcidelay_done;
  #endif
  	struct udevice *cur_serial_dev;	/* current serial device */
  	struct arch_global_data arch;	/* architecture-specific data */
  #ifdef CONFIG_CONSOLE_RECORD
  	struct membuff console_out;	/* console output */
  	struct membuff console_in;	/* console input */
  #endif
  #ifdef CONFIG_DM_VIDEO
  	ulong video_top;		/* Top of video frame buffer area */
  	ulong video_bottom;		/* Bottom of video frame buffer area */
  #endif
  } gd_t;
  #endif
  ```

  

* 这句话 是怎么实现函数指针跳转到对应函数的？-后面有具体实现的，只是clangd没有跳转过去。

```c
typedef int (*init_fnc_t)(void);
int initcall_run_list(const init_fnc_t init_sequence[]);

int initcall_run_list(const init_fnc_t init_sequence[])
{
	const init_fnc_t *init_fnc_ptr;

	for (init_fnc_ptr = init_sequence; *init_fnc_ptr; ++init_fnc_ptr) {
		unsigned long reloc_ofs = 0;
		int ret;

		if (gd->flags & GD_FLG_RELOC)
			reloc_ofs = gd->reloc_off;
#ifdef CONFIG_EFI_APP
		reloc_ofs = (unsigned long)image_base;
#endif
		debug("initcall: %p", (char *)*init_fnc_ptr - reloc_ofs);
		if (gd->flags & GD_FLG_RELOC)
			debug(" (relocated to %p)\n", (char *)*init_fnc_ptr);
		else
			debug("\n");
		ret = (*init_fnc_ptr)();
		if (ret) {
			printf("initcall sequence %p failed at call %p (err=%d)\n",
			       init_sequence,
			       (char *)*init_fnc_ptr - reloc_ofs, ret);
			return -1;
		}
	}
	return 0;
}
```

*  uboot 命令分析

```python
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

   * ```python
     #define ll_entry_declare(_type, _name, _list)				\
     	_type _u_boot_list_2_##_list##_2_##_name __aligned(4)		\
     			__attribute__((unused,				\
     			section(".u_boot_list_2_"#_list"_2_"#_name)))
     ```

   * ```python
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

* section 再内存中的存储位置如下所示：四字节对齐之后存储在rodata 段之后。

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

* 对于命令结构体的处理方法如下所示：

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
		rc = cmd_call(cmdtp, flag, argc, argv);
		if (ticks)
			*ticks = get_timer(*ticks);
		*repeatable &= cmdtp->repeatable;
	}
	if (rc == CMD_RET_USAGE)
		rc = cmd_usage(cmdtp);
	return rc;
}
```



* boot z 命令执行

