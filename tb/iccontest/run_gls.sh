# Run this script in the sim/ic_contest/ directory
bsub -Ip vcs -R -full64 -debug_access -negdelay -sdfretain -diag=sdf:verbose \
    -debug_region+cell+encrypt \
    ../../ip/rf136x16m4h3v2/rf136x16m4h3v2.v \
    -v /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/Verilog/tpz973gv.v \
    -v /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/Verilog/tsmc18_neg.v \
    +sdfverbose +maxdelays \
    +define+PAT='"../../tb/iccontest/pattern1.dat"' \
    +define+EXP='"../../tb/iccontest/golden1.dat"' \
    +define+SDFFILE='"../../syn/out/CHIP_syn.sdf"' \
    ../../tb/iccontest/testfixture.v \
    ../../tb/iccontest/AXI_LBP_CDC.v \
    ../../syn/out/CHIP_syn.v \
    +define+SDF +neg_tchk