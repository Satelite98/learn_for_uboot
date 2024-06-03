# 从头理清uboot（4）-boot_cmd 的处理

[toc]

上次我们分析到，uboot在启动linux的过程中，最后是执行`bootcmd`这个环境变量，那么我们今天来分析，这个环境变量到底执行了哪些功能，这些功能调用了哪些函数，最后是如何实现linux的boot的？

==关于环境变量：==**对于imax6ull来说，都是存储在/include/configs/mx6ullevk.h和include/env_dedault.h**



## 1. 默认的bootcmd 包含了哪些内容？

在`default_environment`中有定义：于是查找`CONFIG_BOOTCOMMAND`

```c
#ifdef	CONFIG_BOOTCOMMAND
	"bootcmd="	CONFIG_BOOTCOMMAND		"\0"
#endif
```

在`./include/configs/mx6ullevk.h`中有定义：

```c
#define CONFIG_BOOTCOMMAND \
	   "run findfdt;" \
	   "mmc dev ${mmcdev};" \
	   "mmc dev ${mmcdev}; if mmc rescan; then " \
		   "if run loadbootscript; then " \
			   "run bootscript; " \
		   "else " \
			   "if run loadimage; then " \
				   "run mmcboot; " \
			   "else run netboot; " \
			   "fi; " \
		   "fi; " \
	   "else run netboot; fi"
#endif
```

其中,有以下环境变量：

* findfdt：其中会用到`fdt_file=undefined，board_name=EVK，board_rev=14X14 `这三个变量，用于寻找.dtb 文件

  ```c
  	"findfdt="\
  			"if test $fdt_file = undefined; then " \
  				"if test $board_name = EVK && test $board_rev = 9X9; then " \
  					"setenv fdt_file imx6ull-9x9-evk.dtb; fi; " \
  				"if test $board_name = EVK && test $board_rev = 14X14; then " \
  					"setenv fdt_file imx6ull-14x14-evk.dtb; fi; " \
  				"if test $fdt_file = undefined; then " \
  					"echo WARNING: Could not determine dtb to use; fi; " \
  			"fi;\0" \
  ```

* mmc dev ${mmcdev} : 用于切换mmc 设置mmc  设备

* mmc rescan ：执行mmc  扫描检查，成功执行`run loadbootscript`失败就执行`run netboot`网络boot。

* run loadbootscript ： 

  ```c
  	"loadbootscript=" \
  		"fatload mmc ${mmcdev}:${mmcpart} ${loadaddr} ${script};\0" \
  ```

  其中` mmcdev=1，mmcpart=1，loadaddr=0x80800000，script= boot.scr`因此展开之后为下面指令，就是从 mmc1 的分区 1 中读取文件 boot.src 到 DRAM 的 0X80800000 处，如果成功的话就执行`bootscript`不行就会执行`run loadimage`

  ```c
  loadbootscript=fatload mmc 1:1 0x80800000 boot.scr; 
  ```

  * bootscript：只是一个输出语句

    ```c
    "bootscript=echo Running bootscript from mmc ...; " \
    ```

* run loadimage：见下方注释为从mmc 加载zImage到0x80800000地址处。

  ```c
  "loadimage=fatload mmc ${mmcdev}:${mmcpart} ${loadaddr} ${image}\0" \
    /* 其中：  mmcdev=1、mmcpart=1  loadaddr=0x80800000、image = zImage 所以展开之后就是：*/ 
      loadimage=fatload mmc 1:1 0x80800000 zImage  
  ```

  
### 1.1 mmcboot

