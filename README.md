# Fuzzing

# Satellite Fuzzer

Run the Makefile, which usesthe  VCS simulator

# Compile and run VCS simulation inside sim/
# Default target

make all

# Clean the simulation directory
make clean

# common_types.sv
typedef a structure package for a random fuzzer

# Block diagram of top_module.sv
The top module consists of a **Satellite fuzzer**(Satellite_fuzzer_wb.sv) and **Wishbone bus** (wishbone_dual.sv) interface, which will be used to communicate with  the Central Fuzzer

![image](https://github.com/user-attachments/assets/d50569b4-c65c-47c7-87ff-825a850f2e88)
