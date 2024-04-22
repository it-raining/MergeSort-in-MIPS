.include "BTL003.mac"
### DATA Segment ###
.data
	fileName: .asciiz "FLOAT15.bin"
	FD: .word 0
	array: .float 	5, 4, 3, 2, 1 #5					# Some testcase used for test?
				-1.1, 6.3, 1, 6.6, 10 #10
				-999.999, 5.6, 4.7, 11, 0 #15
	length: .word 15
	tmp_array: .float 0:15
	## Some char string
	cannot_open_file: .asciiz "Error handle: Can not open file"
	cannot_read_file: .asciiz "Error handle: Can not read file"
### TEXT Segment ###
.text
.globl main
main: 
	# Open the Binary file, which one I have no idea wtf is going on
	li		$v0, 13
	la		$a0, fileName
	li		$a1, 0				# Only read
	li		$a2, 1
	syscall
	slt		$t0, $v0, $zero		#v0 < zero?1:0
	bne		$t0, $zero, error_openfile_handle
	sw		$v0, FD				# Save file descript
	# Read the file
	li		$v0, 14				
	lw		$a0, FD				# Load file descript
	la		$a1, array
	li		$a2, 60
	syscall
	slt		$t0, $v0, $zero		#v0 < zero?1:0
	bne		$t0, $zero, error_readfile_handle

	# TESTED SEGMENT:
	la		$a0, array			# Address of first element				
	lw		$at, length			# Length of array
	addiu	$at, $at, -1			# CAUTION: Idk but this thing can be wrong
	sll		$at, $at, 2			# Calculate address of last element
	addu	$a1, $a0, $at			
	
	#Print the before sorting array
	jal		print_ieee_array
	endl
	
	#Let's mergeSort
	addiu	$sp, $sp, 60			#4 word for each 15-element array
	jal		mergeSort
	endl
	
	#Print the after sorting array
	la		$a0, array			# Address of first element
	lw		$at, length			# Length of array
	addiu	$at, $at, -1			# Calculate address of last element
	sll		$at, $at, 2
	addu	$a1, $a0, $at
	jal		print_ieee_array
	endl
	
	jal		close_file
# x x x x x x
#^            ^
#first	last addr
# @brief: Merge sort for floating point single precision
# @arg:
#		$a0: address of first element
#		$a1: address of last element
# @retval: None
# CAUTION:
#	Stack flow: +0 = retaddr; +4 = first addr; +8 = last addr; +12 = middle addr
#	Register currently using: 
#		$s6: address of the middle of array

mergeSort:
	addiu	$sp, $sp, -16
	sw		$ra, 0($sp)			#Save retaddr
	sw		$a0, 4($sp)			#Save first addr
	sw		$a1, 8($sp)			#Save last addr
	
	sub		$t0, $a1, $a0			#Check if the address out of range
	slt		$t0, $zero, $t0		# a1-a0 > 0 ?1:0
	beq		$t0, $zero, return_mergeSort
	
	nor		$t1, $a0, $zero		# last minus first
	addiu	$t1, $t1, 1
	add		$t1, $a1, $t1			
	sra		$t1, $t1, 1			# Middle point (divide by 2)
	add		$s6, $a0, $t1			# Middle address
	ori		$at, $zero, 3			# Round down to the nearest multiple of 4
	nor		$at, $at, $zero			#0x FFFF _ FFFC <Mask for middle address>
	and		$s6, $s6, $at			# The point of this is to point exactly the middle element of array
	sw		$s6, 12($sp)			# Save middle address into stack	
	
	lw		$a0, 4($sp)
	lw		$a1, 12($sp)
	jal		print_ieee_array
	endl
	jal		mergeSort			# mergeSort(first, middle)
	
	lw		$a0, 12($sp)
	addiu	$a0, $a0, 4
	lw		$a1, 8($sp)
	jal		print_ieee_array
	endl
	jal		mergeSort			# mergeSort(middle + 1, last)

	lw		$a0, 4($sp)
	lw		$a1, 12($sp)
	lw		$a2, 8($sp)
	jal		merge				# merge(first, middle, last)
