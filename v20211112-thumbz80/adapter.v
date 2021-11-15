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
wire [ 9:0] xr = x - 64 + 2;
wire [ 9:0] yr = y - 8;

always @(posedge CLOCK) begin

    // Кадровая развертка
    X <= xmax ?         0 : X + 1;
    Y <= xmax ? (ymax ? 0 : Y + 1) : Y;
    
    case (xr[0])
        
        // 4000h - 9FFFh Видеопамять 
        0: vaddr <= {2'b10, yr[7:1], xr[7:2]}; 
        1: color <= xr[1] ? vdata[3:0] : vdata[7:4];
        
    endcase

    // Вывод окна видеоадаптера
    if (X >= hzb && X < hzb + hzv && Y >= vtb && Y < vtb + vtv)
    begin
    
        // Область экрана
        if (x >= 64 && x < 64 + 512 && y >= 8 && y < 8 + 384)
            {VGA_R, VGA_G, VGA_B} <= 
            color == 8 ? 12'h888 : // 8-й цвет серый
            {
                {color[3] & color[2], {3{color[2]}}}, // R
                {color[3] & color[1], {3{color[1]}}}, // G
                {color[3] & color[0], {3{color[0]}}}  // B
            };
                    
        else
            {VGA_R, VGA_G, VGA_B} <= border; // Бордер
         
    end
    else {VGA_R, VGA_G, VGA_B} <= 12'b0;

end

endmodule