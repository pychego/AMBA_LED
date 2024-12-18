module SoC_top (
    input        HCLK,
    input        HRESETn,
    input  [3:0] FPGA_Key,
    output [3:0] FPGA_LED
);

    wire        bridge_HREADY_o;
    wire [ 1:0] bridge_HRESP_o;
    wire [31:0] bridge_HRDATA_o;

    wire [ 1:0] cu_HTRANS_o;
    wire [ 2:0] cu_HSIZE_o;
    wire [ 2:0] cu_HBURST_o;
    wire        cu_HWRITE_o;
    wire [31:0] cu_HADDR_o;
    wire [31:0] cu_HWDATA_o;

    wire [31:0] gpio_PRDATA_o;
    wire        brige_PSEL0_o;
    wire        brige_PSEL1_o;
    wire        brige_PWRITE_o;
    wire        brige_PENABLE_o;
    wire [31:0] brige_PADDR_o;
    wire [31:0] brige_PWDATA_o;

    wire        gpio_PREADY_o;

    wire [23:0] dont_care_gpio_output24;
    wire [ 3:0] dont_care_gpio_output4;



    AHB_control_unit u_AHB_control_unit (
        .iHCLK   (HCLK),
        .iHRESETn(HRESETn),
        .iHREADY (bridge_HREADY_o),
        .iHRESP  (bridge_HRESP_o),
        .iHRDATA (bridge_HRDATA_o),
        .oHTRANS (cu_HTRANS_o),
        .oHSIZE  (cu_HSIZE_o),
        .oHBURST (cu_HBURST_o),
        .oHWRITE (cu_HWRITE_o),
        .oHADDR  (cu_HADDR_o),
        .oHWDATA (cu_HWDATA_o)
    );


    AHB2APB_bridge u_AHB2APB_bridge (
        // -----------------AHB---------------
        .iHCLK   (HCLK),
        .iHRESETn(HRESETn),
        .iHSEL   (1),
        .iHTRANS (cu_HTRANS_o),
        .iHSIZE  (cu_HSIZE_o),
        .iHBURST (cu_HBURST_o),
        .iHWRITE (cu_HWRITE_o),
        .iHWDATA (cu_HWDATA_o),
        .iHADDR  (cu_HADDR_o),
        .oHREADY (bridge_HREADY_o),
        .oHRESP  (bridge_HRESP_o),
        .oHRDATA (bridge_HRDATA_o),
        //-------------APB-------------
        .iPRDATA (gpio_PRDATA_o),
        .iPREADY (gpio_PREADY_o),
        .oPSEL0  (brige_PSEL0_o),
        .oPSEL1  (brige_PSEL1_o),
        .oPWRITE (brige_PWRITE_o),
        .oPENABLE(brige_PENABLE_o),
        .oPADDR  (brige_PADDR_o),
        .oPWDATA (brige_PWDATA_o)
    );

    APB_GPIO u_APB_GPIO (
        .iPCLK   (HCLK),
        .iPRESETn(HRESETn),
        .iPSEL   (brige_PSEL0_o),
        .iPWRITE (brige_PWRITE_o),
        .iPENABLE(brige_PENABLE_o),
        .iPADDR  (brige_PADDR_o),
        .iPWDATA (brige_PWDATA_o),
        .oPRDATA (gpio_PRDATA_o),
        .oPREADY (gpio_PREADY_o),
        .GPIO_in ({{28{1'b0}}, FPGA_Key}),
        .GPIO_out({dont_care_gpio_output24, FPGA_LED, dont_care_gpio_output4})
    );

endmodule
