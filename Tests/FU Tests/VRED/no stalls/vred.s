ADDI x5, x0, 16
#512-bits vred tests
vsetivli x20, x5, 18 #32 bit elements 512-bit vector
ADDI x5, x5, 16
vle32.v v4, x0
vle32.v v8, x0
vredmax.vs v8, v4, v0
ADDI x1, x0, 0
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v8, x1
vredsum.vs v12, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v12, x1
vsetivli x20, x5, 10 #16 bit elements 512-bit vector
vredmax.vs v16, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v16, x1
vredsum.vs v20, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v20, x1
vsetivli x20, x5, 2 #8 bit elements 512-bit vector
vredmax.vs v24, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v24, x1
vredsum.vs v28, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v28, x1
#256-bits vred tests
vsetivli x20, x5, 17 #32 bit elements 256-bit vector
ADDI x5, x5, 16
C.NOP
C.NOP
C.NOP
vredmax.vs v8, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v8, x1
vredsum.vs v12, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v12, x1
vsetivli x20, x5, 9 #16 bit elements 256-bit vector
vredmax.vs v16, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v16, x1
vredsum.vs v20, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v20, x1
vsetivli x20, x5, 1 #8 bit elements 256-bit vector
vredmax.vs v24, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v24, x1
vredsum.vs v28, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v28, x1
#128-bits vred tests
vsetivli x20, x5, 16 #32 bit elements 128-bit vector
ADDI x5, x5, 16
C.NOP
C.NOP
C.NOP
vredmax.vs v8, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v8, x1
vredsum.vs v12, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v12, x1
vsetivli x20, x5, 8 #16 bit elements 128-bit vector
vredmax.vs v16, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v16, x1
vredsum.vs v20, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v20, x1
vsetivli x20, x5, 0 #8 bit elements 128-bit vector
vredmax.vs v24, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v24, x1
vredsum.vs v28, v4, v0
ADDI x1, x1, 16
C.NOP
C.NOP
C.NOP
C.NOP
C.NOP
vse32.v v28, x1
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
