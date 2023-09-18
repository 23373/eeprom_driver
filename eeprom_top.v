`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: BLT 
// Engineer: 
// 
// Create Date: 2023/09/12 17:07:09
// Design Name: 
// Module Name: eeprom_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module eeprom_top(
    input                               clk                 ,

    output                              o_i2c_scl           ,
    inout                               io_i2c_sda          
    );
/******************parametera define********************/
localparam                              P_RW_NUMBER = 8     ;

/**********************reg define***********************/
reg  [2 :0]                             ri_ctrl_slave_addr  ;
reg  [15:0]                             ri_ctrl_rw_addr     ;
reg  [7 :0]                             ri_ctrl_num         ;
reg  [0 :0]                             ri_ctrl_type        ;
reg                                     ri_ctrl_valid       ;
reg  [7 :0]                             ri_ctrl_wr_data     ;
reg                                     ri_ctrl_wr_sop      ;
reg                                     ri_ctrl_wr_eop      ;
reg                                     ri_ctrl_wr_valid    ;
reg  [7 :0]                             r_st_cnt            ;
reg  [7 :0]                             r_wr_cnt            ;
/*********************wire define***********************/
wire                                    w_clk_5mhz          ;
wire                                    w_locked            ;
wire                                    w_clk_125khz        ;
wire                                    w_rst_n             ;
wire  [7 :0]                            wo_ctrl_rd_data     ;
wire                                    wo_ctrl_rd_valid    ;
wire                                    wo_ctrl_ready       ;
wire                                    w_ctrl_active       ;

/************************module*************************/
clk_wiz_0 u_clk_wiz_0(
    .clk_out1                           (w_clk_5mhz         ),    
    .locked                             (w_locked           ),
    .clk_in1                            (clk                )
    );

clk_drive
#(
    .P_factor                           (40                 )          
)
u_clk_drive
(
    .clk                                (w_clk_5mhz         ),
    .rst_n                              (w_locked           ),
    .o_clk                              (w_clk_125khz       )
    );

rst_n_drive
#(
    .P_rst_sync                         (10                 ) 
)
u_rst_n_drive
(
    .i_clk                              (w_clk_125khz       ),
    .o_rst_n                            (w_rst_n            )
);

eeprom_driver u_eeprom_driver(
    .clk                                (w_clk_125khz       ),
    .rst_n                              (w_rst_n            ),
    //UI接口
    .i_ctrl_slave_addr                  (ri_ctrl_slave_addr ),
    .i_ctrl_rw_addr                     (ri_ctrl_rw_addr    ),
    .i_ctrl_num                         (ri_ctrl_num        ),
    .i_ctrl_type                        (ri_ctrl_type       ),
    .i_ctrl_valid                       (ri_ctrl_valid      ),
    .o_ctrl_ready                       (wo_ctrl_ready      ),
    .i_ctrl_wr_data                     (ri_ctrl_wr_data    ),
    .i_ctrl_wr_sop                      (ri_ctrl_wr_sop     ),
    .i_ctrl_wr_eop                      (ri_ctrl_wr_eop     ),
    .i_ctrl_wr_valid                    (ri_ctrl_wr_valid   ),
    .o_ctrl_rd_data                     (wo_ctrl_rd_data    ),
    .o_ctrl_rd_valid                    (wo_ctrl_rd_valid   ),
    //IIC
    .o_i2c_scl                          (o_i2c_scl          ),
    .io_i2c_sda                         (io_i2c_sda         )
    );
/************************assign*************************/
assign  w_ctrl_active = ri_ctrl_valid && wo_ctrl_ready      ;
/************************always*************************/
always@(posedge w_clk_125khz or negedge w_rst_n)
begin 
    if(!w_rst_n) begin
        ri_ctrl_slave_addr <= 'd0;
        ri_ctrl_rw_addr    <= 'd0;
        ri_ctrl_num        <= 'd0;
        ri_ctrl_type       <= 'd0;
        ri_ctrl_valid      <= 'd0;
    end
    else if(wo_ctrl_ready && r_st_cnt == 0) begin
        ri_ctrl_slave_addr <= 'd3;
        ri_ctrl_rw_addr    <= 'd0;
        ri_ctrl_num        <= P_RW_NUMBER;
        ri_ctrl_type       <= 'd0;
        ri_ctrl_valid      <= 'd1;
    end
    else if(wo_ctrl_ready && r_st_cnt == 1) begin
        ri_ctrl_slave_addr <= 'd3;
        ri_ctrl_rw_addr    <= 'd0;
        ri_ctrl_num        <= P_RW_NUMBER;
        ri_ctrl_type       <= 'd1;
        ri_ctrl_valid      <= 'd1;
    end
    else begin
        ri_ctrl_slave_addr <= 'd0;
        ri_ctrl_rw_addr    <= 'd0;
        ri_ctrl_num        <= 'd0;
        ri_ctrl_type       <= 'd0;
        ri_ctrl_valid      <= 'd0;
    end
end

always@(posedge w_clk_125khz or negedge w_rst_n)
begin 
    if(!w_rst_n)
        r_st_cnt <= 'd0;
    else if(w_ctrl_active)
        r_st_cnt <= r_st_cnt + 'd1;
    else
        r_st_cnt <= r_st_cnt;
end

always@(posedge w_clk_125khz or negedge w_rst_n)
begin 
    if(!w_rst_n)
        ri_ctrl_wr_data <= 'd0;
    else if(ri_ctrl_wr_valid)
        ri_ctrl_wr_data <= ri_ctrl_wr_data + 'd1;
    else
        ri_ctrl_wr_data <= ri_ctrl_wr_data;
end

always@(posedge w_clk_125khz or negedge w_rst_n)
begin 
    if(!w_rst_n)
        ri_ctrl_wr_sop <= 'd0;
    else if(w_ctrl_active && r_st_cnt == 0)
        ri_ctrl_wr_sop <= 'd1;
    else
        ri_ctrl_wr_sop <= 'd0;
end

always@(posedge w_clk_125khz or negedge w_rst_n)
begin 
    if(!w_rst_n)
        ri_ctrl_wr_eop <= 'd0;
    else if((w_ctrl_active || ri_ctrl_wr_valid) &&(r_wr_cnt == P_RW_NUMBER - 1))
        ri_ctrl_wr_eop <= 'd1;
    else
        ri_ctrl_wr_eop <= 'd0;
end

always@(posedge w_clk_125khz or negedge w_rst_n)
begin
    if(!w_rst_n)
        ri_ctrl_wr_valid <= 'd0;
    else if(ri_ctrl_wr_eop)
        ri_ctrl_wr_valid <= 'd0;
    else if(w_ctrl_active && r_st_cnt == 0)
        ri_ctrl_wr_valid <= 'd1;
    else
        ri_ctrl_wr_valid <= ri_ctrl_wr_valid;
end

always@(posedge w_clk_125khz or negedge w_rst_n)
begin
    if(!w_rst_n)
        r_wr_cnt <= 'd0;
    else if(r_wr_cnt == P_RW_NUMBER - 1)
        r_wr_cnt <= 'd0;
    else if(ri_ctrl_wr_valid)
        r_wr_cnt <= r_wr_cnt + 'd1;
    else
        r_wr_cnt <= r_wr_cnt;
end

endmodule
