.data

input: .space 200
stack: .space 100			# 25
postfix: .space 100			# 25
postfixTags: .space 100  	# 25, tags: 1 - operand, 2 - operator
evalStack: .space 100

prompt: .asciiz "Enter expression: "
error: .asciiz "SYNTAX ERROR"

.text
main:

################# STEP 1: ASK INPUT #################
# Ask input
li $v0, 4
la $a0, prompt
syscall
li $v0, 8
la $a0, input
li $a1, 256
syscall

# Print input
li $v0, 4
la $a0, input
syscall

################# STEP 2: CONVERT TO POSTFIX #################

# Constants
li $s0, 25			# Max elements of stack
li $s1, 1					
li $s2, 2		

li $t0, 0			# char index
li $t1, 0			# context (0 - none, 1 - number)
li $t2, 0       	# number buffer
li $t3, 0			# stack offset
li $t4, 0			# postfix offset

li $t8, 0			# Parenthesis pairing counter

# For every character
iterateInput:
	# t5 = char
	la $t5, input
	add $t5, $t5, $t0
	lb $t5, 0($t5)		
	
	# End loop if char = '\n'
	beq $t5, '\0', end_iterateInput
	
	# If digit, append to number buffer
	beq $t5, '0', appendDigit
	beq $t5, '1', appendDigit
	beq $t5, '2', appendDigit
	beq $t5, '3', appendDigit
	beq $t5, '4', appendDigit
	beq $t5, '5', appendDigit
	beq $t5, '6', appendDigit
	beq $t5, '7', appendDigit
	beq $t5, '8', appendDigit
	beq $t5, '9', appendDigit
	
	# If previous context was number, push it
	beq $t1, 1, pushNumber
	ret_iterateInput_pushNumber:
	
	# If operator
	beq $t5, '+', scanOperator
	beq $t5, '-', scanOperator
	beq $t5, '*', scanOperator
	beq $t5, '/', scanOperator
	
	# If '('
	beq $t5, '(', pushParenthesisToStack
	
	# If ')'
	beq $t5, ')', popUntilOpening
	
	ret_iterateInput:

	add $t0, $t0, 1
	b iterateInput
end_iterateInput:


# If parenthesis pairing != 0, syntax error
bnez $t8, syntaxError
	
# Pop and push all other operators
b popAll
ret__popAll:


################# STEP 3: EVALUATE POSTFIX #################
li $t0, 0		# postfix offset
li $t1, 0		# evalstack offset

evalPostfix:
	# Get tag (t2)
	la $t2, postfixTags
	add $t2, $t2, $t0
	lw $t2, 0($t2)
	
	# If tag = 0, end
	beqz $t2, end_evalPostfix
	
	# Get value (t3)
	la $t3, postfix
	add $t3, $t3, $t0
	lw $t3, 0($t3)
	
	# If operand
	beq $t2, 1, evalOperand
	
	# If operator
	beq $t2, 2, evalOperator
	
	ret_evalPostfix:
	
	add $t0, $t0, 4
	b evalPostfix
	

end_evalPostfix:

# If t1 - 4 != 0, syntax error
add $t9, $t1, -4
bnez $t9, syntaxError

################# STEP 4: PRINT POSTFIX AND RESULT #################

li $t0, 0		# postfix array offset
printPostfix:
	# Get tag (t1)
	la $t1, postfixTags
	add $t1, $t1, $t0
	lw $t1, 0($t1)
	
	# If tag=0, end
	beqz $t1, end_printPostfix
	
	# Get value (a0)
	la $a0, postfix
	add $a0, $a0, $t0
	lw $a0, 0($a0)
	
	# If tag = 2 (operator)
	beq $t1, 2, printPostfix_operator
	
	printPostfix_operand:
		li $v0, 1
		j ret_printPostfix
	printPostfix_operator:
		li $v0, 11
	ret_printPostfix:
	syscall
	
	# Print space
	li $v0, 11
	li $a0, ' '
	syscall
	
	# Increment offset
	add $t0, $t0, 4
	
	b printPostfix
end_printPostfix:

# Print line break
li $v0, 11
li $a0, '\n'
syscall

# Print result
la $a0, evalStack
lwc1 $f12, 0($a0)
li $v0, 2
syscall

exit:
	li $v0, 10
	syscall

############ SUBROUTINES ###############
appendDigit:  # Append digit ($t5) to number buffer ($t2)
	mul $t2, $t2, 10
	add $t2, $t2, $t5
	add $t2, $t2, -48		# char-to-digit correction
	
	# Set context to 1
	li $t1, 1
	
	# Go back to callee
	j ret_iterateInput

