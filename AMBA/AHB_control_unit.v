// 将AHB总线默认直接融合到模块里面了

module AHB_control_unit (
    //----------AHB----------
    input iHCLK,
    input iHRESETn,

    output reg [31:0] oHADDR,
    output     [ 1:0] oHTRANS,
    output            oHWRITE,
    output     [ 2:0] oHSIZE,
    output     [ 2:0] oHBURST,  // burst, size, trans都没用到

    output reg [31:0] oHWDATA,

    input        iHREADY,
    input [31:0] iHRDATA,
    input [ 1:0] iHRESP    // 没用到
);

    //AHB Parameters
    parameter OKAY = 2'b00;
    parameter ERROR = 2'b01;
    parameter SPLIT = 2'b10;
    parameter RETRY = 2'b11;
    parameter IDLE = 2'b00;
    parameter BUSY = 2'b01;
    parameter SEQ = 2'b10;
    parameter NONSEQ = 2'b11;
    parameter BYTE = 3'b000;
    parameter WORD = 3'b001;
    parameter DWORD = 3'b010;
    parameter SINGLE = 3'b000;
    parameter INCR = 3'b001;
    parameter WRAP4 = 3'b010;
    parameter INCR4 = 3'b011;
    parameter WARP8 = 3'b100;
    parameter INCR8 = 3'b101;
    parameter WARP16 = 3'b110;
    parameter INCR16 = 3'b111;
    // Control Unit FSM Parameters
    parameter CONFIG_0 = 3'b000;
    parameter CONFIG_1 = 3'b001;
    parameter CONFIG_2 = 3'b010;
    parameter READ_DATA_RO = 3'b011;
    parameter WRITE_DATA_0 = 3'b100;
    parameter WRITE_DATA_1 = 3'b101;
    parameter WRITE_DATA_2 = 3'b110;
    parameter WRITE_DATA_3 = 3'b111;

    // LED_mode Parameters
    parameter MODE_BEGIN = 4'b0000;  // reset之后的全亮模式
    parameter MODE0 = 4'b0001;  // 普通流水灯模式
    parameter MODE1 = 4'b0010;  // 加速流水灯模式
    parameter MODE2 = 4'b0100;  // 心跳模式
    parameter MODE3 = 4'b1000;  // 呼吸灯模式

    // 按键状态, 按下是0
    parameter KEY_IDLE = 4'b1111, KEY_ON = 4'b0000, 
                KEY0_ON = 4'b1110, KEY1_ON = 4'b1101, 
                KEY2_ON = 4'b1011, KEY3_ON = 4'b0111;

    //Address Parameters
    // 外设的高位地址31:28
    parameter ADDR_SLAVE_0 = 4'b0000;
    parameter ADDR_SLAVE_1 = 4'b0001;
    // slave_0接GPIO,偏移地址如下
    parameter OFFSET_GPIO_DATA_RO = 4'h0;
    parameter OFFSET_GPIO_DATA = 4'h4;
    parameter OFFSET_GPIO_DIRM = 4'h8;
    parameter OFFSET_GPIO_OEN = 4'hC;


    // 定义led
    reg [3:0] led_mode;

    reg [2:0] state, next;

    always @(*) begin
        case (state)
            CONFIG_0: begin
                next = iHREADY ? CONFIG_1 : CONFIG_0;
            end
            CONFIG_1: begin
                next = iHREADY ? CONFIG_2 : CONFIG_1;
            end
            CONFIG_2: begin
                next = (iHREADY && iHRDATA[3:0] == KEY_ON) ? READ_DATA_RO : CONFIG_2;
            end
            READ_DATA_RO: begin     // 这里一定要注意, 按下按键的优先级高, 只有没按下按键才需要判断led_mode
                if(~iHREADY) begin
                    next = READ_DATA_RO;
                end else if (iHRDATA[3:0] == KEY0_ON) begin
                    next = WRITE_DATA_0;
                end else if (iHRDATA[3:0] == KEY1_ON) begin
                    next = WRITE_DATA_1;
                end else if (iHRDATA[3:0] == KEY2_ON) begin
                    next = WRITE_DATA_2;
                end else if (iHRDATA[3:0] == KEY3_ON) begin
                    next = WRITE_DATA_3;
                end else if(led_mode == MODE0) begin
                    next = WRITE_DATA_0;
                end else if(led_mode == MODE1) begin
                    next = WRITE_DATA_1;
                end else if(led_mode == MODE2) begin
                    next = WRITE_DATA_2;
                end else if(led_mode == MODE3) begin
                    next = WRITE_DATA_3;
                end
            end
            WRITE_DATA_0: begin
                next = iHREADY ? READ_DATA_RO : WRITE_DATA_0;
            end
            WRITE_DATA_1: begin
                next = iHREADY ? READ_DATA_RO : WRITE_DATA_1;
            end
            WRITE_DATA_2: begin
                next = iHREADY ? READ_DATA_RO : WRITE_DATA_2;
            end
            WRITE_DATA_3: begin
                next = iHREADY ? READ_DATA_RO : WRITE_DATA_3;
            end
            default: ;
        endcase
    end

    always @(posedge iHCLK) begin
        state <= (~iHRESETn) ? CONFIG_0 : next;
    end

    reg [3:0] LED;

    // 重要, led_mode转换
    always @(posedge iHCLK) begin
        if (~iHRESETn) begin
            led_mode <= MODE_BEGIN;
        end else begin
            case (next)
                CONFIG_0, CONFIG_1, CONFIG_2: begin
                    led_mode <= MODE_BEGIN;
                end
                READ_DATA_RO: begin
                    led_mode <= led_mode;
                end
                WRITE_DATA_0: begin
                    led_mode <= MODE0;
                end
                WRITE_DATA_1: begin
                    led_mode <= MODE1;
                end
                WRITE_DATA_2: begin
                    led_mode <= MODE2;
                end
                WRITE_DATA_3: begin
                    led_mode <= MODE3;
                end
                default: ;
            endcase
        end
    end

    /*————————————————————————————————————————————————————————————————————————*\
    /                                AHB Master Output                         \
    \*————————————————————————————————————————————————————————————————————————*/
    assign oHTRANS = NONSEQ;  // 这三个信号在这里没用
    assign oHBURST = SINGLE;
    assign oHSIZE  = DWORD;

    // 操作oHADDR 地址
    always @(*) begin
        case (state)
            CONFIG_0: oHADDR = 32'h0000_0008;  // DIRM寄存器
            CONFIG_1: oHADDR = 32'h0000_000C;  // DATA寄存器
            CONFIG_2: oHADDR = 32'h0000_0004;  // OEN寄存器
            READ_DATA_RO: oHADDR = 32'h0000_0004;
            WRITE_DATA_0, WRITE_DATA_1, WRITE_DATA_2, WRITE_DATA_3: begin
                oHADDR = 32'h0000_0004;  // OEN寄存器
            end
            default: ;
        endcase
    end

    assign oHWRITE = (state == READ_DATA_RO) ? 0 : 1;

    // 操作 oHWDATA 数据
    always @(*) begin
        case (state)
            CONFIG_0: oHWDATA = 32'h0000_00F0;  // DIRM寄存器
            CONFIG_1: oHWDATA = 32'h0000_00F0;  // DATA寄存器
            CONFIG_2: oHWDATA = 32'h0000_00F0;  // OEN寄存器
            READ_DATA_RO: oHWDATA = 32'h0000_0000;
            WRITE_DATA_0, WRITE_DATA_1, WRITE_DATA_2, WRITE_DATA_3: begin
                oHWDATA = {24'b0, ~LED[3:0], 4'b0000};
            end
            default: ;
        endcase
    end

    reg [31:0] timer;
    always @(posedge iHCLK or negedge iHRESETn) begin
        if (!iHRESETn) timer <= 32'd0;  // when the reset signal valid,time counter clearing
        else if (timer == 32'd199_999_999)  // 4 seconds count(50M*4-1=199999999)
            timer <= 32'd0;  // count done,clearing the time counter
        else timer <= timer + 1'b1;  // timer counter = timer counter + 1
    end

    //------------ led ------------ 
    always @(*) begin
        case (led_mode)
            MODE0: begin
                LED[3:0] = (timer >= 32'd149_999_999) ? 4'b0111 :  // LED4亮 
                (timer >= 32'd99_999_999) ? 4'b1011 :  // LED3亮
                (timer >= 32'd49_999_999) ? 4'b1101 :  // LED2亮
                4'b1110;  // LED1亮
            end
            MODE1: begin
                LED[3:0] = (timer >= 32'd174_999_999) ? 4'b0111 :  // LED4亮 
                (timer >= 32'd149_999_999) ? 4'b1011 :  // LED3亮
                (timer >= 32'd124_999_999) ? 4'b1101 :  // LED2亮
                (timer >= 32'd99_999_999) ? 4'b1110 :  // LED1亮
                (timer >= 32'd74_999_999) ? 4'b0111 :  // LED4亮  
                (timer >= 32'd49_999_999) ? 4'b1011 :  // LED3亮
                (timer >= 32'd24_999_999) ? 4'b1101 :  // LED2亮
                4'b1110;  // LED1亮
            end
            MODE2: begin
                LED[3:0] = (timer >= 32'd189_999_999) ? 4'b0000 :  // 全亮 
                (timer >= 32'd179_999_999) ? 4'b1111 :  // 全灭
                (timer >= 32'd169_999_999) ? 4'b0000 :  // 全亮
                4'b1111;  // 全灭
            end
            MODE3: begin
                LED[3:0] = (timer >= 32'd189_999_999) ? 4'b1111 :  // 0%
                ((timer >= 32'd169_999_999) && (timer[5:0] == 6'b000)) ? 4'b0000 :  // 1.56%  
                (timer >= 32'd169_999_999) ? 4'b1111 :  // 1.56%   1 / 64
                ((timer >= 32'd149_999_999) && (timer[4:0] == 5'b000)) ? 4'b0000 :  // 3.12%
                (timer >= 32'd149_999_999) ? 4'b1111 :  // 3.12%
                ((timer >= 32'd129_999_999) && (timer[3:0] == 4'b000)) ? 4'b0000 :  // 6.25%
                (timer >= 32'd129_999_999) ? 4'b1111 :  // 6.25%
                ((timer >= 32'd109_999_999) && (timer[2:0] == 3'b000)) ? 4'b0000 :  // 12.5%
                (timer >= 32'd109_999_999) ? 4'b1111 :  // 12.5%
                ((timer >= 32'd89_999_999) && (timer[1:0] == 2'b00)) ? 4'b0000 :  // 25%
                (timer >= 32'd89_999_999) ? 4'b1111 :  // 25%
                ((timer >= 32'd69_999_999) && (timer[2:0] == 3'b000)) ? 4'b0000 :  // 12.5%
                (timer >= 32'd69_999_999) ? 4'b1111 :  // 12.5%
                ((timer >= 32'd49_999_999) && (timer[3:0] == 4'b000)) ? 4'b0000 :  // 6.25%
                (timer >= 32'd49_999_999) ? 4'b1111 : 
                ((timer >= 32'd29_999_999) && (timer[4:0] == 5'b000)) ? 4'b0000 :  // 3.12%
                (timer >= 32'd29_999_999) ? 4'b1111 :  // 3.12%
                ((timer >= 32'd9_999_999) && (timer[5:0] == 6'b000)) ? 4'b0000 :  // 1.56%
                (timer >= 32'd9_999_999) ? 4'b1111 :  // 1.56%
                4'b1111;  // 0%
            end
            default: ;
        endcase
    end




endmodule
