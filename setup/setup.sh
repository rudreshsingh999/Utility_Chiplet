# System requirements
sudo apt-get install git -y
sudo apt-get install autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev git libexpat1-dev gtkwave -y

sudo apt-get install help2man perl python3 make
sudo apt-get install g++                        # Alternatively, clang
sudo apt-get install libgz                      # Non-Ubuntu (ignore if gives error)
sudo apt-get install libfl2                     # Ubuntu only (ignore if gives error)
sudo apt-get install libfl-dev                  # Ubuntu only (ignore if gives error)
sudo apt-get install zlibc zlib1g zlib1g-dev    # Ubuntu only (ignore if gives error)

sudo apt-get install libsystemc libsystemc-dev  # SystemC

# sudo apt-get install z3                                 # Optional solver
# sudo apt-get install perl-doc                           # Optional
# sudo apt-get install ccache                             # Optional: if present at build, needed for run
# sudo apt-get install mold                               # Optional: of present at build, needed for run
# sudo apt-get install libgoogle-perftools-dev numactl    # Optional

sudo apt-get install git autoconf flex bison            # Mandatory for installing Verilator

cd
pwd=$PWD

# Installing Icarus Verilog
git clone https://github.com/steveicarus/iverilog.git
cd iverilog/
git checkout --track -b v12-branch origin/v12-branch
git pull 
chmod +x autoconf.sh 
./autoconf.sh 
./configure 
make 
sudo make install 

cd $pwd # Back to top directory

# Installing Verilator
git clone https://github.com/verilator/verilator 
unset VERILATOR_ROOT        # For bash
cd verilator
git pull                    # Make sure you are up-to-date
git tag                     # See what versions exist
#git checkout master        # Use development branch (e.g. recent bug fix)
#git checkout stable        # Use most recent release
#git checkout v{version}    # Switch to specified release version

autoconf                    # Create ./configure script
./configure                 # Configure and create Makefile
make -j `nproc`             # Build Verilator itself (if error, try just 'make')
make test
make install
