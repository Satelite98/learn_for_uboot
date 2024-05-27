

关于CP 的操作，参考这个链接：https://www.cnblogs.com/schips/p/11270644.html

```asm
/*************************************************************************
 *
 * cpu_init_cp15
 *
 * Setup CP15 registers (cache, MMU, TLBs). The I-cache is turned on unless
 * CONFIG_SYS_ICACHE_OFF is defined.
 *
 *************************************************************************/
ENTRY(cpu_init_cp15)
	/*
	 * Invalidate L1 I/D
	 */
	mov	r0, #0			@ set up for MCR
	mcr	p15, 0, r0, c8, c7, 0	@ 无效整个数据和指令TLB
	mcr	p15, 0, r0, c7, c5, 0	@无效整个指令cache
	mcr	p15, 0, r0, c7, c5, 6	@ 无效整个跳转目标cache
	mcr p15, 0, r0, c7, c10, 4	@ 清空写缓存区
	mcr p15, 0, r0, c7, c5, 4	@ 清空预取缓存区

	/*
	 * disable MMU stuff and caches
	 */
	mrc	p15, 0, r0, c1, c0, 0	@把cp15-c1 的值读到r0中
	bic	r0, r0, #0x00002000	@ 设置低端一场中断向量表，且在可重定位状态
	bic	r0, r0, #0x00000007	@ 关闭mmu、地址对齐、禁止cache
	orr	r0, r0, #0x00000002	@ 使能地址对齐检查
	orr	r0, r0, #0x00000800	@ 使能跳转预测
#ifdef CONFIG_SYS_ICACHE_OFF
	bic	r0, r0, #0x00001000	@ 关闭 I-cahe
#else
	orr	r0, r0, #0x00001000	@ 使能 I-cahe
#endif
	mcr	p15, 0, r0, c1, c0, 0

#ifdef CONFIG_ARM_ERRATA_716044  --使能跳转预测
	mrc	p15, 0, r0, c1, c0, 0	@ read system control register
	orr	r0, r0, #1 << 11	@ set bit #11
	mcr	p15, 0, r0, c1, c0, 0	@ write system control register
#endif

//  --C15 寄存器会随着设计的不同而不同。
#if (defined(CONFIG_ARM_ERRATA_742230) || defined(CONFIG_ARM_ERRATA_794072))
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 4		@ set bit #4
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif

#ifdef CONFIG_ARM_ERRATA_743622
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 6		@ set bit #6
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif

#ifdef CONFIG_ARM_ERRATA_751472
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 11	@ set bit #11
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif
#ifdef CONFIG_ARM_ERRATA_761320
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 21	@ set bit #21
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif
#ifdef CONFIG_ARM_ERRATA_845369
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 22	@ set bit #22
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif

	mov	r5, lr			@ Store my Caller
	mrc	p15, 0, r1, c0, c0, 0	@ 把cp15-c0 读到r1
	mov	r3, r1, lsr #20		@ get variant field
	and	r3, r3, #0xf		@ r3 has CPU variant
	and	r4, r1, #0xf		@ r4 has CPU revision
	mov	r2, r3, lsl #4		@ shift variant field for combined value
	orr	r2, r4, r2		@ r2 has combined CPU variant + revision

#ifdef CONFIG_ARM_ERRATA_798870
	cmp	r2, #0x30		@ Applies to lower than R3p0
	bge	skip_errata_798870      @ skip if not affected rev
	cmp	r2, #0x20		@ Applies to including and above R2p0
	blt	skip_errata_798870      @ skip if not affected rev

	mrc	p15, 1, r0, c15, c0, 0  @ read l2 aux ctrl reg
	orr	r0, r0, #1 << 7         @ Enable hazard-detect timeout
	push	{r1-r5}			@ Save the cpu info registers
	bl	v7_arch_cp15_set_l2aux_ctrl
	isb				@ Recommended ISB after l2actlr update
	pop	{r1-r5}			@ Restore the cpu info - fall through
skip_errata_798870:
#endif

#ifdef CONFIG_ARM_ERRATA_801819
	cmp	r2, #0x24		@ Applies to lt including R2p4
	bgt	skip_errata_801819      @ skip if not affected rev
	cmp	r2, #0x20		@ Applies to including and above R2p0
	blt	skip_errata_801819      @ skip if not affected rev
	mrc	p15, 0, r0, c0, c0, 6	@ pick up REVIDR reg
	and	r0, r0, #1 << 3		@ check REVIDR[3]
	cmp	r0, #1 << 3
	beq	skip_errata_801819	@ skip erratum if REVIDR[3] is set

	mrc	p15, 0, r0, c1, c0, 1	@ read auxilary control register
	orr	r0, r0, #3 << 27	@ Disables streaming. All write-allocate
					@ lines allocate in the L1 or L2 cache.
	orr	r0, r0, #3 << 25	@ Disables streaming. All write-allocate
					@ lines allocate in the L1 cache.
	push	{r1-r5}			@ Save the cpu info registers
	bl	v7_arch_cp15_set_acr
	pop	{r1-r5}			@ Restore the cpu info - fall through
skip_errata_801819:
#endif

#ifdef CONFIG_ARM_ERRATA_454179
	cmp	r2, #0x21		@ Only on < r2p1
	bge	skip_errata_454179

	mrc	p15, 0, r0, c1, c0, 1	@ Read ACR
	orr	r0, r0, #(0x3 << 6)	@ Set DBSM(BIT7) and IBE(BIT6) bits
	push	{r1-r5}			@ Save the cpu info registers
	bl	v7_arch_cp15_set_acr
	pop	{r1-r5}			@ Restore the cpu info - fall through

skip_errata_454179:
#endif

#ifdef CONFIG_ARM_ERRATA_430973
	cmp	r2, #0x21		@ Only on < r2p1
	bge	skip_errata_430973

	mrc	p15, 0, r0, c1, c0, 1	@ Read ACR
	orr	r0, r0, #(0x1 << 6)	@ Set IBE bit
	push	{r1-r5}			@ Save the cpu info registers
	bl	v7_arch_cp15_set_acr
	pop	{r1-r5}			@ Restore the cpu info - fall through

skip_errata_430973:
#endif

#ifdef CONFIG_ARM_ERRATA_621766
	cmp	r2, #0x21		@ Only on < r2p1
	bge	skip_errata_621766

	mrc	p15, 0, r0, c1, c0, 1	@ Read ACR
	orr	r0, r0, #(0x1 << 5)	@ Set L1NEON bit
	push	{r1-r5}			@ Save the cpu info registers
	bl	v7_arch_cp15_set_acr
	pop	{r1-r5}			@ Restore the cpu info - fall through

skip_errata_621766:
#endif

	mov	pc, r5			@ back to my caller
ENDPROC(cpu_init_cp15)
```

