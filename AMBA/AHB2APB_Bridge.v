module AHB2APB_bridge (

    // -------- AHB --------
    input             iHCLK,
    input             iHRESETn,
    input             iHSEL,     // 默认一直选中
    // 地址信号(第一拍)
    input      [31:0] iHADDR,
    // 控制信号 iHTRANS, iHSIZE, iHBURST没用到
    input      [ 1:0] iHTRANS,
    input             iHWRITE,
    input      [ 2:0] iHSIZE,
    input      [ 2:0] iHBURST,
    // 数据信号(第二拍)
    input      [31:0] iHWDATA,
    // 输出给master的响应信号
    output reg        oHREADY,
    output     [31:0] oHRDATA,
    output     [ 1:0] oHRESP,

    //  ---------- APB ---------
    output reg [31:0] oPADDR,
    output reg        oPSEL0,    // 接GPIO的iPSEL
    output reg        oPSEL1,
    output reg        oPENABLE,  // 标记传输使能
    output reg        oPWRITE,
    output reg [31:0] oPWDATA,

    input        iPREADY,  // slave 准备好进行下一次的读写了
    input [31:0] iPRDATA
);

    //HRANS Parameters
    parameter IDLE = 2'b00;
    parameter BUSY = 2'b01;
    parameter SEQ = 2'b10;
    parameter NONSEQ = 2'b11;

    //HRSP Parameters
    parameter OKAY = 2'b00;
    parameter ERROR = 2'b01;
    parameter SPLIT = 2'b10;
    parameter RETRY = 2'b11;

    //bridge_state Parameters
    parameter BRIDGE_IDLE = 2'b00;
    parameter BRIDGE_SETUP = 2'b01;
    parameter BRIDGE_ACCESS = 2'b10;

    // 仿照tinyriscv挂外设, 暂时挂两个外设
    parameter ADDR_SLAVE_0 = 4'b0000;
    parameter ADDR_SLAVE_1 = 4'b0001;

    reg [1:0] state, next_state;


    // ------------------ bridge状态机 ------------------------
    always @(*) begin
        case (state)
            BRIDGE_IDLE: begin
                next_state = iHSEL ? BRIDGE_SETUP : BRIDGE_IDLE;
            end
            BRIDGE_SETUP: begin
                next_state = BRIDGE_ACCESS;
            end
            BRIDGE_ACCESS: begin
                next_state = iPREADY ? (iHSEL ? BRIDGE_SETUP : BRIDGE_IDLE) : BRIDGE_ACCESS;
            end
            default: ;
        endcase
    end

    // 状态更新
    always @(posedge iHCLK) begin
        state <= iHRESETn ? next_state : BRIDGE_IDLE;
    end

    // 根据状态机操作输出变量
    always @(posedge iHCLK) begin
        if (!iHRESETn) begin
            oHREADY  <= 0;
            oPSEL0   <= 0;
            oPSEL1   <= 0;
            oPENABLE <= 0;
            oPADDR   <= 0;
            oPWRITE  <= 0;
            oPWDATA  <= 0;
        end else begin
            case (next_state)
                BRIDGE_SETUP: begin
                    oHREADY  <= 0;
                    oPSEL0   <= (iHADDR[31:28] == ADDR_SLAVE_0) ? 1 : 0;
                    oPSEL1   <= (iHADDR[31:28] == ADDR_SLAVE_1) ? 1 : 0;
                    oPENABLE <= 0;
                    oPADDR   <= iHADDR;
                    oPWRITE  <= iHWRITE;
                    oPWDATA  <= iHWDATA;
                end
                BRIDGE_ACCESS: begin
                    oHREADY  <= 1;
                    oPSEL0   <= oPSEL0;
                    oPSEL1   <= oPSEL1;
                    oPENABLE <= 1;
                    oPADDR   <= oPADDR;
                    oPWRITE  <= oPWRITE;
                    oPWDATA  <= oPWDATA;
                end
                default: begin
                    oHREADY  <= 0;
                    oPSEL0   <= 0;
                    oPSEL1   <= 0;
                    oPENABLE <= 0;
                    oPADDR   <= 0;
                    oPWRITE  <= 0;
                    oPWDATA  <= 0;
                end
            endcase
        end
    end

    assign oHRDATA = iPRDATA;
    assign oHRESP  = OKAY;


endmodule
