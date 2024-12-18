module APB_GPIO #(

    //ADDR Parameters
    parameter ADDR_GPIO           = 32'h0000_0000,
    parameter OFFSET_GPIO_DATA_RO = 4'h0,
    parameter OFFSET_GPIO_DATA    = 4'h4,
    parameter OFFSET_GPIO_DIRM    = 4'h8,
    parameter OFFSET_GPIO_OEN     = 4'hC

) (
    // APB Signal  from APB bridge
    input         iPCLK,
    input         iPRESETn,
    input         iPSEL,        // 这个信号根本没用到
    input         iPWRITE,
    input         iPENABLE,     // 使能信号, 标记传输使能
    input  [31:0] iPADDR,
    input  [31:0] iPWDATA,
    output [31:0] oPRDATA,
    // output oPREADY,          // 写数据时,表示salve是否已经将数据写入; 读数据时,表示slave是否已经发送数据

    // I/O Signal  分别使用iGPIOin和oGPIOout避免双向引脚, inout类型不太懂
    input      [31:0] iGPIOin,
    output reg [31:0] oGPIOout

);

    /*————————————————————————————————————————————————————————————————————————*\
    /                            APB Signal Register                           \
    \*————————————————————————————————————————————————————————————————————————*/
    reg        iPWRITE_r;
    reg [31:0] iPADDR_r;
    reg [31:0] iPWDATA_r;

    always @(posedge iPCLK) begin
        if (!iPRESETn) begin
            iPWRITE_r <= 1'b0;
            iPADDR_r  <= 16'b0;
        end else begin
            iPWRITE_r <= iPWRITE;
            iPWDATA_r <= iPWDATA;
            iPADDR_r  <= iPADDR;
        end
    end

    /*————————————————————————————————————————————————————————————————————————*\
    /                           GPIO Register Declaration                      \
    \*————————————————————————————————————————————————————————————————————————*/
    // Read Only Data 用来观测GPIO引脚状态(输入输出都有)，若引脚被配置成输出模式，则该寄存器会反映驱动该引脚的电平的状态。
    reg     [31:0] reg_DATA_RO;
    // GPIO Data 当GPIO某一引脚被配置为输出模式时，用来控制该引脚的输出状态
    reg     [31:0] reg_DATA;
    // Direction (in or out) 用来配置GPIO各个引脚的方向（做输入or做输出），当DIRMP[x]==0，第x位引脚为输入引脚，其输出功能被disable
    reg     [31:0] reg_DIRM;
    // Output Enable 当GPIO某一引脚被配置为输出模式时，用来使能该引脚的输出功能，当OEN[x]==0时，第x位引脚的输出功能被disable
    reg     [31:0] reg_OEN;

    /*————————————————————————————————————————————————————————————————————————*\
    /                              Register Configuration                      \
    \*————————————————————————————————————————————————————————————————————————*/
    integer        i;

    always @(posedge iPCLK) begin
        if (!iPRESETn) begin
            reg_DATA_RO <= 32'b0;
            reg_DATA    <= 32'b0;
            reg_DIRM    <= 32'b0;
            reg_OEN     <= 32'b0;
        end else begin

            // reg_DATA, reg_DIRM, reg_OEN
            if (iPENABLE && iPWRITE) begin
                case (iPADDR[3:0])
                    OFFSET_GPIO_DATA_RO: begin
                    end  //DATA_RO is read only register             
                    OFFSET_GPIO_DATA: begin // 控制输出引脚的电平 7:4
                        reg_DATA <= iPWDATA;
                    end
                    OFFSET_GPIO_DIRM: begin
                        reg_DIRM <= iPWDATA; // 控制引脚方向 7:4 为输出(1), 3:0 为输入(0)
                    end
                    OFFSET_GPIO_OEN: begin  // 控制输出引脚的使能 7:4
                        reg_OEN <= iPWDATA;
                    end
                    default: begin
                        reg_DATA <= reg_DATA;
                        reg_DIRM <= reg_DIRM;
                        reg_OEN  <= reg_OEN;
                    end
                endcase
            end

            /*  如果该引脚为输出方向, 就存放输出的数据, 否则存放输入的数据
            */
            for (i = 0; i < 32; i = i + 1) begin
                if (reg_DIRM[i]) begin 
                    reg_DATA_RO[i] <= oGPIOout[i];  // output mode
                end else begin          
                    reg_DATA_RO[i] <= iGPIOin[i];  // input mode      
                end
            end
        end
    end

    /*————————————————————————————————————————————————————————————————————————*\
    /                                     I/O                                  \
    \*————————————————————————————————————————————————————————————————————————*/
    // iGPIOin -> GPIOin_r -> DATA_RO -> PRADATA
    assign oPRDATA = reg_DATA_RO;

    always @(*) begin
        for (i = 0; i < 32; i = i + 1) begin
            if (reg_DIRM[i] & reg_OEN[i]) begin  //output mode
                oGPIOout[i] = reg_DATA[i];
            end else begin
                oGPIOout[i] = 1'bz;
            end
        end
    end

endmodule
