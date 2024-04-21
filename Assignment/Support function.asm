#Support function
# brief: Subtract 2 reg into result reg and return bool if overflow occurred
	# param: a0: 1st float; a1: 2nd float; s0: overwrite
.globl subtract_ieee
subtract_ieee:
# Assign B is the subtractee  // remove to make addition
    	lui 	$t3, 0x8000
    	xor	$a1, $a1, $t3
    	
# Truy xuat
   	srl 	$t2, $a0, 31 		# sign of A
   	srl 	$t3, $a1, 31 		# sign of B

    	sll	$t4, $a0, 1
    	srl 	$t4, $t4, 24	# exponent of A
    	sll	$t5, $a1, 1
    	srl 	$t5, $t5, 24 	# exponent of B
    	
    	lui	$at, 0x7f
    	ori	$at, $at, 0xffff
    	and	$t6, $a0, $at # fraction of A
    	
    	lui	$at, 0x7f
    	ori	$at, $at, 0xffff
    	and	$t7, $a1, $at # fraction of B	
# Case 0:
    	beq 	$zero, $t4, zero_A
    	beq 	$zero, $t5, zero_B
    	
# Case NaN / Inf
	addi	$at, $zero, 0xff
	beq	$at, $t4, Inf_A
	beq	$at, $t5, Inf_B
# Adding 1.xxxx    	
	and 	$at, $at, $zero
	lui	$at, 0x80
    	or	$t6, $t6, $at
	or 	$t7, $t7, $at
# Perform subtraction
	slt	$at, $t4, $t5
	bne 	$at, $zero, A_lt_B	
	A_gt_B:		#A>B
	subu 	$t8, $t4, $t5	
	srlv 		$t7, $t7, $t8	# Dich mantissa cua so thu 2 sang phai $t8 lan
	or 		$t1,  $t4, $zero			# Gan exponent so lon hon cho ket qua
	
	j 	sum_mantissa
	A_lt_B: 	#A<B
	subu		$t8, $t5, $t4
	srlv		$t6, $t6, $t8	# Dich mantissa cua so thu 1 sang phai $t8 lan
	or		$t1, $t5, $zero			# Gan exponent so lon hon cho ket qua
	
sum_mantissa:
		# 2's complement 1st num
	beq	$t2, $zero, next_branch
	nor	$t6, $t6, $zero
	addi	$t6, $t6, 1
	next_branch:	
		# 2's complement 2nd num
	beq	$t3, $zero, add_func
	nor 	$t7, $t7, $zero
	addi	$t7, $t7, 1
	add_func:
	addu $s0, $t6, $t7	# Cong 2 mantissa lai (ko quan tam tran`)
		# check sign
	lui 	$at, 0x200
	and	$t9, $s0, $at
	srl	$t9, $t9, 25
	or 	$t0, $t9, $zero
		# neg sum
	slt	$at, $s0, $zero
	bne	$at, $zero, neg_sum
	
	andi 	$t9, 0x0			# Xoa bit thua ko can thiet
	lui	$at, 0x1ff
	ori	$at, $at, 0xffff
	and	$s0, $s0, $at			# Xoa bit thua ko can thiet (filter)
adjust_mantissa:
	beqz	$s0, mantiE0
	lui	$at, 0x100
	sltu	$at, $s0, $at
	beq	$at, $zero, adj_14		# Dich sang phai neu lon hon 0x1000000
	lui	$at, 0x80
	sltu	$at, $s0, $at
	bne	$at, $zero, adj_12		# Dich sang trai neu be hon 0x800000
	# modified mantissa
	lui	$at, 0x7f
	ori	$at, $at, 0xffff
	and 	$s0, $s0, $at				# Xoa bit 1 o dau` (1.xxxx) de thu ket qua mantissa 
	j	adjust_expon
	mantiE0:							# Truong hop mantisa bang 0
	bne 	$t4, $t5, combine
	li		$t1, 0
	j	combine
	adj_14: 
	srl 		$s0, $s0, 1
	addi	$t9, $t9, 1
	j		adjust_mantissa
	adj_12: 
	sll	$s0, $s0, 1
	addi	$at, $zero, 0x1
	sub 	$t9, $t9, $at
	j		adjust_mantissa

adjust_expon: 
	add	$t1, $t1, $t9
	addi	$at, $zero, 0xff
	bne	$at, $t1, combine	# kiem tra neu tra`n so (inf)
	overflow_case:
	and	$s0, $s0, $zero		# Xoa mantissa de tro thanh inf
	
combine:					# Hop thanh san pham 
	lui	$t8, 0x0
	or	$t8, $t8, $t0

	sll	$t8, $t8, 8
	or	$t8, $t8, $t1

	sll	$t8, $t8, 23
	or	$t8, $t8, $s0
	
write_back:
	lui 	$at, 0x8000
    	xor	$a1, $a1, $at
	or	$s0, $t8, $zero
	jr	$ra
	
neg_sum:
	nor	$s0, $s0, $zero
	addi	$s0, $s0, 1
	andi 	$t9, 0x0
	j	adjust_mantissa	
zero_A:
    # If A is zero, the result is -B
    	or	$t8, $a1, $zero
    	j 	write_back

zero_B:
    # If B is zero, the result is A
    	or	$t8, $a0, $zero
    	j 	write_back
    	
Inf_A:
	# If B is neg Inf, return NaN
	addi	$at, $zero, 0xff
	bne	$at, $t5, return_Inf_A
	xor	$t8, $t2, $t3
	beqz	$t8, return_Inf_A
	beq	$at, $t5, NaN_Case
	beqz	$t6, NaN_Case
	return_Inf_A:
	j 	write_back
Inf_B:	
	addi	$at, $zero, 0xff
	bne	$t4, $at, return_Inf_B
	xor	$t8, $t2, $t3
	beqz	$t8, return_Inf_B
	beq	$t4, $at, NaN_Case
	beq	$t7, $zero, NaN_Case
	return_Inf_B:
	j 	write_back
NaN_Case:
	lui	$t8, 0x7fff
	ori	$t8, 0xffff
	j	write_back
	
# brief: Print current result of floating array
# param: a0: address of first array
#		a1: address of last array
# retvl: None
print_ieee_array:
	addiu	$t1, $a1, 4
	or		$t0, $a0, $zero	#Init address
	loop:
	lwc1		$f12, 0($t0)		#Load the value
	li		$v0, 2
	syscall
		space
	addiu	$t0, $t0, 4
	bne		$t0, $t1, loop
	jr		$ra
	
		
