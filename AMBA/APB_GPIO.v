module APB_GPIO (
    // ------------ APB slave ---------
    input        iPCLK,
    input        iPRESETn,
    input [31:0] iPADDR,
    input        iPSEL,
    input        iPENABLE,
    input        iPWRITE,
    input [31:0] iPWDATA,

    output        oPREADY,
    output [31:0] oPRDATA,

    // 约束引脚 7:4 输出led  3:0 输入key
    input  [31:0] GPIO_in,
    output [31:0] GPIO_out
);

    // 外设的高位地址31:28
    parameter ADDR_SLAVE_0 = 4'b0000;
    parameter ADDR_SLAVE_1 = 4'b0001;
    // slave_0接GPIO,偏移地址如下
    parameter OFFSET_GPIO_DATA_RO = 4'h0;
    parameter OFFSET_GPIO_DATA = 4'h4;
    parameter OFFSET_GPIO_DIRM = 4'h8;
    parameter OFFSET_GPIO_OEN = 4'hC;


    // 这里GPIO接口定义分开input和output只是为了避免使用inout,实际物理接口只有32个
    /* 定义GPIO内部寄存器
        reg_DATA_RO: 只读存储器,存放32个GPIO引脚的电平状态(输入输出都有)
        reg_DATA: 当引脚为输出模式时, 控制引脚的输出电压
        reg_DIRM: 设置引脚的输入输出方向,1为输出,0为输入
        reg_OEN: 控制输出引脚的使能, 为1输出引脚使能
    */
    reg [31:0] reg_DATA_RO;
    reg [31:0] reg_DATA;
    reg [31:0] reg_DIRM;
    reg [31:0] reg_OEN;

    // 将读和写分开写, 这个先写
    always @(posedge iPCLK) begin
        if (~iPRESETn) begin
            reg_DATA <= 0;
            reg_DIRM <= 0;
            reg_OEN  <= 0;
        end else begin
            if (iPSEL && iPENABLE && iPWRITE)  // 此时已经是access要结束的clk了
                case (iPADDR[3:0])
                    OFFSET_GPIO_DATA_RO: begin
                        // reg_DATA_RO, 只读reg, 不操作
                    end
                    OFFSET_GPIO_DATA: begin
                        reg_DATA <= iPWDATA;
                    end
                    OFFSET_GPIO_DIRM: begin
                        reg_DIRM <= iPWDATA;
                    end
                    OFFSET_GPIO_OEN: begin
                        reg_OEN <= iPWDATA;
                    end
                    default: ;
                endcase
        end
    end

    // 存放GPIO的电平状态
    integer i;
    always @(*) begin
        for (i = 0; i < 32; i = i + 1) begin
            if (reg_DIRM[i]) begin
                reg_DATA_RO[i] = GPIO_out[i];
            end else begin
                reg_DATA_RO[i] = GPIO_in[i];
            end
        end
    end

    // 根据寄存器数据设置输出电平
    generate
        genvar j;
        for (j = 0; j < 32; j = j + 1) begin
            assign GPIO_out[j] = (reg_DIRM[j] && reg_OEN[j]) ? reg_DATA[j] : 1'bz;
        end
    endgenerate

    assign oPRDATA = reg_DATA_RO;
    assign oPREADY = 1;


endmodule
