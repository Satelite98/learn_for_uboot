CONFIG_VIDEO_BMP_LOGO=y
CONFIG_BOOTM_NETBSD=y
CONFIG_BOOTCOMMAND="run updateset;run findfdt;run findtee;mmc dev ${mmcdev};mmc dev ${mmcdev}; if mmc rescan; then if run loadbootscript; then run bootscript; else if run loadimage; then run mmcboot; else run netboot; fi; fi; else run netboot; fi"
CONFIG_IMX_CONFIG="board/freescale/mx6ullevk/imximage.cfg"
CONFIG_SYS_FSL_ESDHC_ADDR="USDHC2_BASE_ADDR"
CONFIG_BOOTM_VXWORKS=y
CONFIG_SF_DEFAULT_MODE="SPI_MODE_0"
CONFIG_SYS_LONGHELP=y
CONFIG_IS_MODULE(option)="config_enabled(CONFIG_VAL(option ##_MODULE))"
CONFIG_VIDEO_MXS=y
CONFIG_SYS_LOAD_ADDR=$(CONFIG_LOADADDR)
CONFIG_SYS_FSL_MAX_NUM_OF_SEC=y
CONFIG_STACKSIZE="SZ_128K"
CONFIG_SYS_HELP_CMD_WIDTH=8
CONFIG_NR_DRAM_BANKS=y
CONFIG_IMX_VIDEO_SKIP=y
CONFIG_FS_FAT=y
CONFIG_BOOTM_RTEMS=y
CONFIG_SYS_CBSIZE=512
CONFIG_BOOTM_LINUX=y
CONFIG_MODULE_FUSE=y
CONFIG_SOFT_SPI=y
CONFIG_MII=y
CONFIG_REVISION_TAG=y
CONFIG_SYS_FSL_QSPI_AHB=y
CONFIG_SYS_FSL_CLK=y
CONFIG_SYS_FSL_SEC_ADDR="(CAAM_BASE_ADDR + CONFIG_SYS_FSL_SEC_OFFSET)"
CONFIG_SYSCOUNTER_TIMER=y
CONFIG_OF_SYSTEM_SETUP=y
CONFIG_ENV_OFFSET="(14 * SZ_64K)"
CONFIG_MXC_OCOTP=y
CONFIG_ENV_OVERWRITE=y
CONFIG_ENV_SIZE="SZ_8K"
CONFIG_SUPPORT_RAW_INITRD=y
CONFIG_SYS_MALLOC_LEN="(16 * SZ_1M)"
CONFIG_SYS_MMC_ENV_DEV=y
CONFIG_SYS_I2C_SPEED=100000
CONFIG_SYS_BOOTM_LEN=0x1000000
CONFIG_SYS_TEXT_BASE=0x87800000
CONFIG_MXC_GPT_HCLK=y
CONFIG_MXC_UART=y
CONFIG_SPLASH_SCREEN=y
CONFIG_SYS_BARGSIZE=$(CONFIG_SYS_CBSIZE)
CONFIG_BOOTM_PLAN9=y
CONFIG_IS_BUILTIN(option)="config_enabled(CONFIG_VAL(option))"
CONFIG_VIDEO_BMP_RLE8=y
CONFIG_MXC_USB_PORTSC="(PORT_PTS_UTMI | PORT_PTS_PTW)"
CONFIG_LIB_RAND=y
CONFIG_SYS_FSL_JR0_ADDR="(CAAM_BASE_ADDR + CONFIG_SYS_FSL_JR0_OFFSET)"
CONFIG_SF_DEFAULT_BUS=0
CONFIG_SYS_MAXARGS=32
CONFIG_BMP_16BPP=y
CONFIG_SYS_PBSIZE="(CONFIG_SYS_CBSIZE + 128)"
CONFIG_FEC_XCV_TYPE="RMII"
CONFIG_MXC_GPIO=y
CONFIG_BOARDDIR="board/freescale/mx6ullevk"
CONFIG_BOUNCE_BUFFER=y
CONFIG_SYS_MAX_FLASH_SECT=512
CONFIG_PHYLIB=y
CONFIG_BOARD_POSTCLK_INIT=y
CONFIG_CMDLINE_EDITING=y
CONFIG_MFG_ENV_SETTINGS="mfgtool_args=setenv bootargs console=${console},${baudrate} " BOOTARGS_CMA_SIZE "rdinit=/linuxrc g_mass_storage.stall=0 g_mass_storage.removable=1 g_mass_storage.file=/fat g_mass_storage.ro=1 g_mass_storage.idVendor=0x066F g_mass_storage.idProduct=0x37FF g_mass_storage.iSerialNumber=" MFG_NAND_PARTITION "clk_ignore_unused 0initrd_addr=0x838000000initrd_high=0xffffffff0bootcmd_mfg=run mfgtool_args; if test ${tee} = yes; then bootm ${tee_addr} ${initrd_addr} ${fdt_addr}; else bootz ${loadaddr} ${initrd_addr} ${fdt_addr}; fi;0"
CONFIG_ZLIB=y
CONFIG_LOADADDR=0x80800000
CONFIG_ETHPRIME="eth1"
CONFIG_AUTO_COMPLETE=y
CONFIG_FSL_USDHC=y
CONFIG_ENV_IS_IN_MMC=y
CONFIG_FEC_ENET_DEV=y
CONFIG_SYS_MMC_IMG_LOAD_PART=2
CONFIG_SYS_FSL_SEC_OFFSET=0
CONFIG_GZIP=y
CONFIG_SC_TIMER_CLK=8000000
CONFIG_SYS_INIT_RAM_SIZE="IRAM_SIZE"
CONFIG_IOMUX_LPSR=y
CONFIG_FEC_MXC_PHYADDR=0x1
CONFIG_SYS_BAUDRATE_TABLE="{ 9600, 19200, 38400, 57600, 115200 }"
CONFIG_VAL(option)="config_val(option)"
CONFIG_SUPPORT_EMMC_BOOT=y
CONFIG_SYS_SDRAM_BASE="PHYS_SDRAM"
CONFIG_IMAGE_FORMAT_LEGACY=y
CONFIG_SYS_BOOT_RAMDISK_HIGH=y
CONFIG_PHY_SMSC=y
CONFIG_SYS_FSL_USDHC_NUM=2
CONFIG_USB_ETHER_ASIX=y
CONFIG_SYS_INIT_SP_OFFSET="(CONFIG_SYS_INIT_RAM_SIZE - GENERATED_GBL_DATA_SIZE)"
CONFIG_FEC_MXC_MDIO_BASE="ENET2_BASE_ADDR"
CONFIG_SYS_INIT_RAM_ADDR="IRAM_BASE_ADDR"
CONFIG_EXTRA_ENV_SETTINGS="CONFIG_MFG_ENV_SETTINGS TEE_ENV "update=undefined0script=boot.scr0image=zImage0console=ttymxc00bootdir=/boot0fdt_high=0xffffffff0initrd_high=0xffffffff0fdt_file=100ask_imx6ull-14x14.dtb0fdt_addr=0x830000000tee_addr=0x840000000tee_file=uTee-6ullevk0boot_fdt=try0ip_dyn=yes0panel=TFT70160ethaddr=00:01:1f:2d:3e:4d0eth1addr=00:01:3f:2d:3e:4d0mmcdev=__stringify(CONFIG_SYS_MMC_ENV_DEV)"0mmcpart=" __stringify(CONFIG_SYS_MMC_IMG_LOAD_PART) "0mmcroot=" CONFIG_MMCROOT " rootwait rw0mmcautodetect=no0mmcargs=setenv bootargs console=${console},${baudrate} " BOOTARGS_CMA_SIZE "root=${mmcroot}0loadbootscript=fatload mmc ${mmcdev}:${mmcpart} ${loadaddr} ${script};0bootscript=echo Running bootscript from mmc ...; source0loadimage=ext2load mmc ${mmcdev}:${mmcpart} ${loadaddr} ${bootdir}/${image}0loadfdt=ext2load mmc ${mmcdev}:${mmcpart} ${fdt_addr} ${bootdir}/${fdt_file}0loadtee=fatload mmc ${mmcdev}:${mmcpart} ${tee_addr} ${tee_file}0mmcboot=echo Booting from mmc ...; run mmcargs; if test ${tee} = yes; then run loadfdt; run loadtee; bootm ${tee_addr} - ${fdt_addr}; else if test ${boot_fdt} = yes || test ${boot_fdt} = try; then if run loadfdt; then bootz ${loadaddr} - ${fdt_addr}; else if test ${boot_fdt} = try; then bootz; else echo WARN: Cannot load the DT; fi; fi; else bootz; fi; fi;0updateset=if test $update = undefined; then setenv update yes; saveenv; fi;0netargs=setenv bootargs console=${console},${baudrate} " BOOTARGS_CMA_SIZE "root=/dev/nfs ip=dhcp nfsroot=${serverip}:${nfsroot},v3,tcp0netboot=echo Booting from net ...; run netargs; setenv get_cmd tftp; ${get_cmd} ${image}; ${get_cmd} ${fdt_addr} ${fdt_file};  bootz ${loadaddr} - ${fdt_addr};0findfdt=if test $fdt_file = undefined; then if test $board_name = EVK && test $board_rev = 9X9; then setenv fdt_file imx6ull-9x9-evk.dtb; fi; if test $board_name = EVK && test $board_rev = 14X14; then setenv fdt_file imx6ull-14x14-evk.dtb; fi; if test $fdt_file = undefined; then setenv fdt_file imx6ull-14x14-alpha.dtb; fi; fi;0"
CONFIG_SYS_INIT_SP_ADDR="(CONFIG_SYS_INIT_RAM_ADDR + CONFIG_SYS_INIT_SP_OFFSET)"
CONFIG_FSL_ESDHC=y
CONFIG_IMX_THERMAL=y
CONFIG_BAUDRATE=115200
CONFIG_INITRD_TAG=y
CONFIG_CMD_BMODE=y
CONFIG_CMDLINE_TAG=y
CONFIG_MXC_UART_BASE="UART1_BASE"
CONFIG_SPLASH_SCREEN_ALIGN=y
CONFIG_USB_HOST_ETHER=y
CONFIG_SYS_MMC_ENV_PART=0
CONFIG_FEC_MXC=y
CONFIG_SYS_MMC_MAX_BLK_COUNT=65535
CONFIG_SYS_DEF_EEPROM_ADDR=0
CONFIG_FS_EXT4=y
CONFIG_SYS_MEMTEST_END="(CONFIG_SYS_MEMTEST_START + 0x8000000)"
CONFIG_MMCROOT="/dev/mmcblk1p2"
CONFIG_SETUP_MEMORY_TAGS=y
CONFIG_EXT4_WRITE=y
CONFIG_SYS_MEMTEST_START=0x80000000
CONFIG_SF_DEFAULT_SPEED=40000000
CONFIG_CONS_INDEX=y
CONFIG_LMB=y
CONFIG_SYS_I2C_MXC=y
CONFIG_IS_ENABLED(option)="(config_enabled(CONFIG_VAL(option)) || config_enabled(CONFIG_VAL(option ##_MODULE)))"
CONFIG_ENV_VARS_UBOOT_RUNTIME_CONFIG=y
CONFIG_SYS_I2C_MXC_I2C1=y
CONFIG_SYS_I2C_MXC_I2C2=y
CONFIG_SYS_FSL_JR0_OFFSET=0x1000
CONFIG_CMD_MII=y
CONFIG_CMD_BMP=y
CONFIG_VIDEO_LOGO=y
CONFIG_CMD_FUSE=y
CONFIG_SF_DEFAULT_CS=0
