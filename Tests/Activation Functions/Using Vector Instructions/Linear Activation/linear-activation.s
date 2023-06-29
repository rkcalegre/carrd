addi x5, x0, 16                 # x5 = 16
C.NOP
C.NOP
C.NOP
vsetivli x20, x5, 18            # 32-bit elements, 512-bit vector
addi x1, x0, 0                  # store data address - load data from m[0]
jal, x0, linear_activation

linear_activation:              # f(x) = x
    vle32.v v4, x1
    vadd.vi v8, v4, 0
    vse32.v v8, x1
    jal, x0, end

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

