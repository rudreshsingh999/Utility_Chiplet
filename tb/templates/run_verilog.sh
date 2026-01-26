# Replace the 'testbench_name' with the original name you want to work with

verilator -Wno-UNOPTFLAT testbench_name.v --top testbench_name --trace --timing --binary -j 4

make -C obj_dir -f Vtestbench_name.mk Vtestbench_name

./obj_dir/Vtestbench_name

rm -rf ./obj_dir