(globals
    version = 4
    io_order = clockwise
)

(iopad
    (topleft
        (inst name="Corner1" place_status=fixed orientation=R270 cell=PCORNER)
    )

    (top
        (inst name="ipad_s_data7" place_status=fixed)
        (inst name="ipad_s_data6" place_status=fixed)
        (inst name="ipad_s_data5" place_status=fixed)

        (inst name="CORE_VSS1"    place_status=fixed cell=PVSS1DGZ)
        (inst name="CORE_VDD1"    place_status=fixed cell=PVDD1DGZ)

        (inst name="ipad_s_data4" place_status=fixed)
        (inst name="ipad_s_data3" place_status=fixed)

        (inst name="IO_VDD1"      place_status=fixed cell=PVDD2DGZ)
        (inst name="opad_m_data7" place_status=fixed)
        (inst name="opad_m_data6" place_status=fixed)
    )

    (topright
        (inst name="Corner2" place_status=fixed orientation=R180 cell=PCORNER)
    )

    (right
        (inst name="IO_VSS1"      place_status=fixed cell=PVSS2DGZ)
        (inst name="opad_m_data5" place_status=fixed)
        (inst name="opad_m_data4" place_status=fixed)
        (inst name="IO_VDD2"      place_status=fixed cell=PVDD2DGZ)
        (inst name="opad_m_data3" place_status=fixed)
        (inst name="IO_VSS2"      place_status=fixed cell=PVSS2DGZ)
        (inst name="opad_m_data2" place_status=fixed)
        (inst name="opad_m_data1" place_status=fixed)
        (inst name="opad_m_data0" place_status=fixed)
        (inst name="opad_m_last"  place_status=fixed)
    )

    (bottomright
        (inst name="Corner3" place_status=fixed orientation=R90 cell=PCORNER)
    )

    (bottom
        (inst name="ipad_m_ready" place_status=fixed)
        (inst name="opad_m_valid" place_status=fixed)
        (inst name="IO_VDD3"      place_status=fixed cell=PVDD2DGZ)
        (inst name="IO_VSS3"      place_status=fixed cell=PVSS2DGZ)

        (inst name="CORE_VDD2"    place_status=fixed cell=PVDD1DGZ)
        (inst name="CORE_VSS2"    place_status=fixed cell=PVSS1DGZ)

        (inst name="ipad_s_last"  place_status=fixed)
        (inst name="ipad_s_data2" place_status=fixed)
        (inst name="ipad_s_data1" place_status=fixed)
        (inst name="ipad_s_data0" place_status=fixed)
    )

    (bottomleft
        (inst name="Corner4" place_status=fixed orientation=R0 cell=PCORNER)
    )

    (left
        (inst name="ipad_s_valid" place_status=fixed)
        (inst name="opad_s_ready" place_status=fixed)
        (inst name="IO_VDD4"      place_status=fixed cell=PVDD2DGZ)
        (inst name="IO_POC"       place_status=fixed cell=PVDD2POC)

        (inst name="ipad_cresetn" place_status=fixed)
        (inst name="ipad_cclk"    place_status=fixed)
        (inst name="IO_VSS4"      place_status=fixed cell=PVSS2DGZ)
        (inst name="IO_VSS5"      place_status=fixed cell=PVSS2DGZ)
        (inst name="ipad_aclk"    place_status=fixed)
        (inst name="ipad_aresetn" place_status=fixed)
    )
)
