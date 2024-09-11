/*
 * Copyright (c) 2024 Renaldas Zioma
 * based on the VGA examples by Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  wire [9:0] x;
  wire [9:0] y;
  wire video_active;
  
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(x),
    .vpos(y)
  );

  // music part that is used to control visuals
  wire [12:0] timer = {frame_counter, frame_counter_frac};
  wire beats_1_3 = timer[5:4] == 2'b10;
  wire [4:0] envelopeB = 5'd31 - timer[3:0]*2;
  // \end of music part that is used to control visuals

  wire signed [9:0] frame = frame_counter[6:0];
  wire signed [9:0] offset_x = frame/2; 
  wire signed [9:0] offset_y = frame; 
  wire signed [9:0] center_x = 10'sd320+offset_x;
  wire signed [9:0] center_y = 10'sd240+offset_y;
  wire signed [9:0] p_x = x - center_x;
  wire signed [9:0] p_y = y - center_y + (beats_1_3 & part==6)*(envelopeB>>1)
                                       + (beats_1_3 & part==1)*(16-envelopeB>>1);

  reg signed [17:0] r1;                                               // was 23 bit
  reg signed [18:0] r2;                                               // was 23 bit
  wire signed [19:0] r = 2*(r1 - center_y*2) + r2 - center_x*2 + 2;   // was 23 bit

  reg signed [13:0] title_r;
  reg [5:0] title_r_pixels_in_scanline;

  always @(posedge clk) begin
    if (~rst_n) begin
      r1 <= 0;
      r2 <= 0;
      title_r <= 0;
    end else begin
      if (vsync) begin
        r1 <= 0;
        r2 <= 0;
      end

      if (video_active & y == 0) begin
        // no mul optimisation, equivalent to:
        //   r1 <= center_y*center_y;
        if (x < center_y)
          r1 <= r1 + center_y;
      end else if (x == 640) begin
        // need to calculate (320+offset)^2
        // (320+offset) * (320+offset) = 320*320 + 2*320*offset + offset*offset
        r2 <= 320*320;
      end else if (x > 640) begin
        // remainder of (320+offset)^2 from above ^^^
        //    2*320*offset + offset*offset
        if (x-640 <= offset_x)
          r2 <= r2 + 2*320 + offset_x;
      end else if (video_active & x == 0) begin
        r1 <= r1 + 2*p_y + 1;
      end else if (video_active) begin
        r2 <= r2 + 2*p_x + 1;
      end

      // repeating circle for title
      if (!video_active & y[6:0] == 0) begin
        title_r <= 64*64+64*64;
      end else if (x == 640) begin
        title_r <= title_r + 2*(y[6:0]-64)+1 - 64*2;
        title_r_pixels_in_scanline <= 0;
      end else if (x > 640 && x < 640+128) begin
        title_r <= title_r + 2*(x[6:0]-64)+1;
        if (x > 640+64 & title_r < 60*60)
          title_r_pixels_in_scanline <= title_r_pixels_in_scanline + 1; // count pixels in circle for each scanline
      end
    end
  end

  wire signed [22:0] dot = (r * (128-frame)) >> (9+((frame[6:4]+1)>>1) );  // zoom on snare
  wire [7:0] pp_x = dot;
  wire [7:0] pp_y = dot;

  wire zoom_mode = part == 5 | part == 6;
  wire signed [22:0] dot2 = ((pp_x * pp_x) * frame) >> (15 - 2*zoom_mode);
  wire [7:0] ppp_x = dot2;

  // mode A: enables drop with different angle, otherwise tunnel
  wire mode_a = part == 0 | part == 1 | part == 2 | part == 5;//frame_counter[8];
  // mode B: enables drop and starting close
  wire mode_b = part == 0 | part == 4;//frame_counter[7]^frame_counter[8];
  wire [7:0] p_p =          p_y*mode_a - p_x/2*mode_a +
                            p_y*(frame[7:5]+1'd1)*mode_b - p_x*(frame[6:5]+1'd1)*mode_b;

  wire fractal_mode = part == 1 | part == 6;//frame_counter[8:7] == 2;
  wire [7:0] ppp_y = fractal_mode? 
                      -(y & 8'h7f & p_x) + (r>>11):
                        dot2 + p_p;

  // generate title pixels
  wire ringR = y[9:7] == 3'b010 & |x[9:7] & (x[6:0] < title_r_pixels_in_scanline) &
      ~(y[6] & (x[9:7] == 2));
  wire ringL = y[9:7] == 3'b010 & x[9:7] == 3'b010 & (~x[6:0] < title_r_pixels_in_scanline);
  // column on every odd 64 pixel sections except 0, 5 and 8th:
  //    .DDRR.OPP.
  //    012345678 
  wire columns = x[6] & x[8:6] != 5 & ~x[9] & (y[9:7] == 2 | y[9:7] == 3) & y[7:0] > 4 & (y[7:0] < 124 | x[8]);
  wire title = ringR | ringL | columns;
  
  // 0: title + wakes
  // 1: fractal red/golden
  // 2: drop zoom 1
  // 3: tunnel
  // 4: red wakes
  // 5: drop zoom 2 (2 zoom beats)
  // 6: fractal multi-color
  // 7: title+tunnel

wire [2:0] part = frame_counter[9-:3];
  assign {R,G,B} =
    (~video_active) ? 6'b00_00_00 :
    (part == 0) ? { &ppp_y[5:3] | title ? 6'b111_111 : 6'b0 } :                     // title + wakes
    (part == 1) ? { &ppp_y[5:2] * ppp_y[1-:2], &ppp_y[6:0] * ppp_y[1-:2], 2'b00 } : // red/golden serpinsky
    (part == 3) ? { |ppp_y[7:6] ? {4'b11_00, dot[6:5]} : ppp_y[5:4] } :             // tunnel
    (part == 4) ? { &ppp_y[6:4] * 6'b110000 | &ppp_y[6:3]*dot[7]*6'b000010 } :      // red wakes
    (part == 6) ? { ppp_y[7-:2], ppp_y[6-:2], ppp_y[5-:2] } :                       // multi-color serpinsky
    (part == 7) ? { |ppp_y[7:6] ? {4'b11_00, dot[6:5]} : ppp_y[5:4] } |
                  { 6{title & (frame_counter[6:0] >= 96) }  } :                     // title + tunnel                            // title + tunnel
                  { ppp_y[7-:2], ppp_y[7-:2], ppp_y[7-:2] } | {4'b0,~ppp_x[6-:2]};

  reg [11:0] frame_counter;
  reg frame_counter_frac;
  always @(posedge clk) begin
    if (~rst_n) begin
      frame_counter <= 0;
      frame_counter_frac <= 0;

    end else begin
      
      if (x == 0 && y == 0) begin
        frame_counter <= frame_counter + 1; // timer goes twice faster in VGA playground
                                            // than in the actual demo to compensate
                                            // for slower framerate in the browser
      end
    end
  end

endmodule