scanOperator:
	# t6 = level(char)
	move $a0, $t5
	jal getOperationLevel
	move $t6, $v0
	
	
	# While length(stack) > 0 && level(char) <= level(lastChar)
	scanOperator_maybePop:
		beq $t3, 0, end_scanOperator_maybePop	# if length(stack) = 0, end
		
		la $t7, stack
		add $t7, $t7, $t3
		add $t7, $t7, -4
		lw $t7, 0($t7)							# t7 = lastChar
		
		move $a0, $t7
		jal getOperationLevel   				# v0 = level(lastChar)
		
		bgt $t6, $v0, end_scanOperator_maybePop	# if level(char) > level(last), end
		
		# Pop lastChar from stack
		add $t3, $t3, -4
		
		# Push lastChar to postfix
		move $a0, $t7
		jal pushOperator
		
		b scanOperator_maybePop
		
	end_scanOperator_maybePop:
	
	# Push char operator to stack
	j pushToStack
	ret_scanOperator_pushToStack:
	
	j ret_iterateInput

pushParenthesisToStack:
	la $t9, stack
	add $t9, $t9, $t3
	sw $t5, 0($t9)
	
	# parenthesis pairing +1
	add $t8, $t8, 1
	
	add $t3, $t3, 4
	j ret_iterateInput

popUntilOpening:
	# If parenthesis pairing = 0, syntax error
	beqz $t8, syntaxError

	la $t7, stack
	add $t3, $t3, -4
	add $t7, $t7, $t3
	lw $t7, 0($t7)							# t7 = lastChar
	
	# If char = '(', end
	beq $t7, '(', end_popUntilOpening
	
	move $a0, $t7
	jal pushOperator
	
	b popUntilOpening
	end_popUntilOpening:
	
	# parenthesis pairing -1
	add $t8, $t8, -1
	j ret_iterateInput

pushNumber:
	# Push number buffer to postfix
	la $t9, postfix
	add $t9, $t9, $t4
	sw $t2, 0($t9)		# pfix[idx] = num
	
	# Save tag
	la $t9, postfixTags
	add $t9, $t9, $t4
	sw $s1, 0($t9)		# tags[idx] = 1  // operand
	
	add $t4, $t4, 4		# increment offset
	li $t2, 0			# reset number buffer
	li $t1, 0			# reset context
	j ret_iterateInput_pushNumber

pushToStack:
	la $t9, stack
	add $t9, $t9, $t3
	sw $t5, 0($t9)
	
	add $t3, $t3, 4
	j ret_scanOperator_pushToStack
	
pushOperator:
	# Push operator value to postfix
	la $t9, postfix
	add $t9, $t9, $t4
	sw $a0, 0($t9)		# pfix[idx] = num
	
	# Save tag
	la $t9, postfixTags
	add $t9, $t9, $t4
	sw $s2, 0($t9)		# tags[idx] = 2  // operator
	
	add $t4, $t4, 4		# increment offset
	jr $ra

getOperationLevel:
	# Operation levels: 1 - add/sub, 2 - mult/div
	beq $a0, '(', getLastStackLevel_0
	beq $a0, '+', getLastStackLevel_1
	beq $a0, '-', getLastStackLevel_1
	beq $a0, '*', getLastStackLevel_2
	beq $a0, '/', getLastStackLevel_2
	
	getLastStackLevel_0:
		li $v0, 0 
		jr $ra
		
	getLastStackLevel_1:
		li $v0, 1
		jr $ra
	
	getLastStackLevel_2:
		li $v0, 2
		jr $ra
		
	jr $ra

popAll:
	beq $t3, 0, endPopAll
	
	la $t7, stack
	add $t7, $t7, $t3
	add $t7, $t7, -4
	lw $a0, 0($t7)							# a0 = lastChar
	jal pushOperator
	
	add $t3, $t3, -4
	b popAll
	
	endPopAll:
	j ret__popAll

evalOperand:
	# Convert operand (t3) to float (f0)
	mtc1 $t3, $f0
	cvt.s.w $f0, $f0
	
	# Push operand (f0) to evalstack
	la $t9, evalStack
	add $t9, $t9, $t1
	swc1 $f0, 0($t9)
	
	add $t1, $t1, 4
	j ret_evalPostfix
 
evalOperator:
	# If $t1 - 8 < 0, syntax error
	add $t9, $t1, -8
	bltz $t9, syntaxError
	
	# Pop last two operands in evalstack (f1, f2)
	la $t9, evalStack
	add $t9, $t9, $t1
	lwc1 $f1, -8($t9)
	lwc1 $f2, -4($t9)
	
	# Perform operation (result: f3)
	beq $t3, '+', evalAdd
	beq $t3, '-', evalSub
	beq $t3, '*', evalMul
	beq $t3, '/', evalDiv
	
	ret_evalOperator:
	
	# Replace second-to-last operand in evalstack with result
	swc1 $f3, -8($t9)
	
	# Update evalstack offset
	add $t1, $t1, -4
	
	j ret_evalPostfix
	
evalAdd:
	add.s $f3, $f1, $f2
	j ret_evalOperator
	
evalSub:
	sub.s $f3, $f1, $f2
	j ret_evalOperator
	
evalMul:
	mul.s $f3, $f1, $f2
	j ret_evalOperator

evalDiv:
	div.s $f3, $f1, $f2
	j ret_evalOperator
	
	
syntaxError:
	li $v0, 4
	la $a0, error
	syscall
	j exit
