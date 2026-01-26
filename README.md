>>>>>>> c314922 (Initial commit)
# Utility-Chiplet

**University of California, Irvine – University of California, Los Angeles**

This repository contains RTL designs, synthesis scripts, and testbench files/scripts for the utility chiplets (UCs) of the Network-on-Interconnect Fabric (NoIF) project.

## Setup Environment
Please read the comments in `setup.sh` and make sure everything is compatible with you system before installation. Specifically, make sure directories and roots are set correctly and aligned with your system. Some commands may need modification, based on your system being `bash` or `csh`. 

Simply run the `setup.sh` from your terminal, and it will automatically install all required prerequisites:
 
```shell
git clone https://github.com/THInK-Team/Utility-Chiplet.git
cd setup
chmod +x setup.sh
./setup.sh
```

## Functional Simulations

### Makefile

To simulate the design sources efficiently, place all RTL source files in the `rtl` directory. Then, in the `tb` directory, create a subdirectory with the same name as the top module (*e.g.*, `module_name`) and name the testbench `module_name_tb`.

Examples:
- RTL: `rtl/module_name.v`
- Verilog TB: `tb/module_name/module_name_tb.v`
- C++ TB: `tb/module_name/module_name_tb.cpp`

By following these naming and directory conventions, the provided `Makefile` can be used to simulate the design using different workflows.

To run a simulation using [**Icarus Verilog**](https://github.com/steveicarus/iverilog):

```shell
make sim=iverilog module=module_name
```

To run a simulation using [**Verilator**](https://github.com/verilator/verilator) with a C++ test environemnt:

```shell
make sim=verilator module=module_name src=cpp
```

To run a simulation using [**Verilator**](https://github.com/verilator/verilator) with a Verilog testbench:

```shell
make sim=verilator module=module_name src=verilog
```

### Icarus Verilog
To run simulations using [**Icarus Verilog**](https://github.com/steveicarus/iverilog), execute the following commands:

```shell
iverilog -o tb/module_name/sim_file_name.vvp -Irtl tb/module_name/testbench_file_name.v
vvp tb/module_name/sim_file_name.vvp
```

### Verilator
To run simulations using [**Verilator**](https://github.com/verilator/verilator), execute the following commands after modifying the directory paths and options in the shell scripts provided in `main/tb/templates`:

```shell
# change file permissions:
chmod +x run_cpp.sh     # verilator with c++ test environment
chmod +x run_verilog.sh # verilator with verilog test environment
# execute shell scripts:
./run_cpp.sh            # verilator with c++ test environment
./run_verilog.sh        # verilator with verilog test environment
```

The shell script structure with **Verilog testbench** is as follows:

```shell
# Replace 'testbench_name' with your file names
verilator -Wno-UNOPTFLAT testbench_name.v --top testbench_name --trace --timing --binary -j 4
make -C obj_dir -f Vtestbench_name.mk Vtestbench_name
./obj_dir/Vtestbench_name
rm -rf ./obj_dir
```

> [!NOTE]
> The provided shell script is intended for direct simulation of a Verilog testbench. It is strongly recommended to use a C++ test environment for Verilator-based simulations.

> [!NOTE]
> Ensure that all designs are compatible with both simulation flows and are fully synthesizable.

The shell script structure with **C++ test environment** is as follows:

```shell
# Replace 'module' and 'testbench' with your file names
verilator -Wno-WIDTHEXPAND --trace -cc module.v --exe testbench.cpp
make -C obj_dir -f Vmodule.mk Vmodule
./obj_dir/Vmodule
```

If a VCD file is generated for waveform dumping, it can be viewed using [**GTKWave**](https://github.com/gtkwave/gtkwave):

```shell
gtkwave waveform_file.vcd
```

## Synthesis Flow

Based on the available systhesis tools on your machine, follow one of the given flows.

### Synopsys Design Compiler (DC)

To execute the synthesis script, run the following command:

```shell
dc_shell-t -f synthesis_dc.tcl
```

Ensure that the directory paths for libraries and design sources are correctly specified. Please read the comments in the synthesis script and make sure right commands are used with respect to your design. 

### Cadence Genus

You can start Genus using the command below:

```shell
genus
# It is recommended to work with the legacy mode of the tool for 
# better command compatibility, using the following command instead:
genus -legacy_ui
```

Once started the Genus environment, source the setup file (`setup.g`) and the `tcl` script to run the synthesis flow:

```bash
@genus:root: > source setup.g
@genus:root: > source synthesis_genus.tcl
```

> [!NOTE]
> All libraries, HDL sources, module names, constraint files, etc., and the directories must be modified in the `setup.g` file, prior to running the synthesis script.

You can also execute a single `tcl` file (including full setup configurations) directly, using this command:

```shell
genus -f synthesis_genus.tcl
```

Ensure that the directory paths for libraries and design sources are correctly specified. Please read the comments in the synthesis script and make sure right commands are used with respect to your design. 

## Contribution Guidelines

All contributors must follow the workflow below to ensure correctness and maintainability:

1. **Create a dedicated branch**  
   Each contributor must create a separate branch for their work. Development directly on the `main` branch is not permitted. 

2. **Independent module development and verification**  
   - Implement and verify each module independently.  
   - Provide a self-contained testbench for the module.  
   - Ensure that all functional simulations pass (Icarus Verilog and/or Verilator, as applicable).

3. **Design requirements**  
   Before requesting a merge, the design must:
   - Pass all automated workflows and checks.
   - Be fully synthesizable. 
   - Contain no simulation-only constructs in the RTL. 

4. **Repository cleanup** 
   Prior to opening a merge request:
   - Remove (don't commit) temporary files, generated artifacts, and build directories.
   - Organize RTL files and testbenches into their appropriate directories.

5. **Merge request**  
   Once all criteria are satisfied, open a merge request targeting the `main` branch.  
   The merge request should clearly describe the implemented module, verification status, and synthesis readiness.
<<<<<<< HEAD

