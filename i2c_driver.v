`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: BLT
// Engineer: 
// 
// Create Date: 2023/09/05 10:57:48
// Design Name: 
// Module Name: i2c_driver
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


module i2c_driver
#(
    parameter                       P_ADDR_WIDTH = 16  
)
(
    input                               clk             ,   //系统时钟
    input                               rst_n           ,   //系统复位

    input   [6 :0]                      i_slave_addr    ,   //从机地址
    input   [P_ADDR_WIDTH - 1:0]        i_op_addr       ,   //操作地址
    input   [7 :0]                      i_op_len        ,   //操作长度
    input   [0 :0]                      i_op_type       ,   //操作类型
    input                               i_op_valid      ,   //操作有效
    output                              o_op_ready      ,   //操作准备

    input   [7 :0]                      i_wr_data       ,   //发送数据
    output                              o_wr_req        ,   //发送请求

    output  [7 :0]                      o_rd_data       ,   //接收数据
    output                              o_rd_valid      ,   //接收有效

    output                              o_i2c_scl       ,   //IIC SCL
    inout                               io_i2c_sda          //IIC SDA
    );
/****************parametera define*******************/
localparam                              st_idle      = 0 ,   //空闲   
                                        st_start     = 1 ,   //起始
                                        st_addr_slave= 2 ,   //发送从机地址
                                        st_addr_msb  = 3 ,   //发送操作地址高位
                                        st_addr_lsb  = 4 ,   //发送操作地址低位
                                        st_send_data = 5 ,   //发送数据
                                        st_restart   = 6 ,
                                        st_recv_data = 7 ,   //接收数据
                                        st_wait      = 8 , 
                                        st_stop      = 9 ,   //结束
                                        st_empty     = 10;

localparam                              P_OP_WRITE   = 0,   //写操作
                                        P_OP_READ    = 1;   //读操作
                                    
/*********************reg define*********************/
reg     [3 :0]                          c_state,n_state ;
reg                                     ro_op_ready     ;
reg                                     ro_wr_req       ;
reg                                     r_write_valid   ;
reg     [7 :0]                          ro_rd_data      ;
reg                                     ro_rd_valid     ;
reg                                     ro_i2c_scl      ;
reg     [7 :0]                          ri_slave_addr   ;
reg     [P_ADDR_WIDTH - 1:0]            ri_op_addr      ;
reg     [7 :0]                          ri_op_len       ;
reg     [0 :0]                          ri_op_type      ;
reg                                     r_st_scl        ;
reg     [7 :0]                          r_st_cnt        ;
reg                                     r_sda_ctrl      ;
reg                                     r_sda_out       ;
reg     [7 :0]                          ri_wr_data      ;                        
reg     [7 :0]                          r_wr_cnt        ;
reg                                     r_slave_ack     ;
reg                                     r_ack_valid     ;
reg     [7 :0]                          r_rd_slave_addr ;
reg                                     r_restart_flag  ;
reg                                     r_ack_lock      ;

/********************wire define*********************/
wire                                    w_op_active     ;
wire                                    w_st_change     ;
wire                                    w_sda_in        ;

/***********************assign***********************/
assign  o_op_ready  = ro_op_ready                       ;
assign  o_wr_req    = ro_wr_req                         ;
assign  o_rd_data   = ro_rd_data                        ;
assign  o_rd_valid  = ro_rd_valid                       ;
assign  o_i2c_scl   = ro_i2c_scl                        ;
assign  w_op_active = i_op_valid && o_op_ready          ;
assign  w_st_change = (r_st_cnt == 8) && r_st_scl       ;
assign  io_i2c_sda  = r_sda_ctrl  ? r_sda_out  : 'dz    ;   //三态门
assign  w_sda_in    = !r_sda_ctrl ? io_i2c_sda : 'd0    ;

/***********************always***********************/
always@(posedge clk or negedge rst_n)   //寄存操作数据
begin
    if(!rst_n)begin
        ri_slave_addr <= 'd0;
        ri_op_addr    <= 'd0;
        ri_op_len     <= 'd0;
        ri_op_type    <= 'd0;
    end
    else if(w_op_active)begin
        ri_slave_addr <= {i_slave_addr,1'b0};  //从机地址 + 写(发送)操作 (读写数据首先都要写地址 所以第一次必定为写数据)
        ri_op_addr    <= i_op_addr      ; 
        ri_op_len     <= i_op_len       ; 
        ri_op_type    <= i_op_type      ; 
    end
    else begin
        ri_slave_addr <= ri_slave_addr ;
        ri_op_addr    <= ri_op_addr    ;
        ri_op_len     <= ri_op_len     ;
        ri_op_type    <= ri_op_type    ;
    end
end

always@(posedge clk or negedge rst_n)//读数据第二次发送的从机地址 低位为 1 
 begin
    if(!rst_n)
        r_rd_slave_addr <= 'd0;
    else if(w_op_active)
        r_rd_slave_addr <= {i_slave_addr,1'b1}; //从机地址 + 读(接收)操作
    else 
        r_rd_slave_addr <= r_rd_slave_addr;
 end

always@(posedge clk or negedge rst_n)//写数据寄存
begin
    if(!rst_n)
        ri_wr_data <= 'd0;
    else if(r_write_valid)
        ri_wr_data <= i_wr_data;
    else
        ri_wr_data <= ri_wr_data;
end 

always@(posedge clk or negedge rst_n)//状态机第一段
begin
    if(!rst_n)
        c_state <= st_idle;
    else
        c_state <= n_state;
end

always@(*)//状态跳转
begin
    n_state = st_idle;
    case(c_state)
        st_idle       : n_state = w_op_active   ? st_start : st_idle ; 
        st_start      : n_state = st_addr_slave ;  
        st_addr_slave : n_state = w_st_change   ? (r_restart_flag ? st_recv_data : st_addr_msb) : st_addr_slave;        //检测重启信号 跳转到读(接收)数据
        st_addr_msb   : n_state = r_slave_ack   ? st_stop : (w_st_change ? st_addr_lsb : st_addr_msb); 
        st_addr_lsb   : n_state = (w_st_change  && ri_op_type == P_OP_WRITE   ) ? st_send_data :
                                  (w_st_change  && ri_op_type == P_OP_READ    ) ? st_restart   : st_addr_lsb  ;         //判断是否读数据 否者跳转重启
        st_send_data  : n_state = (w_st_change  && r_wr_cnt   == ri_op_len - 1) ? st_wait      : st_send_data ; 
        st_restart    : n_state = st_stop;                                                                              //重启
        st_recv_data  : n_state = w_st_change   ? st_wait  : st_recv_data ;                                             //随机读一次只能读一个数据
        st_wait       : n_state = st_stop;                                                                              //等待应答 
        st_stop       : n_state = r_st_cnt == 1 ? st_empty : st_stop      ;
        st_empty      : n_state = (r_restart_flag || r_ack_lock) ? st_start : st_idle;
        default       : n_state = st_idle;   
    endcase
end

always@(posedge clk or negedge rst_n)//应答
begin
    if(!rst_n)
        r_ack_lock <= 'd0;
    else if(r_ack_valid && !w_sda_in && c_state == st_addr_msb)
        r_ack_lock <= 'd0;
    else if(r_ack_valid && w_sda_in &&  c_state == st_addr_msb)
        r_ack_lock <= 'd1;
    else
        r_ack_lock <= r_ack_lock;
end

always@(posedge clk or negedge rst_n)//重启信号 
begin
    if(!rst_n)
        r_restart_flag <= 'd0;
    else if(c_state == st_recv_data)
        r_restart_flag <= 'd0;
    else if(c_state == st_restart)
        r_restart_flag <= 'd1;
    else
        r_restart_flag <= r_restart_flag;
end

always@(posedge clk or negedge rst_n)//操作准备
begin
    if(!rst_n)
        ro_op_ready <= 'd1;
    else if(w_op_active)
        ro_op_ready <= 'd0;
    else if(c_state == st_idle)
        ro_op_ready <= 'd1;
    else
        ro_op_ready <= ro_op_ready;
end

always@(posedge clk or negedge rst_n)//状态计数
begin
    if(!rst_n)
        r_st_cnt <= 'd0;
    else if(c_state != n_state || r_write_valid || ro_rd_valid)
        r_st_cnt <= 'd0;
    else if(c_state == st_stop)
        r_st_cnt <= r_st_cnt + 'd1;
    else if(r_st_scl)
        r_st_cnt <= r_st_cnt + 'd1;
    else
        r_st_cnt <= r_st_cnt;
end

always@(posedge clk or negedge rst_n)//IIC SCL
begin
    if(!rst_n)
        ro_i2c_scl <= 'd1;
    else if(c_state >= st_addr_slave && c_state <= st_wait)
        ro_i2c_scl <= ~ro_i2c_scl;
    else
        ro_i2c_scl <= 'd1; 
end

always@(posedge clk or negedge rst_n)//时钟状态信号
begin
    if(!rst_n)
        r_st_scl <= 'd0;
    else if(c_state >= st_addr_slave && c_state <= st_wait)
        r_st_scl <= ~r_st_scl;
    else
        r_st_scl <= 'd0;
end

always@(posedge clk or negedge rst_n)//SDA 总线控制
begin
    if(!rst_n)
        r_sda_ctrl <= 'd0;
    else if(r_st_cnt == 8 || c_state == st_idle)
        r_sda_ctrl <= 'd0;
    else if(c_state >= st_start && c_state <= st_send_data || c_state == st_stop)
        r_sda_ctrl <= 'd1;
    else
        r_sda_ctrl <= r_sda_ctrl;
end


always@(posedge clk or negedge rst_n)//IIC SDA
begin
    if(!rst_n)
        r_sda_out <= 'd0;
    else if(c_state == st_start)
        r_sda_out <= 'd0;
    else if(c_state == st_addr_slave)
        r_sda_out <= r_restart_flag ? r_rd_slave_addr[7 - r_st_cnt] : ri_slave_addr[7 - r_st_cnt];  //判断重启信号是否为高 
    else if(c_state == st_addr_msb)
        r_sda_out <= ri_op_addr[15 - r_st_cnt];
    else if(c_state == st_addr_lsb)
        r_sda_out <= ri_op_addr[7 - r_st_cnt];
    else if(c_state == st_send_data)
        r_sda_out <= ri_wr_data[7 - r_st_cnt];
    else if(c_state == st_stop && r_st_cnt == 1)
        r_sda_out <= 'd1;
    else if(c_state == st_empty)
        r_sda_out <= 'd1;
    else
        r_sda_out <= 'd0;
end

always@(posedge clk or negedge rst_n)//写请求
begin
    if(!rst_n)
        ro_wr_req <= 'd0;
    else if(c_state == st_addr_lsb && ri_op_type == P_OP_WRITE && r_st_cnt == 7 && r_st_scl)
        ro_wr_req <= 'd1;
    else if(c_state >= st_addr_lsb && ri_op_type == P_OP_WRITE && r_st_cnt == 7 && r_st_scl)
        ro_wr_req <= (r_wr_cnt < ri_op_len - 1) ? 'd1:'d0;
    else
        ro_wr_req <= 'd0;
end

always@(posedge clk or negedge rst_n)//数据输入有效
begin
    if(!rst_n)
        r_write_valid <= 'd0;
    else
        r_write_valid <= ro_wr_req;
end

always@(posedge clk or negedge rst_n)//读写计数
begin
    if(!rst_n)
        r_wr_cnt <= 'd0;
    else if(c_state == st_idle)
        r_wr_cnt <= 'd0;
    else if((c_state == st_send_data || c_state == st_recv_data) && w_st_change)
        r_wr_cnt <= r_wr_cnt + 'd1;
    else
        r_wr_cnt <= r_wr_cnt;
end

always@(posedge clk or negedge rst_n)//接收数据
begin
    if(!rst_n)
        ro_rd_data <= 'd0;
    else if(c_state == st_recv_data && r_st_cnt >= 1 && r_st_cnt <= 8 && !r_st_scl)
        ro_rd_data <= {ro_rd_data[6:0],w_sda_in};
    else
        ro_rd_data <= ro_rd_data;
end

always@(posedge clk or negedge rst_n)//接收数据有效
begin
    if(!rst_n)
        ro_rd_valid <= 'd0;
    else if(c_state == st_recv_data && r_st_cnt == 8 && !r_st_scl)
        ro_rd_valid <= 'd1;
    else
        ro_rd_valid <= 'd0;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        r_slave_ack <= 'd0;
    else if(r_ack_valid)
        r_slave_ack <= w_sda_in;
    else
        r_slave_ack <= 'd0;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        r_ack_valid <= 'd0;
    else
        r_ack_valid <= w_st_change;
end

/***********************module***********************/
endmodule
