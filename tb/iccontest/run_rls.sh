# Run this script in the sim/ic_contest/ directory
bsub -Ip vcs -R -full64 -debug_access \
    +define+PAT='"../../tb/iccontest/pattern1.dat"' \
    +define+EXP='"../../tb/iccontest/golden1.dat"' \
    ../../tb/iccontest/testfixture.v \
    ../../tb/iccontest/AXI_LBP_CDC.v \
    ../../rtl/CHIP.v \
    ../../rtl/CORE.v \
    ../../ip/rf136x16m4h3v2/rf136x16m4h3v2.v \
    -v /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/Verilog/tpz973gv.v \
    +notimingcheck