mmcboot 的源码如下：

  ```c
  	"mmcboot=echo Booting from mmc ...; " \
  		"run mmcargs; " \
  		"if test ${boot_fdt} = yes || test ${boot_fdt} = try; then " \
  			"if run loadfdt; then " \
  				"bootz ${loadaddr} - ${fdt_addr}; " \
  			"else " \
  				"if test ${boot_fdt} = try; then " \
					"bootz; " \
  				"else " \
					"echo WARN: Cannot load the DT; " \
  				"fi; " \
  			"fi; " \
  		"else " \
  			"bootz; " \
  		"fi;\0" \
  ```

  * 其中第一行是设置boot 参数

  ```c
    	"mmcargs=setenv bootargs console=${console},${baudrate} " \
  		CONFIG_BOOTARGS_CMA_SIZE \
    		CONFIG_MFG_NAND_PARTITION \
    		"root=${mmcroot}\0" \
     /*"console=ttymxc"  baudrate=115200  mmcroot="/dev/mmcblk1p2"rootwait rw */ 
     所以这句话为：
    mmcargs=setenv bootargs  console=ttymxc0,115200  "" "" root=/dev/mmcblk1p2 rootwait rw
  ```

  * 由于`"boot_fdt=try\0" \`所以执行`loadfdt`,由于`fdt_file`在之前`findfdt`时候初始化过了，所以额这里就是load dtb 文件到`0x83000000`。
  
    ```c
    "loadfdt=fatload mmc ${mmcdev}:${mmcpart} ${fdt_addr} ${fdt_file}\0" \
     /* mmcdev=1、mmcpart=1 fdt_addr=0x83000000 、fdt_file= imx6ull-14x14-evk.dtb \0 */
        fatload mmc 1:1 0x83000000 imx6ull-14x14-evk.dtb
    ```
  ```
  
  * 于是` run loadfdt`执行成功，就会执行指令：
  
    ```c
    bootz ${loadaddr} - ${fdt_addr};
    /* loadaddr =  0x80800000  fdt_addr=0x83000000*/
    bootz 0x80800000 - 0x83000000 
  ```

### 1.2 netboot

```c
		"netboot=echo Booting from net ...; " \
		"run netargs; " \
		"if test ${ip_dyn} = yes; then " \
			"setenv get_cmd dhcp; " \
		"else " \
			"setenv get_cmd tftp; " \
		"fi; " \
		"${get_cmd} ${image}; " \
		"if test ${boot_fdt} = yes || test ${boot_fdt} = try; then " \
			"if ${get_cmd} ${fdt_addr} ${fdt_file}; then " \
				"bootz ${loadaddr} - ${fdt_addr}; " \
			"else " \
				"if test ${boot_fdt} = try; then " \
					"bootz; " \
				"else " \
					"echo WARN: Cannot load the DT; " \
				"fi; " \
			"fi; " \
		"else " \
			"bootz; " \
		"fi;\0" \
```

### 1.3 小总结

* 对于`mmc_boot`有效的信息如下：
  1. 给`findfdt`赋值，设置dtb文件：`setenv fdt_file imx6ull-14x14-evk.dtb`
  2. 设置mmc 设备: `mmc dev 1`
  3. 加载镜像：`fatload mmc 1:1 0x80800000 zImage  `
  4. 设置bootargs：`setenv bootargs  console=ttymxc0,115200  "" "" root=/dev/mmcblk1p2 rootwait rw`
  5. 加载dtb：`fatload mmc 1:1 0x83000000 imx6ull-14x14-evk.dtb`
  6. 启动：`bootz 0x80800000 - 0x83000000 `



### 1.4 关于`bootargs`

* bootargs 是uboot 传递给linux 中的参数，上述解析之后的参数见下方：

  ```c
  mmcargs=setenv bootargs  console=ttymxc0,115200  "" "" root=/dev/mmcblk1p2 rootwait rw
  ```

  其中有三个设置点：

  1. console ：设置Linux的输出窗口，由于mx6ull中，串口0的表示是`/dev/ttymxc0`所以设置输出窗口为这个。
  2. root ：设置根文件系统的位置，告诉Linux在哪里寻找根文件系统。`/dev/mmcblk1p2 `表示在ima6ull的分区2中。后续还有`“rootwait rw”`数据，表示等待根文件系统挂载完毕才加载，rw表示文件系统是可读写的。

## 2. boot-linux 函数过程

​		上面分析到，在把image和dtb 搬运到固定地址之后，执行`bootz 0x80800000 - 0x83000000`指令，进入linux 的boot 阶段。`bootz`指令的定义如下，于是可以发现是执行`do_bootz`函数。

```c
U_BOOT_CMD(
	bootz,	CONFIG_SYS_MAXARGS,	1,	do_bootz,
	"boot Linux zImage image from memory", bootz_help_text
);
```

### 2.1 结构体简单介绍

uboot 中 定义了`bootm_headers_t`和`image_header_t`结构体分别用来抽象image 信息和 image 头部信息。

