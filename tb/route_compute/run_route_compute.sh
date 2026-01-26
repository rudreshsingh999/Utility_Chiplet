verilator -Wno-WIDTHEXPAND --trace -cc route_compute.v --exe route_compute_tb.cpp

make -C obj_dir -f Vroute_compute.mk Vroute_compute

./obj_dir/Vroute_compute
