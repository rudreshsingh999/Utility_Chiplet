# Replace 'module' and 'testbench' with your file names

verilator -Wno-WIDTHEXPAND --trace -cc module.v --exe testbench.cpp

make -C obj_dir -f Vmodule.mk Vmodule

./obj_dir/Vmodule