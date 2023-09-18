`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: BLT
// Engineer: 
// 
// Create Date: 2023/09/12 14:15:17
// Design Name: 
// Module Name: eeprom_ctrl
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


module eeprom_ctrl
#(
    parameter                               P_ADDR_WIDTH = 16  
)
(
    input                                   clk                 ,
    input                                   rst_n               ,
    //
    input   [2 :0]                          i_ctrl_slave_addr   ,
    input   [P_ADDR_WIDTH - 1:0]            i_ctrl_rw_addr      ,
    input   [7 :0]                          i_ctrl_num          ,
    input   [0 :0]                          i_ctrl_type         ,
    input                                   i_ctrl_valid        ,
    output                                  o_ctrl_ready        ,

    input   [7 :0]                          i_ctrl_wr_data      ,
    input                                   i_ctrl_wr_sop       ,
    input                                   i_ctrl_wr_eop       ,
    input                                   i_ctrl_wr_valid     ,

    output  [7 :0]                          o_ctrl_rd_data      ,
    output                                  o_ctrl_rd_valid     ,
    //
    output  [6 :0]                          o_slave_addr        ,   //从机地址
    output  [P_ADDR_WIDTH - 1:0]            o_op_addr           ,   //操作地址
    output  [7 :0]                          o_op_len            ,   //操作长度
    output  [0 :0]                          o_op_type           ,   //操作类型
    output                                  o_op_valid          ,   //操作有效
    input                                   i_op_ready          ,   //操作准备

    output  [7 :0]                          o_wr_data           ,   //发送数据
    input                                   i_wr_req            ,   //发送请求

    input   [7 :0]                          i_rd_data           ,   //接收数据
    input                                   i_rd_valid              //接收有效
    );
/******************parametera define********************/
localparam                                  ST_IDLE   = 0       ,
                                            ST_WRITE  = 1       ,
                                            ST_WATI   = 2       ,
                                            ST_READ   = 3       ,
                                            ST_REREAD = 4       ,
                                            ST_OREAD  = 5       ;

/**********************reg define***********************/
reg     [2 :0]                              c_state , n_state   ;
reg                                         ro_ctrl_ready       ;
reg     [7 :0]                              ro_ctrl_rd_data     ;  
reg                                         ro_ctrl_rd_valid    ;
reg                                         ro_ctrl_rd_valid_1d ;
reg     [2 :0]                              ri_ctrl_slave_addr  ;
reg     [P_ADDR_WIDTH - 1:0]                ri_ctrl_rw_addr     ;
reg     [7 :0]                              ri_ctrl_num         ;
reg     [0 :0]                              ri_ctrl_type        ;
reg     [7 :0]                              ri_ctrl_wr_data     ;
reg                                         ri_ctrl_wr_sop      ;
reg                                         ri_ctrl_wr_eop      ;
reg                                         ri_ctrl_wr_valid    ;
reg     [6 :0]                              ro_slave_addr       ;
reg     [P_ADDR_WIDTH - 1:0]                ro_op_addr          ;
reg     [7 :0]                              ro_op_len           ;
reg     [0 :0]                              ro_op_type          ;
reg                                         ro_op_valid         ;
reg                                         ri_op_ready         ;
reg     [7 :0]                              ri_rd_data          ;
reg                                         ri_rd_valid         ;
reg                                         r_fifo_rd_en        ;
reg                                         r_fifo_rd_cnt       ;   //读数据计数
reg     [7 :0]                              r_rd_addr           ;

/*********************wire define***********************/
wire                                        w_ctrl_active       ;
wire                                        w_op_active         ;
wire                                        w_op_end            ;
wire    [7 :0]                              w_fifo_rd_data      ;
wire                                        w_fifo_wr_full      ;
wire                                        w_fifo_wr_empty     ;
wire                                        w_fifo_rd_full      ;
wire                                        w_fifo_rd_empty     ;

/************************module*************************/
FIFO U_FIFO_WRITE(
    .clk                                    (clk               ),
    .srst                                   (~rst_n            ),
    .din                                    (ri_ctrl_wr_data   ),
    .wr_en                                  (ri_ctrl_wr_valid  ),
    .rd_en                                  (i_wr_req          ),
    .dout                                   (o_wr_data         ),
    .full                                   (w_fifo_wr_full    ),
    .empty                                  (w_fifo_wr_empty   ) 
    );

FIFO U_FIFO_READ(
    .clk                                    (clk               ),
    .srst                                   (~rst_n            ),
    .din                                    (ri_rd_data        ),
    .wr_en                                  (ri_rd_valid       ),
    .rd_en                                  (r_fifo_rd_en      ),
    .dout                                   (w_fifo_rd_data    ),
    .full                                   (w_fifo_rd_full    ),
    .empty                                  (w_fifo_rd_empty   ) 
    );

/************************assign*************************/
assign  o_ctrl_ready      = ro_ctrl_ready                       ; 
assign  o_ctrl_rd_data    = ro_ctrl_rd_data                     ; 
assign  o_ctrl_rd_valid   = ro_ctrl_rd_valid_1d                 ;   

assign  o_slave_addr      = ro_slave_addr                       ;
assign  o_op_addr         = ro_op_addr                          ;
assign  o_op_len          = ro_op_len                           ;
assign  o_op_type         = ro_op_type                          ;
assign  o_op_valid        = ro_op_valid                         ;

assign  w_ctrl_active     = i_ctrl_valid && o_ctrl_ready        ;
assign  w_op_active       = o_op_valid && i_op_ready            ;
assign  w_op_end          = i_op_ready && !ri_op_ready          ;  
/************************always*************************/
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        c_state <= ST_IDLE;
    else
        c_state <= n_state;
end

always@(*)
begin
    n_state = ST_IDLE;
    case(c_state)
        ST_IDLE   : n_state = (w_ctrl_active && i_ctrl_type == 'd0) ? ST_WRITE : 
                              (w_ctrl_active && i_ctrl_type == 'd1 ? ST_WATI : ST_IDLE);
        ST_WRITE  : n_state = w_op_end ? ST_IDLE : ST_WRITE;
        ST_WATI   : n_state = ST_READ;
        ST_READ   : n_state = w_op_end ? (r_fifo_rd_cnt == ri_ctrl_num - 'd1 ? ST_OREAD : ST_REREAD) : ST_READ;
        ST_REREAD : n_state = ST_READ;
        ST_OREAD  : n_state = w_fifo_rd_empty ? ST_IDLE : ST_OREAD; 
        default   : n_state = ST_IDLE;
    endcase
end

always@(posedge clk or negedge rst_n)   //激活寄存数据
begin
    if(!rst_n)begin
        ri_ctrl_slave_addr <= 'd0;
        ri_ctrl_rw_addr    <= 'd0;
        ri_ctrl_num        <= 'd0;
        ri_ctrl_type       <= 'd0;
    end
    else if(w_ctrl_active)begin
        ri_ctrl_slave_addr <= i_ctrl_slave_addr ;
        ri_ctrl_rw_addr    <= i_ctrl_rw_addr    ;
        ri_ctrl_num        <= i_ctrl_num        ;
        ri_ctrl_type       <= i_ctrl_type       ;
    end
    else begin
        ri_ctrl_slave_addr <= ri_ctrl_slave_addr;
        ri_ctrl_rw_addr    <= ri_ctrl_rw_addr   ;
        ri_ctrl_num        <= ri_ctrl_num       ;
        ri_ctrl_type       <= ri_ctrl_type      ;
    end
end

always@(posedge clk or negedge rst_n)   //寄存写数据以及信号
begin
    if(!rst_n) begin
        ri_ctrl_wr_data  <= 'd0;
        ri_ctrl_wr_sop   <= 'd0;
        ri_ctrl_wr_eop   <= 'd0;
        ri_ctrl_wr_valid <= 'd0;
    end
    else begin
        ri_ctrl_wr_data  <= i_ctrl_wr_data ;
        ri_ctrl_wr_sop   <= i_ctrl_wr_sop  ;
        ri_ctrl_wr_eop   <= i_ctrl_wr_eop  ;
        ri_ctrl_wr_valid <= i_ctrl_wr_valid;
    end
end

always@(posedge clk or negedge rst_n)   //寄存检测上升沿
begin
    if(!rst_n)
        ri_op_ready <= 'd0;
    else
        ri_op_ready <= i_op_ready;
end

always@(posedge clk or negedge rst_n)   //寄存读出的数据
begin
    if(!rst_n)begin
        ri_rd_data  <= 'd0;
        ri_rd_valid <= 'd0;
    end
    else begin
        ri_rd_data  <= i_rd_data ;
        ri_rd_valid <= i_rd_valid;
    end
end

always@(posedge clk or negedge rst_n)   //输出操作信号给到iic_driver
begin
    if(!rst_n)begin
        ro_slave_addr <= 'd0;
        ro_op_addr    <= 'd0;
        ro_op_len     <= 'd0;
        ro_op_type    <= 'd0;
        ro_op_valid   <= 'd0;
    end
    else if(w_op_active)begin
        ro_slave_addr <= 'd0; 
        ro_op_addr    <= 'd0;
        ro_op_len     <= 'd0;
        ro_op_type    <= 'd0;
        ro_op_valid   <= 'd0;
    end
    else if(ri_ctrl_wr_eop)begin
        ro_slave_addr <= {4'b1010,ri_ctrl_slave_addr};
        ro_op_addr    <= ri_ctrl_rw_addr;
        ro_op_len     <= ri_ctrl_num    ;
        ro_op_type    <= ri_ctrl_type   ;
        ro_op_valid   <= 1'b1           ;
    end   
    else if(n_state == ST_READ && c_state != ST_READ)begin
        ro_slave_addr <= {4'b1010,ri_ctrl_slave_addr};
        ro_op_addr    <= r_rd_addr    ;
        ro_op_len     <= 'd1          ;
        ro_op_type    <= ri_ctrl_type ;
        ro_op_valid   <= 1'b1         ;
    end  
    else begin   
        ro_slave_addr <= ro_slave_addr;
        ro_op_addr    <= ro_op_addr   ;
        ro_op_len     <= ro_op_len    ;
        ro_op_type    <= ro_op_type   ;
        ro_op_valid   <= ro_op_valid  ;
    end
end;

always@(posedge clk or negedge rst_n)   //准备信号
begin
    if(!rst_n)
        ro_ctrl_ready <= 'd0;
    else if(w_ctrl_active)
        ro_ctrl_ready <= 'd0;
    else if(c_state == ST_IDLE)
        ro_ctrl_ready <= 'd1;
    else
        ro_ctrl_ready <= ro_ctrl_ready;
end

always@(posedge clk or negedge rst_n)   //将读fifo读出的数据给到用户
begin
    if(!rst_n)
        ro_ctrl_rd_data <= 'd0;
    else
        ro_ctrl_rd_data <= w_fifo_rd_data;
end

always@(posedge clk or negedge rst_n)   //读有效
begin
    if(!rst_n)
        ro_ctrl_rd_valid <= 'd0;
    else if(w_fifo_rd_empty)
        ro_ctrl_rd_valid <= 'd0;
    else if(r_fifo_rd_en)
        ro_ctrl_rd_valid <= 'd1;
    else
        ro_ctrl_rd_valid <= ro_ctrl_rd_valid;
end

always@(posedge clk or negedge rst_n)   //打拍
begin
    if(!rst_n)
        ro_ctrl_rd_valid_1d <= 'd0;
    else 
        ro_ctrl_rd_valid_1d <= ro_ctrl_rd_valid;
end

always@(posedge clk or negedge rst_n)   //读使能
begin
    if(!rst_n)
        r_fifo_rd_en <= 'd0;
    else if(w_fifo_rd_empty)
        r_fifo_rd_en <= 'd0;
    else if(c_state != ST_OREAD && n_state == ST_OREAD)
        r_fifo_rd_en <= 'd1;
    else
        r_fifo_rd_en <= r_fifo_rd_en;
end

always@(posedge clk or negedge rst_n)   //读数据计数
begin
    if(!rst_n)
        r_fifo_rd_cnt <= 'd0;
    else if(c_state == ST_IDLE)
        r_fifo_rd_cnt <= 'd0;
    else if(c_state == ST_READ && w_op_end)
        r_fifo_rd_cnt <=  r_fifo_rd_cnt + 'd1;
    else
        r_fifo_rd_cnt <= r_fifo_rd_cnt; 
end

always@(posedge clk or negedge rst_n)   //读地址 累加
begin
    if(!rst_n)
        r_rd_addr <= 'd0;
    else if(w_ctrl_active)
        r_rd_addr <= 'd0;
    else if(c_state == ST_READ && w_op_end)
        r_rd_addr <= r_rd_addr + 'd1;
    else
        r_rd_addr <= r_rd_addr;
end

endmodule
