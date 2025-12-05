`timescale 1ns/1ps

module vga_pic(
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    output reg  [15:0] pix_data
);

    localparam BLACK  = 16'h0000;
    localparam WHITE  = 16'hFFFF;
    
    // 字母尺寸（保持统一粗细）
    localparam LETTER_H = 10'd80;
    localparam LETTER_W = 10'd48;
    localparam GAP      = 10'd12;
    localparam STROKE   = 10'd10;  // 所有笔画统一粗细
    localparam RADIUS   = 10'd12;
    localparam R_SQ = RADIUS * RADIUS;

    // -------------------------- 辅助函数 (用于圆角计算) --------------------------
    function [19:0] dist_sq;
        input [9:0] x, y;
        input [9:0] cx, cy;
        reg [9:0] dx, dy;
        begin
            dx = (x > cx) ? (x - cx) : (cx - x);
            dy = (y > cy) ? (y - cy) : (cy - y);
            dist_sq = (dx * dx) + (dy * dy);
        end
    endfunction
    

    // -------------------------- 字母区域 --------------------------
    localparam TOTAL_WIDTH  = 4*LETTER_W + 3*GAP;
    localparam X_START      = 10'd320 - (TOTAL_WIDTH/2);
    localparam Y_START      = 10'd240 - (LETTER_H/2);

    wire in_m_box = (pix_x >= X_START) && (pix_x < X_START + LETTER_W) && (pix_y >= Y_START) && (pix_y < Y_START + LETTER_H);
    wire in_u_box = (pix_x >= X_START + LETTER_W + GAP) && (pix_x < X_START + 2*LETTER_W + GAP) && (pix_y >= Y_START) && (pix_y < Y_START + LETTER_H);
    wire in_s_box = (pix_x >= X_START + 2*(LETTER_W + GAP)) && (pix_x < X_START + 3*LETTER_W + 2*GAP) && (pix_y >= Y_START) && (pix_y < Y_START + LETTER_H);
    wire in_t_box = (pix_x >= X_START + 3*(LETTER_W + GAP)) && (pix_x < X_START + 4*LETTER_W + 3*GAP) && (pix_y >= Y_START) && (pix_y < Y_START + LETTER_H);

    // -------------------------- 绘制 M (修复底部横线+统一粗细) --------------------------
    wire [9:0] m_x_base = X_START;
    wire [9:0] m_x_rel  = pix_x - m_x_base;
    wire [9:0] m_y_rel  = pix_y - Y_START;
    
    // M的关键几何参数
    localparam M_MID_X   = LETTER_W / 2;     // 宽度中点（24）
    localparam M_HALF_H  = LETTER_H / 2;     // 高度中点（40）
    localparam M_SLOPE_DEN = M_MID_X - STROKE;  // 斜线分母（24-10=14）

    // 1. 左竖条（宽度=STROKE，高度全高）
    wire m_left_bar = (m_x_rel < STROKE);
    // 2. 右竖条（宽度=STROKE，高度全高）
    wire m_right_bar = (m_x_rel >= (LETTER_W - STROKE));
    // 3. 左斜线：从左竖顶部(STROKE,0)到中点(M_MID_X, M_HALF_H)，宽度=STROKE
    wire m_left_diag = (m_x_rel >= STROKE) && (m_x_rel < M_MID_X) &&
                       (m_y_rel >= ((M_HALF_H * (m_x_rel - STROKE)) / M_SLOPE_DEN) - (STROKE/2)) &&
                       (m_y_rel <= ((M_HALF_H * (m_x_rel - STROKE)) / M_SLOPE_DEN) + (STROKE/2));
    // 4. 右斜线：从中点(M_MID_X, M_HALF_H)到右竖顶部(LETTER_W-STROKE, 0)，宽度=STROKE
    wire m_right_diag = (m_x_rel >= M_MID_X) && (m_x_rel < (LETTER_W - STROKE)) &&
                        (m_y_rel >= ((-M_HALF_H * (m_x_rel - (LETTER_W - STROKE))) / M_SLOPE_DEN) - (STROKE/2)) &&
                        (m_y_rel <= ((-M_HALF_H * (m_x_rel - (LETTER_W - STROKE))) / M_SLOPE_DEN) + (STROKE/2));

    // 最终M绘制逻辑（去掉底部横线）
    wire draw_m = in_m_box && (m_left_bar || m_right_bar || m_left_diag || m_right_diag);


    // -------------------------- 绘制 U (保持原逻辑) --------------------------
    wire [9:0] u_x_base = X_START + LETTER_W + GAP;
    wire [9:0] u_x_rel = pix_x - u_x_base;
    wire [9:0] u_y_rel = pix_y - Y_START;
    
    wire u_left_rect   = (u_x_rel < STROKE);
    wire u_right_rect  = (u_x_rel >= LETTER_W - STROKE);
    wire u_bottom_rect = (u_y_rel >= LETTER_H - STROKE);
    wire u_rect_shape = (u_left_rect || u_right_rect || u_bottom_rect);
    
    wire u_corner_ld = (u_x_rel < RADIUS) && (u_y_rel >= LETTER_H - RADIUS) && 
                       (dist_sq(u_x_base + u_x_rel, Y_START + u_y_rel, u_x_base + RADIUS, Y_START + LETTER_H - RADIUS) <= R_SQ);
    wire u_corner_rd = (u_x_rel >= LETTER_W - RADIUS) && (u_y_rel >= LETTER_H - RADIUS) && 
                       (dist_sq(u_x_base + u_x_rel, Y_START + u_y_rel, u_x_base + LETTER_W - RADIUS, Y_START + LETTER_H - RADIUS) <= R_SQ);
    
    wire in_u_corner = u_corner_ld || u_corner_rd;
    wire draw_u = in_u_box && (u_rect_shape || in_u_corner);


    // -------------------------- 绘制 S (保持原逻辑) --------------------------
    wire [9:0] s_x_base = X_START + 2*(LETTER_W + GAP);
    wire [9:0] s_x_rel = pix_x - s_x_base;
    wire [9:0] s_y_rel = pix_y - Y_START;
    localparam s_y_mid  = LETTER_H/2;
    
    wire s_top_h = (s_y_rel < STROKE);
    wire s_mid_h = (s_y_rel >= s_y_mid - STROKE/2) && (s_y_rel < s_y_mid + STROKE/2);
    wire s_bot_h = (s_y_rel >= LETTER_H - STROKE);
    wire s_top_v = (s_x_rel < STROKE) && (s_y_rel < s_y_mid);
    wire s_bot_v = (s_x_rel >= LETTER_W - STROKE) && (s_y_rel >= s_y_mid);
    wire s_rect_shape = (s_top_h || s_mid_h || s_bot_h || s_top_v || s_bot_v);

    wire s_corner_lu = (s_x_rel < RADIUS) && (s_y_rel < RADIUS) && 
                       (dist_sq(s_x_base + s_x_rel, Y_START + s_y_rel, s_x_base + RADIUS, Y_START + RADIUS) <= R_SQ);
    wire s_corner_ru = (s_x_rel >= LETTER_W - RADIUS) && (s_y_rel < RADIUS) && 
                       (dist_sq(s_x_base + s_x_rel, Y_START + s_y_rel, s_x_base + LETTER_W - RADIUS, Y_START + RADIUS) <= R_SQ);
    wire s_corner_ld = (s_x_rel < RADIUS) && (s_y_rel >= LETTER_H - RADIUS) && 
                       (dist_sq(s_x_base + s_x_rel, Y_START + s_y_rel, s_x_base + RADIUS, Y_START + LETTER_H - RADIUS) <= R_SQ);
    wire s_corner_rd = (s_x_rel >= LETTER_W - RADIUS) && (s_y_rel >= LETTER_H - RADIUS) && 
                       (dist_sq(s_x_base + s_x_rel, Y_START + s_y_rel, s_x_base + LETTER_W - RADIUS, Y_START + LETTER_H - RADIUS) <= R_SQ);

    wire in_s_corner = s_corner_lu || s_corner_ru || s_corner_ld || s_corner_rd;
    wire draw_s = in_s_box && (s_rect_shape || in_s_corner);


    // -------------------------- 绘制 T (保持原逻辑) --------------------------
    wire [9:0] t_x_base = X_START + 3*(LETTER_W + GAP);
    wire [9:0] t_x_rel = pix_x - t_x_base;
    wire [9:0] t_y_rel = pix_y - Y_START;
    
    wire t_top  = (t_y_rel < STROKE);
    wire t_vert = (t_x_rel >= LETTER_W/2 - STROKE/2) && (t_x_rel < LETTER_W/2 + STROKE/2);

    wire t_corner_lu = (t_x_rel < RADIUS) && (t_y_rel < RADIUS) && 
                       (dist_sq(t_x_base + t_x_rel, Y_START + t_y_rel, t_x_base + RADIUS, Y_START + RADIUS) <= R_SQ);
    wire t_corner_ru = (t_x_rel >= LETTER_W - RADIUS) && (t_y_rel < RADIUS) && 
                       (dist_sq(t_x_base + t_x_rel, Y_START + t_y_rel, t_x_base + LETTER_W - RADIUS, Y_START + RADIUS) <= R_SQ);
    
    wire in_t_corner = t_corner_lu || t_corner_ru;
    wire draw_t = in_t_box && (t_top || t_vert || in_t_corner);


    // -------------------------- 输出像素 --------------------------
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) pix_data <= BLACK;
        else pix_data <= (draw_m || draw_u || draw_s || draw_t) ? WHITE : BLACK;
    end
endmodule
