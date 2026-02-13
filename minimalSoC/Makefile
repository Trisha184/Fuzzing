# Use the exact path from your 'ls' output
RISCV_PATH = $(HOME)/riscv64-toolchain/bin/
CROSS      = $(RISCV_PATH)riscv64-unknown-elf-

CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump

VCS = vcs
VCS_FLAGS  = -full64 -sverilog +v2k -debug_access+all

# IMPORTANT: Even though it's a 64-bit compiler, these flags 
# force it to produce 32-bit code for the PicoRV32
CFLAGS  = -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -O2
LDFLAGS = -Wl,-Bstatic,-T,linker.lds,-strip-debug

SRCS_SW = start.S main.c

SRCS_HW = picorv32.v picorv32_top.v \
		  aes_192.v aes_top.v round.v table.v \
		  wbram.v \
		  wb_bus_b3.sv wb_decode.sv wb_interconnect_arb_rr.sv wb_mux.sv \
		  top.v tb_top.v

TCL_SCRIPT = compiledc.tcl

all: firmware.hex compile

firmware.elf: $(SRCS_SW)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@

firmware.hex: firmware.bin
	python3 -c "import binascii; data = open('firmware.bin','rb').read(); [print(binascii.hexlify(data[i:i+4][::-1]).decode()) for i in range(0, len(data), 4)]" > $@

compile: firmware.hex
	$(VCS) $(VCS_FLAGS) $(SRCS_HW) -o simv

sim: compile
	./simv

synthesis: clean 
	dc_shell -f compiledc.tcl

clean:
	rm -rf firmware.elf firmware.bin firmware.hex simv* alib-52/ simv*/ WORK/ csrc/ .cdsint ucli* default.svf .cdsinit cds.lib