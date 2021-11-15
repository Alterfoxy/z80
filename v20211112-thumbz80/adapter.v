module adapter
(
    input   wire        CLOCK,
    output  reg  [3:0]  VGA_R,
    output  reg  [3:0]  VGA_G,
    output  reg  [3:0]  VGA_B,
    output  wire        VGA_HS,
    output  wire        VGA_VS,
    output  reg  [15:0] vaddr,
    input   wire [ 7:0] vdata,
    input   wire [11:0] border
);
       
// ---------------------------------------------------------------------
// Тайминги для горизонтальной и вертикальной развертки
//        Visible    Front     Sync      Back      Whole
parameter hzv = 640, hzf = 16, hzs = 96, hzb = 48, hzw = 800,
          vtv = 400, vtf = 12, vts = 2,  vtb = 35, vtw = 449;
// ---------------------------------------------------------------------
assign VGA_HS = X  < (hzb + hzv + hzf); // NEG
assign VGA_VS = Y >= (vtb + vtv + vtf); // POS
// ---------------------------------------------------------------------
// Позиция луча в кадре и максимальные позиции (x,y)
reg  [ 9:0] X = 0; wire xmax = (X == hzw - 1);
reg  [ 9:0] Y = 0; wire ymax = (Y == vtw - 1);
wire [ 9:0] x = (X - hzb); // x=[0..639]
wire [ 9:0] y = (Y - vtb); // y=[0..399]
// ---------------------------------------------------------------------

reg  [ 3:0] color;
wire [ 9:0] xr = X - hzb - 64 + 2;
wire [ 9:0] yr = Y - vtb - 8;

// Итоговый цвет
wire [11:0] dstcolor = 
    color == 4'h0 ? 12'h111 :
    color == 4'h1 ? 12'h008 :
    color == 4'h2 ? 12'h080 :
    color == 4'h3 ? 12'h088 :
    color == 4'h4 ? 12'h800 :
    color == 4'h5 ? 12'h808 :
    color == 4'h6 ? 12'h880 :
    color == 4'h7 ? 12'hccc :
    color == 4'h8 ? 12'h888 :
    color == 4'h9 ? 12'h00f :
    color == 4'hA ? 12'h000 :
    color == 4'hB ? 12'h0ff :
    color == 4'hC ? 12'hff0 :
    color == 4'hD ? 12'hf0f :
    color == 4'hE ? 12'hf00 :
                    12'hfff;

always @(posedge CLOCK) begin

    // Кадровая развертка
    X <= xmax ?         0 : X + 1;
    Y <= xmax ? (ymax ? 0 : Y + 1) : Y;
    
    case (xr[0])
        
        // 4000h - 9FFFh Видеопамять 
        0: vaddr <= 16'h4000 + {/*8*/ yr[8:1], /*7*/xr[8:2]}; 
        1: color <= xr[1] ? vdata[3:0] : vdata[7:4];
        
    endcase

    // Вывод окна видеоадаптера
    if (X >= hzb && X < hzb + hzv && Y >= vtb && Y < vtb + vtv)
    begin
    
        // Область экрана
        if (x >= 64 && x < 64 + 512 && y >= 8 && y < 8 + 384)        
            {VGA_R, VGA_G, VGA_B} <= dstcolor;  // Бумага
        else
            {VGA_R, VGA_G, VGA_B} <= border;    // Бордер
         
    end
    else {VGA_R, VGA_G, VGA_B} <= 12'b0;

end

endmodule