```c
typedef struct bootm_headers {
	/*
	 * Legacy os image header, if it is a multi component image
	 * then boot_get_ramdisk() and get_fdt() will attempt to get
	 * data from second and third component accordingly.
	 */
	image_header_t	*legacy_hdr_os;		/* image header pointer */
	image_header_t	legacy_hdr_os_copy;	/* header copy */
	ulong		legacy_hdr_valid;
    #ifndef USE_HOSTCC
	image_info_t	os;		/* os image info */
	ulong		ep;		/* entry point of OS */

	ulong		rd_start, rd_end;/* ramdisk start/end */

	char		*ft_addr;	/* flat dev tree address */
	ulong		ft_len;		/* length of flat device tree */

	ulong		initrd_start;
	ulong		initrd_end;
	ulong		cmdline_start;
	ulong		cmdline_end;
	bd_t		*kbd;
#endif

	int		verify;		/* getenv("verify")[0] != 'n' */

#define	BOOTM_STATE_START	(0x00000001)
#define	BOOTM_STATE_FINDOS	(0x00000002)
#define	BOOTM_STATE_FINDOTHER	(0x00000004)
#define	BOOTM_STATE_LOADOS	(0x00000008)
#define	BOOTM_STATE_RAMDISK	(0x00000010)
#define	BOOTM_STATE_FDT		(0x00000020)
#define	BOOTM_STATE_OS_CMDLINE	(0x00000040)
#define	BOOTM_STATE_OS_BD_T	(0x00000080)
#define	BOOTM_STATE_OS_PREP	(0x00000100)
#define	BOOTM_STATE_OS_FAKE_GO	(0x00000200)	/* 'Almost' run the OS */
#define	BOOTM_STATE_OS_GO	(0x00000400)
	int		state;

#ifdef CONFIG_LMB
	struct lmb	lmb;		/* for memory mgmt */
#endif
} bootm_headers_t;

extern bootm_headers_t images;


/* 其中，header 再定义为： */
 typedef struct image_header {
	__be32		ih_magic;	/* Image Header Magic Number	*/
	__be32		ih_hcrc;	/* Image Header CRC Checksum	*/
	__be32		ih_time;	/* Image Creation Timestamp	*/
	__be32		ih_size;	/* Image Data Size		*/
	__be32		ih_load;	/* Data	 Load  Address		*/
	__be32		ih_ep;		/* Entry Point Address		*/
	__be32		ih_dcrc;	/* Image Data CRC Checksum	*/
	uint8_t		ih_os;		/* Operating System		*/
	uint8_t		ih_arch;	/* CPU architecture		*/
	uint8_t		ih_type;	/* Image Type			*/
	uint8_t		ih_comp;	/* Compression Type		*/
	uint8_t		ih_name[IH_NMLEN];	/* Image Name		*/
} image_header_t;
```

### 2.2 do_bootz函数分析

​		`do_bootz`会调用`bootz_start`准备好环境之后，关闭`中断`，在设置要启动的系统是`IH_OS_LINUX`之后，就会利用`do_bootm_states`函数启动linux。源码如下：

```c
int do_bootz(cmd_tbl_t *cmdtp, int flag, int argc, char * const argv[])
{
	int ret;
	/* Consume 'bootz'  过滤掉bootz 参数，这样子addr= argv[0] */ 
	argc--; argv++;
	if (bootz_start(cmdtp, flag, argc, argv, &images))
		return 1;

    bootm_disable_interrupts();
	
    images.os.os = IH_OS_LINUX;
	ret = do_bootm_states(cmdtp, flag, argc, argv,
			      BOOTM_STATE_OS_PREP | BOOTM_STATE_OS_FAKE_GO |
			      BOOTM_STATE_OS_GO,
			      &images, 1);

	return ret;
}
```

#### 2.2.1 bootz_start 函数

* 见下方，bootz_start的主要功能为：

  * 调用 do_bootm_states,且把状态设置为 `BOOTM_STATE_START `准备环境，释放原来`images`占用的区域。
  * 设置`images->ep`这个地址是image 的启动地址（entry-point）。
  * 把`images->ep`头部指针传递给`bootz_setup`,在里面会做是否是linux  系统image 的判定，并且获得起始和结束位置，如果不是的话会报错，给image  指针重定位。
  * 调用`lmb_reserve`将image 占用的内存大小和区域设置为已经使用的区域。
  * 调用`bootm_find_images`去找到dtb 文件，并且将地址和长度信息，存储到全局变量`images`中。

  做完以上之后，就会调用`do_bootm_states`,并且设置对应状态 启动inux。

  ```c
  static int bootz_start(cmd_tbl_t *cmdtp, int flag, int argc,
  			char * const argv[], bootm_headers_t *images)
  {
  	int ret;
  	ulong zi_start, zi_end;
  	ret = do_bootm_states(cmdtp, flag, argc, argv, BOOTM_STATE_START,
  			      images, 1); /* */
  
  	/* Setup Linux kernel zImage entry point */
  	if (!argc) {
  		images->ep = load_addr;
  		debug("*  kernel: default image load address = 0x%08lx\n",
  				load_addr);
  	} else {
  		images->ep = simple_strtoul(argv[0], NULL, 16);
  		debug("*  kernel: cmdline image address = 0x%08lx\n",
  			images->ep);
  	}
  
  	ret = bootz_setup(images->ep, &zi_start, &zi_end);
  	if (ret != 0)
  		return 1;
  
  	lmb_reserve(&images->lmb, images->ep, zi_end - zi_start);
  
  	if (bootm_find_images(flag, argc, argv))
  		return 1;
  	return 0;
  }
  ```