return_mergeSort:
	lw		$ra, 0($sp)
	addiu	$sp, $sp, 16
	jr		$ra
	

# @brief: Merge (horrible things I gonna make)
# @arg:
#		$a0: address of first element
#		$a1: address of middle element
#		$a2: address of last element
# @retval: None
# CAUTION:
#	Stack flow: +0 = retaddr; +4 = first addr; +8 = middle addr; +12 = last addr
#	Register currently using: 
#		$s0: retvl for subtract (can be overwrite)
#		$s1: Working address for first arr
#		$s2: Working address for sec arr
#		$s3: Addr of Temp array
merge:
	addiu	$sp, $sp, -16		# Adjust the stack pointer
	sw		$ra, 0($sp)		# Store the return address on the stack
	sw		$a0, 4($sp)		# Store the start address on the stack
	sw		$a1, 8($sp)		# Store the midpoint address on the stack
	sw		$a2, 12($sp)		# Store the end address on the stack
	
	la		$s3, tmp_array	#We dont give a f to this array
	or		$s1, $a0, $zero	# Working address for first arr
	or		$s2, $a1, $zero	# Working address for sec arr
	addiu	$s2, $s2, 4
merge_loop:
	# Call subtract ieee754
	lw		$a0, 0($s1)		#  first value of 1st arr
	lw		$a1, 0($s2)		# first value of 2nd arr
	jal		subtract_ieee
	slt		$t0, $zero, $s0	# a0 - a1 > zero ? 1 : 0
	beq		$t0, $zero, first_half	# branch if a0 < a1
	sw		$a1, 0($s3)		# Otherwise copy  sec half into array
	addiu	$s2, $s2, 4		#2nd_arr[j++]
	j		update_pointers
first_half:
	sw		$a0, 0($s3)
	addiu		$s1, $s1, 4		#1st_arr[i++]

update_pointers:
	# Check if reach the end of array
	lw		$a1, 8($sp)
	lw		$a2, 12($sp)
	addi		$at, $zero, 4
	addu	$a1, $a1, $at		# Point to end of array (not element)
	addu	$a2, $a2, $at		# Point to end of array (not element)
	beq		$s1, $a1, copy_second_half		# If we reach to the end of first array, copy the rest of 2nd arr
	beq		$s2, $a2, copy_first_half			# Similar to above
	addiu	$s3, $s3, 4		# tmp_arr[k++]
	#If not, continue merge
	j		merge_loop
copy_first_half:
	addiu	$s3, $s3, 4
	lwc1		$f0, 0($s1)
	swc1	$f0, 0($s3)
	addiu	$s1, $s1, 4
	bne		$s1, $a1, copy_first_half
	j		end_merge	
copy_second_half:
	addiu	$s3, $s3, 4
	lwc1		$f0, 0($s2)
	swc1	$f0, 0($s3)
	addiu	$s2,	$s2, 4
	bne		$s2, $a2, copy_second_half
	j		end_merge
	
end_merge:
	la		$t0, tmp_array		# Get back addr of sorted arr
	lw		$t1, 4($sp)		# Addr of first element
	addiu	$t3, $s3, 4		# Point to end of array (not element)
end_merge_loop:
	lwc1		$f0, 0($t0)
	swc1	$f0, 0($t1)
	addiu	$t0, $t0, 4		# Next addr of temp
	addiu	$t1, $t1, 4		# Next addr of arr
	bne		$t0, $t3, end_merge_loop
return_merge:
	# Print the current working on array
	la		$a0, tmp_array	# Addr of tmp array
	addiu	$a1, $t3, -4		# Addr of the last item in array
	jal		print_ieee_array
	endl
	lw		$ra, 0($sp)
	addiu	$sp, $sp, 16
	jr		$ra

.include "Support function.asm"
error_openfile_handle:
	print_text(cannot_open_file)
	li	$v0, 10
	syscall
error_readfile_handle:
	print_text(cannot_read_file)
	li	$v0, 10
	syscall
close_file:
	lw		$a0, FD
	li		$v0, 16
	syscall
	li		$v0, 10
	syscall
