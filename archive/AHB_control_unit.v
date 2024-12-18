module AHB_control_unit #(
    //AHB Parameters
    parameter OKAY         = 2'b00,
    parameter ERROR        = 2'b01,
    parameter SPLIT        = 2'b10,
    parameter RETRY        = 2'b11,
    parameter IDLE         = 2'b00,
    parameter BUSY         = 2'b01,
    parameter SEQ          = 2'b10,
    parameter NONSEQ       = 2'b11,
    parameter BYTE         = 3'b000,
    parameter WORD         = 3'b001,
    parameter DWORD        = 3'b010,
    parameter SINGLE       = 3'b000,
    parameter INCR         = 3'b001,
    parameter WRAP4        = 3'b010,
    parameter INCR4        = 3'b011,
    parameter WARP8        = 3'b100,
    parameter INCR8        = 3'b101,
    parameter WARP16       = 3'b110,
    parameter INCR16       = 3'b111,
    // Control Unit FSM Parameters
    parameter CONFIG_0     = 3'b000,
    parameter CONFIG_1     = 3'b001,
    parameter CONFIG_2     = 3'b010,
    parameter READ_DATA_RO = 3'b011,
    parameter WRITE_DATA_0 = 3'b100,
    parameter WRITE_DATA_1 = 3'b101,
    parameter WRITE_DATA_2 = 3'b110,
    parameter WRITE_DATA_3 = 3'b111,

    // LED_mode Parameters
    parameter MODE_BEGIN = 4'b0000,
    parameter MODE0 = 4'b0001,  // 普通流水灯模式
    parameter MODE1 = 4'b0010,  // 加速流水灯模式
    parameter MODE2 = 4'b0100,  // 心跳模式
    parameter MODE3 = 4'b1000,  // 呼吸灯模式

    //Address Parameters
    parameter ADDR_GPIO           = 32'h0000_0000,
    parameter OFFSET_GPIO_DATA_RO = 32'h0000_0000,
    parameter OFFSET_GPIO_DATA    = 32'h0000_0004,
    parameter OFFSET_GPIO_DIRM    = 32'h0000_0008,
    parameter OFFSET_GPIO_OEN     = 32'h0000_000C

) (
    // Input from AHB Bus
    input iHCLK,
    input iHRESETn,
    input iHREADY,          // 这三个由AHB2APB_bridge输出提供
    input [1:0] iHRESP,
    input [31:0] iHRDATA,   // 实时来自GPIO中的reg_DATA_RO寄存器, 实时读取GPIO输入电平(3:0)

    // Output to AHB Bus
    output     [ 1:0] oHTRANS,  // 这三个信号没用
    output     [ 2:0] oHSIZE,
    output     [ 2:0] oHBURST,
    output            oHWRITE,
    output reg [31:0] oHADDR,
    output reg [31:0] oHWDATA

);
    reg [3 : 0] led_mode;  //4 modes in all (one hot encoding)
    reg [3 : 0] LED;
    /*————————————————————————————————————————————————————————————————————————*\
    /                           Control Unit FSM                               \
    \*————————————————————————————————————————————————————————————————————————*/
    /* CONFIG_0~2: 按下复位按钮/上电后，对GPIO外设进行初始化配置
        CONFIG_0: 将GPIO的0~3位引脚配置为输入模式，连接FPGA开发板的Key按键进行观测
                  将GPIO的4~7位引脚配置为输出模式，连接FPGA开发板的LED灯进行驱动控制
        CONFIG_1: 将GPIO的4~7位引脚的输出电平均设定为高电平1,使用的小梅哥7010开发板,LED灯为高电平点亮
        CONFIG_2: 对GPIO的4~7位引脚进行输出使能
       READ_DATA_RO: 读GPIO的DATA_RO寄存器，根据[3:0]的值得知Key状态,并根据Key状态切换LED模式
       WRITE_DATA_0~3: 配置不同的流水灯灯工作模式，模式由KEY状态决定，按下KEY1进入工作模式0，
                       按下KEY2进入工作模式1，按下KEY3进入工作模式2，按下KEY4进入工作模式3，
                       在初始静止状态下，只有同时按下KEY0~3才能进入工作模式0，
                       此时按下某个单独的KEY不会有任何反应的
    */

    reg [  2:0] CU_state;

    always @(posedge iHCLK) begin
        if (!iHRESETn) begin
            CU_state <= CONFIG_0;
        end else begin
            case (CU_state)
                // write GPIO_DIRM 
                CONFIG_0: begin
                    if (iHREADY) begin
                        CU_state <= CONFIG_1;
                    end else begin
                        CU_state <= CONFIG_0;
                    end
                end
                // write GPIO_DATA
                CONFIG_1: begin
                    if (iHREADY) begin
                        CU_state <= CONFIG_2;
                    end else begin
                        CU_state <= CONFIG_1;
                    end
                end
                // write GPIO_OEN 
                CONFIG_2: begin  // 如果四个key同时按下
                    if (iHREADY && iHRDATA[3:0] == 4'b0000) begin
                        CU_state <= READ_DATA_RO;
                    end else begin
                        CU_state <= CONFIG_2;
                    end
                end
                // read DATA_RO  进入正常工作状态
                READ_DATA_RO: begin
                    if (iHREADY && iHRDATA[3:0] == 4'b1110) begin  //key1 pressed
                        CU_state <= WRITE_DATA_0;
                    end else if (iHREADY && iHRDATA[3:0] == 4'b1101) begin  //key2 pressed
                        CU_state <= WRITE_DATA_1;
                    end else if (iHREADY && iHRDATA[3:0] == 4'b1011) begin  //key3 pressed
                        CU_state <= WRITE_DATA_2;
                    end else if (iHREADY && iHRDATA[3:0] == 4'b0111) begin  //key4 pressed
                        CU_state <= WRITE_DATA_3;
                    end else if ( iHREADY && led_mode[0] )            begin //keep mode0 if not pressed this moment
                        CU_state <= WRITE_DATA_0;
                    end else if (iHREADY && led_mode[1]) begin  //keep mode1
                        CU_state <= WRITE_DATA_1;
                    end else if (iHREADY && led_mode[2]) begin  //keep mode2 
                        CU_state <= WRITE_DATA_2;
                    end else if (iHREADY && led_mode[3]) begin  //keep mode3
                        CU_state <= WRITE_DATA_3;
                    end else begin
                        CU_state <= READ_DATA_RO;  // Slave not ready || no key ever been pressed
                    end
                end
                // write DATA
                WRITE_DATA_0: begin
                    if (iHREADY) begin  // 轮询,一直进入READ_DATA_RO状态读取key
                        CU_state <= READ_DATA_RO;
                    end else begin
                        CU_state <= CU_state;
                    end
                end
                // write DATA
                WRITE_DATA_1: begin
                    if (iHREADY) begin
                        CU_state <= READ_DATA_RO;
                    end else begin
                        CU_state <= CU_state;
                    end
                end
                // write DATA
                WRITE_DATA_2: begin
                    if (iHREADY) begin
                        CU_state <= READ_DATA_RO;
                    end else begin
                        CU_state <= CU_state;
                    end
                end
                WRITE_DATA_3: begin
                    if (iHREADY) begin
                        CU_state <= READ_DATA_RO;
                    end else begin
                        CU_state <= CU_state;
                    end
                end
                default: CU_state <= CONFIG_0;
            endcase
        end
    end

    /*————————————————————————————————————————————————————————————————————————*\
    /                                AHB Master Output                         \
    \*————————————————————————————————————————————————————————————————————————*/

    assign oHTRANS = NONSEQ;  // 这三个信号在这里没用
    assign oHBURST = SINGLE;
    assign oHSIZE  = DWORD;
    /*  下面这些都是GPIO的地址, 用来读写GPIO的寄存器
    */
    always @(*) begin
        case (CU_state)
            CONFIG_0:     oHADDR = 32'h0000_0008;  // GPIO_DIRM 配置GPIO的引脚方向
            CONFIG_1:     oHADDR = 32'h0000_000C;  // GPIO_OEN  配置GPIO的引脚输出使能
            READ_DATA_RO: oHADDR = 32'h0000_0000;  // GPIO_DATA_RO 读取GPIO的引脚输入电平
            CONFIG_2, WRITE_DATA_0, WRITE_DATA_1, WRITE_DATA_2, WRITE_DATA_3: begin
                oHADDR = 32'h0000_0004;  // GPIO_DATA 配置GPIO的引脚输出电平
            end
            default:      oHADDR = 32'hz;
        endcase
    end

    /* 除了READ_DATA_RO状态下为读操作,其他都是写操作
    */
    assign oHWRITE = (CU_state == READ_DATA_RO) ? 1'b0 : 1'b1;

    always @(*) begin
        case (CU_state)
            CONFIG_0: oHWDATA = 32'h0000_00F0;  // 配置7:4为输出，3:0为输入
            CONFIG_1: oHWDATA = 32'h0000_00F0;  // 配置7:4输出使能
            CONFIG_2: oHWDATA = 32'h0000_00F0;  // 配置7:4输出高电平
            WRITE_DATA_0, WRITE_DATA_1, WRITE_DATA_2, WRITE_DATA_3: begin
                oHWDATA = {24'b0, ~LED[3:0], 4'b0};
            end
            default:  oHWDATA = 32'hz;
        endcase
    end
    // 因为小梅哥7010的eda扩展板led是高电平点亮,所以要达到流水效果, 需要翻转LED


    /*————————————————————————————————————————————————————————————————————————*\
    /                              LED Control                                 \
    \*————————————————————————————————————————————————————————————————————————*/

    //------------ led_mode ------------
    always @(posedge iHCLK) begin
        if (!iHRESETn) begin
            led_mode <= MODE_BEGIN;
        end else begin
            case (CU_state)
                CONFIG_0, CONFIG_1: begin
                    led_mode <= MODE_BEGIN;
                end
                CONFIG_2: begin
                    if (iHREADY && iHRDATA[3:0] == 4'b0000) begin
                        led_mode <= MODE0;
                    end else begin
                        led_mode <= 4'b0000;
                    end
                end
                READ_DATA_RO: begin
                    // key1 pressed mode -> MODE0 
                    if (iHREADY && iHRDATA[3:0] == 4'b1110) begin
                        led_mode <= MODE0;
                        // key2 pressed mode -> MODE1 
                    end else if (iHREADY && iHRDATA[3:0] == 4'b1101) begin
                        led_mode <= MODE1;
                        // key3 pressed mode -> MODE2 
                    end else if (iHREADY && iHRDATA[3:0] == 4'b1011) begin
                        led_mode <= MODE2;
                        // key4 pressed mode -> MODE3 
                    end else if (iHREADY && iHRDATA[3:0] == 4'b0111) begin
                        led_mode <= MODE3;
                        // no key pressed, mode kept 
                    end else begin
                        led_mode <= led_mode;
                    end
                end
                WRITE_DATA_0, WRITE_DATA_1, WRITE_DATA_2, WRITE_DATA_3: begin
                    led_mode <= led_mode;
                end
                default: begin
                    led_mode <= led_mode;
                end

            endcase
        end
    end

    //------------ timer ------------
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