### 2.2.2 do_bootm_states 函数

* `do_bootm_states `能够根据不同的状态执行不同的函数，在imax6ull 中，起到了下面这些作用：

  * 调用`bootm_start`函数，释放原来`images`指向的区域并清0。
  * 调用`bootm_load_os`函数，设置对应的地址。
  * ==调用`bootm_os_get_boot_func`函数:==找到boot 中真正使用的函数。本次boot 的os 在之前已经设置过了为`IH_OS_LINUX`于是会调用`do_bootm_linux`。后面执行的`boot_fn(BOOTM_STATE_OS_CMDLINE, argc, argv, images);`函数实际上都是由`do_bootm_linux`函数执行。

  ```c
  int do_bootm_states(cmd_tbl_t *cmdtp, int flag, int argc, char * const argv[],
  		    int states, bootm_headers_t *images, int boot_progress)
  {
  	boot_os_fn *boot_fn;
  	ulong iflag = 0;
  	int ret = 0, need_boot_fn;
  
  	images->state |= states;
  
  	/*
  	 * Work through the states and see how far we get. We stop on
  	 * any error.
  	 */
  	if (states & BOOTM_STATE_START)
  		ret = bootm_start(cmdtp, flag, argc, argv);
  
  	if (!ret && (states & BOOTM_STATE_FINDOS))
  		ret = bootm_find_os(cmdtp, flag, argc, argv);
  
  	if (!ret && (states & BOOTM_STATE_FINDOTHER)) {
  		ret = bootm_find_other(cmdtp, flag, argc, argv);
  		argc = 0;	/* consume the args */
  	}
      ......
          
      boot_fn = bootm_os_get_boot_func(images->os.os);
  	need_boot_fn = states & (BOOTM_STATE_OS_CMDLINE |
  			BOOTM_STATE_OS_BD_T | BOOTM_STATE_OS_PREP |
  			BOOTM_STATE_OS_FAKE_GO | BOOTM_STATE_OS_GO);
  	......
      	/*  这里实际执行的都是do_bootm_linux 函数了！ */
      	/* Call various other states that are not generally used */ 
  	if (!ret && (states & BOOTM_STATE_OS_CMDLINE))
  		ret = boot_fn(BOOTM_STATE_OS_CMDLINE, argc, argv, images);
  	if (!ret && (states & BOOTM_STATE_OS_BD_T))
  		ret = boot_fn(BOOTM_STATE_OS_BD_T, argc, argv, images);
  	if (!ret && (states & BOOTM_STATE_OS_PREP))
  		ret = boot_fn(BOOTM_STATE_OS_PREP, argc, argv, images);
  	......
      	/* Now run the OS! We hope this doesn't return */
  	if (!ret && (states & BOOTM_STATE_OS_GO))
  		ret = boot_selected_os(argc, argv, BOOTM_STATE_OS_GO,
  				images, boot_fn);
  }
  ```

### 2.2.3 do_bootm_linux函数

上面说到，在本次启动过程中，最后实际调用的是`do_bootm_linux`于是再继续分析这个函数。

* 我们在`do_bootz`的时候，实际调用的是这调用整个宏`BOOTM_STATE_OS_PREP `，会调用`boot_prep_linux(images);` 这个函数进行启动前的准备。

  ```c
  int do_bootm_linux(int flag, int argc, char * const argv[],
  		   bootm_headers_t *images)
  {
  	/* No need for those on ARM */
  	if (flag & BOOTM_STATE_OS_BD_T || flag & BOOTM_STATE_OS_CMDLINE)
  		return -1;
  
  	if (flag & BOOTM_STATE_OS_PREP) {
  		boot_prep_linux(images);
  		return 0;
  	}
  
  	if (flag & (BOOTM_STATE_OS_GO | BOOTM_STATE_OS_FAKE_GO)) {
  		boot_jump_linux(images, flag);
  		return 0;
  	}
  
  	boot_prep_linux(images);
  	boot_jump_linux(images, flag);
  	return 0;
  }
  ```

