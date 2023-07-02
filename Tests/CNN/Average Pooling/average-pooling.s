addi x5, x0, 16                 # x5 = 16
addi x21, x0, 0                 # load data address - load data from mem
addi x30, x0, 0                 # store data address - store data in mem
addi x31, x0, 0                 # answer shift register
addi x18, x0, 8                 # max shift
addi x19, x0, 0                 # kernel shift
addi x9, x0, 8                  # max loop counter
addi x10, x0, 0                 # looper1
addi x11, x0, 1                 # looper2
jal, x0, load_input

load_input:
    addi x0, x0, 0
    beq x10, x9, end
    vsetivli x20, x5, 10        # 16-bit elements, 512-bit vector
    vle32.v v0, x21             # Loads a single 32-element row
    addi x21, x21, 16
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    vslideup.vi v20, v0, 0      # copy row data into kernel vector reg
    vle32.v v4, x21             # Loads the succeeding 32-element row
    addi x21, x21, 16
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    vslidedown.vi v0, v0, 4     # drop first 4 elements of row
    vslideup.vi v20, v4, 4      # place first 4 elements of row2 next to the first 4 elements of row1
    vle32.v v8, x21             # Loads the succeeding 32-element row
    addi x21, x21, 16
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    vslidedown.vi v4, v4, 4     # drop first 4 elements of row2
    vslideup.vi v20, v8, 8      # place first 4 elements of row3 next to the first 4 elements of row2
    vle32.v v12, x21            # Loads the succeeding 32-element row
    addi x21, x21, 16
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    vslidedown.vi v8, v8, 4     # drop first 4 elements of row3     
    vslideup.vi v20, v12, 12    # place first 4 elements of row4 next to the first 4 elements of row3 # KERNEL COMPLETE
    vslidedown.vi v12, v12, 4   # drop first 4 elements of row4
    addi x10, x10, 1            # loop1 counter++
    vsetivli x20, x5, 9         # 16-bit elements, 256-bit vector 
    vredsum.vs v20, v20, v16    # sum elements
    vsrl.vi v20, v20, 4         # divide by 16 and save
    vslideup.vx v28, v20, x31   # shift contents of answer vector
    vsetivli x20, x5, 10        # 16-bit elements, 512-bit vector
    addi x31, x31, 1            # increment shift answer
    jal, x0, average_pool

average_pool:
    addi x0, x0, 0
    beq x11, x9, store_ans
    vsetivli x20, x5, 10        # 16-bit elements, 512-bit vector
    addi x11, x11, 1            # loop2 counter++
    vslideup.vx v20, v0, x19    # place first 4 elements of row1 in kernel
    addi x19, x19, 4
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    vslidedown.vi v0, v0, 4     # drop first 4 elements of row1
    vslideup.vx v20, v4, x19    # place first 4 elements of row2 next to row1 elements
    addi x19, x19, 4
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    vslidedown.vi v4, v4, 4     # drop first 4 elements of row2
    vslideup.vx v20, v8, x19    # place first 4 elements of row3 next to row2 elements
    addi x19, x19, 4
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    vslidedown.vi v8, v8, 4     # drop first 4 elements of row3
    vslideup.vx v20, v12, x19   # place first 4 elements of row4 next to row3 elements
    addi x19, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0
    vslidedown.vi v12, v12, 4   # drop first 4 elements of row4
    vsetivli x20, x5, 9         # 16-bit elements, 256-bit vector 
    vredsum.vs v20, v20, v16    # sum elements
    vsrl.vi v20, v20, 4         # divide by 16 and save (overwrite)
    vslideup.vx v28, v20, x31   # shift contents of answer vector
    vsetivli x20, x5, 10        # 16-bit elements, 512-bit vector
    addi x31, x31, 1            # increment shift answer
    jal, x0, average_pool


store_ans:
    vsetivli x20, x5, 8         # 16-bit elements, 128-bit vector
    vse32.v v28, x30            # store answer in mem
    addi x30, x30, 4
    addi x11, x0, 1             # reset loop2 counter
    addi x31, x0, 0             # reset shift for answers
    jal, x0, load_input



end:
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
    C.NOP
