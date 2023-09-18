`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: BLT
// Engineer: 
// 
// Create Date: 2023/09/12 16:53:27
// Design Name: 
// Module Name: eeprom_driver
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


module eeprom_driver(
    input                               clk                 ,
    input                               rst_n               ,
    //UI接口
    input   [2 :0]                      i_ctrl_slave_addr   ,
    input   [P_ADDR_WIDTH - 1:0]        i_ctrl_rw_addr      ,
    input   [7 :0]                      i_ctrl_num          ,
    input   [0 :0]                      i_ctrl_type         ,
    input                               i_ctrl_valid        ,
    output                              o_ctrl_ready        ,

    input   [7 :0]                      i_ctrl_wr_data      ,
    input                               i_ctrl_wr_sop       ,
    input                               i_ctrl_wr_eop       ,
    input                               i_ctrl_wr_valid     ,

    output  [7 :0]                      o_ctrl_rd_data      ,
    output                              o_ctrl_rd_valid     ,
    //IIC
    output                              o_i2c_scl           ,
    inout                               io_i2c_sda          
    );

/******************parametera define********************/
localparam                              P_ADDR_WIDTH =16    ; 
/**********************reg define***********************/

/*********************wire define***********************/
wire    [6 :0]                          w_slave_addr        ;
wire    [P_ADDR_WIDTH - 1:0]            w_op_addr           ;
wire    [7 :0]                          w_op_len            ;
wire    [0 :0]                          w_op_type           ;
wire                                    w_op_valid          ;
wire                                    w_op_ready          ;
wire    [7 :0]                          w_wr_data           ;
wire                                    w_wr_req            ;
wire    [7 :0]                          w_rd_data           ;
wire                                    w_rd_valid          ;
/************************module*************************/
eeprom_ctrl
#(
    .P_ADDR_WIDTH                       (P_ADDR_WIDTH       ) 
)
u_eeprom_ctrl
(
    .clk                                (clk                ),
    .rst_n                              (rst_n              ),
    //
    .i_ctrl_slave_addr                  (i_ctrl_slave_addr  ),
    .i_ctrl_rw_addr                     (i_ctrl_rw_addr     ),
    .i_ctrl_num                         (i_ctrl_num         ),
    .i_ctrl_type                        (i_ctrl_type        ),
    .i_ctrl_valid                       (i_ctrl_valid       ),
    .o_ctrl_ready                       (o_ctrl_ready       ),
    .i_ctrl_wr_data                     (i_ctrl_wr_data     ),
    .i_ctrl_wr_sop                      (i_ctrl_wr_sop      ),
    .i_ctrl_wr_eop                      (i_ctrl_wr_eop      ),
    .i_ctrl_wr_valid                    (i_ctrl_wr_valid    ),
    .o_ctrl_rd_data                     (o_ctrl_rd_data     ),
    .o_ctrl_rd_valid                    (o_ctrl_rd_valid    ),
    //
    .o_slave_addr                       (w_slave_addr       ),
    .o_op_addr                          (w_op_addr          ),
    .o_op_len                           (w_op_len           ),
    .o_op_type                          (w_op_type          ),
    .o_op_valid                         (w_op_valid         ),
    .i_op_ready                         (w_op_ready         ),
    .o_wr_data                          (w_wr_data          ),
    .i_wr_req                           (w_wr_req           ),
    .i_rd_data                          (w_rd_data          ),
    .i_rd_valid                         (w_rd_valid         ) 
    );

i2c_driver
#(
    .P_ADDR_WIDTH                       (P_ADDR_WIDTH       ) 
)
u_i2c_driver
(
    .clk                                (clk                ),
    .rst_n                              (rst_n              ),

    .i_slave_addr                       (w_slave_addr       ),
    .i_op_addr                          (w_op_addr          ),
    .i_op_len                           (w_op_len           ),
    .i_op_type                          (w_op_type          ),
    .i_op_valid                         (w_op_valid         ),
    .o_op_ready                         (w_op_ready         ),
    .i_wr_data                          (w_wr_data          ),
    .o_wr_req                           (w_wr_req           ),
    .o_rd_data                          (w_rd_data          ),
    .o_rd_valid                         (w_rd_valid         ),

    .o_i2c_scl                          (o_i2c_scl          ),
    .io_i2c_sda                         (io_i2c_sda         ) 
    );                  

/************************assign*************************/

/************************always*************************/

endmodule