* 后面`do_bootz`会调用`boot_selected_os`函数，之后继续调用`do_bootm_linux`并且将flag 设置为`BOOTM_STATE_OS_GO`，执行`boot_jump_linux(images, flag);`

  ```c
  boot_selected_os(argc, argv, BOOTM_STATE_OS_GO,
  				images, boot_fn);
  /* 实际还是调用了  boot_fn(state, argc, argv, images); */
  /* 在bootlinux 的情况下，实际执行的是：do_bootm_linux*/
   do_bootm_linux (BOOTM_STATE_OS_GO,argc,argv，images)
  ```



### 2.2.4 boot_jump_linux函数

* 可见`boot_jump_linux`的作用如下：

  * 定义函数指针并且赋值为`images->ep`,作为程序跳转到linux 的入口。
  * 获取`id`值和环境变量`machid`比较，判断是否相等。
  * 清除CPU的cache 环境。
  * 设置函数指针`kernel_entry`的参数，分别是0、machid、fdt地址/或者bi_boot_params。如果不使用设备数的话，就是`bootargs`
  
  ```c
  /* Subcommand: GO */
  static void boot_jump_linux(bootm_headers_t *images, int flag)
  {
  	unsigned long machid = gd->bd->bi_arch_number;
  	char *s;
  	void (*kernel_entry)(int zero, int arch, uint params);/* 定义函数指针 */
  	unsigned long r2;
  	int fake = (flag & BOOTM_STATE_OS_FAKE_GO);
  
  	kernel_entry = (void (*)(int, int, uint))images->ep; /*给函数指针赋值为*/
  
  	s = getenv("machid");    /* 比较id 是不是和环境变量是相同的 */
  	if (s) {
  		if (strict_strtoul(s, 16, &machid) < 0) {
  			debug("strict_strtoul failed!\n");
  			return;
  		}
  		printf("Using machid 0x%lx from environment\n", machid);
  	}
  
  	debug("## Transferring control to Linux (at address %08lx)" \
  		"...\n", (ulong) kernel_entry);
  	bootstage_mark(BOOTSTAGE_ID_RUN_OS);
  	announce_and_cleanup(fake);					/* CPU clean up,把cache 都刷掉了。 */
  
  	if (IMAGE_ENABLE_OF_LIBFDT && images->ft_len)/* 把 r2 寄存器设置为ft_addr 或者 bi_boot_params*/
  		r2 = (unsigned long)images->ft_addr;
  	else
  		r2 = gd->bd->bi_boot_params;
  
  	if (!fake) {
  #ifdef CONFIG_ARMV7_NONSEC
  		if (armv7_boot_nonsec()) {
  			armv7_init_nonsec();
  			secure_ram_addr(_do_nonsec_entry)(kernel_entry,
  							  0, machid, r2);
  		} else
  #endif
  			kernel_entry(0, machid, r2);
  	}
  #endif
  }
  ```
  
  * 小问题，之前提到的`bootargs` 是在哪里设定的呢，怎么传递过去的？
    * 如果不适用fdt的话，参数r2 就是`bootargs`的值。



## 3. 一些指令是如何实现的?

由前面分析我们可以知道，uboot 的命令都是由`U_BOOT_CMD`实现的，所以我们可以在boot 的文件夹下搜索我们关心的命令，例如上面频繁的用到了`fatload`命令，我们可以搜索如下：

```c
:~/for_study/imax6ull/uboot$: grep  -nr "U_BOOT_CMD" | grep -n "fat"
    
/* 得到下面结果 */
1244:cmd/fat.c:27:U_BOOT_CMD(
1245:cmd/fat.c:41:U_BOOT_CMD(
1246:cmd/fat.c:61:U_BOOT_CMD(
1247:cmd/fat.c:93:U_BOOT_CMD(
1248:cmd/fat.c:145:U_BOOT_CMD(
```

可以发现，是在这些命令都在`cmd/fat.c`里面，由此可以找到命令的定义和回调函数，具体的实现就需要深入研究源码了。

```c
U_BOOT_CMD(
	fatload,	7,	0,	do_fat_fsload,
	......
	}
    
    
```

