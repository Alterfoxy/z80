/**
 * Thumb Z80
 * Процессор с сокращенным набором инструкции
 */

module tz80
(
    // Стандартный интерфейс
    input   wire        clock,
    input   wire        resetn,
    input   wire        locked,
    output  wire [15:0] address,
    input   wire [ 7:0] i_data,
    output  reg  [ 7:0] o_data,
    output  reg         we
);
// -----------------------------------------------------------------------------

initial begin o_data = 0; we = 0; end

// Выбор текущего положения указателя в память
assign address = select ? cursor : pc;

localparam
    CF = 0, NF = 1, PF = 2, F3F = 3, HF = 4, F5F = 5, ZF = 6, SF = 7;

localparam
    alu_add = 0, alu_rlc =  8, alu_inc = 16, alu_rlca = 24,
    alu_adc = 1, alu_rrc =  9, alu_dec = 17, alu_rrca = 25,
    alu_sub = 2, alu_rl  = 10,               alu_rla  = 26,
    alu_sbc = 3, alu_rr  = 11,               alu_rra  = 27,
    alu_and = 4, alu_sla = 12, alu_daa = 20, alu_bit  = 28,
    alu_xor = 5, alu_sra = 13, alu_cpl = 21, alu_set  = 29,
    alu_or  = 6, alu_sll = 14, alu_scf = 22, alu_res  = 30,
    alu_cp  = 7, alu_srl = 15, alu_ccf = 23;    
// -----------------------------------------------------------------------------

reg [15:0]  pc          = 16'h0000;
reg [ 7:0]  ir          = 8'h00;
reg [ 3:0]  phase       = 1'b0;
reg         select      = 1'b0;
reg [15:0]  cursor      = 16'h0000;
wire [7:0]  opcode      = phase ? ir : i_data;

reg  [4:0] alu_m;   // Режим работы АЛУ
reg  [7:0] op1;     // Операнды
reg  [7:0] op2;

// Регистровый файл
reg  [15:0] bc = 16'h1405;
reg  [15:0] de = 16'h3010;
reg  [15:0] hl = 16'h0004;
reg  [15:0] af = 16'hE123;
reg  [15:0] sp = 16'h0000;

reg  [15:0] bc_prime = 16'h0000;
reg  [15:0] de_prime = 16'h0000;
reg  [15:0] hl_prime = 16'h0000;
reg  [15:0] af_prime = 16'h5423;

// -----------------------------------------------------------------------------
wire [7:0]  r20 = // Регистр, получаемый из опкода[2:0]
    opcode[2:0] == 3'h0 ? bc[15:8] :
    opcode[2:0] == 3'h1 ? bc[ 7:0] :
    opcode[2:0] == 3'h2 ? de[15:8] :
    opcode[2:0] == 3'h3 ? de[ 7:0] :
    opcode[2:0] == 3'h4 ? hl[15:8] :
    opcode[2:0] == 3'h5 ? hl[ 7:0] :
    opcode[2:0] == 3'h6 ? i_data : 
                          af[15:8];
                          
wire [7:0]  r53 = // Регистр, получаемый из опкода[5:3]
    opcode[5:3] == 3'h0 ? bc[15:8] :
    opcode[5:3] == 3'h1 ? bc[ 7:0] :
    opcode[5:3] == 3'h2 ? de[15:8] :
    opcode[5:3] == 3'h3 ? de[ 7:0] :
    opcode[5:3] == 3'h4 ? hl[15:8] :
    opcode[5:3] == 3'h5 ? hl[ 7:0] :
    opcode[5:3] == 3'h6 ? i_data : 
                          af[15:8];    

// -----------------------------------------------------------------------------
// Модуль АЛУ
// -----------------------------------------------------------------------------

wire zf8 = alu_r[7:0]==0;           // Zero
wire pf8 = ~^alu_r[7:0];            // Parity
wire sf8 = alu_r[7];                // Sign
wire cf8 = alu_r[8];                // Carry
wire f58 = alu_r[5];                // H5 Undocumented
wire f38 = alu_r[3];                // H3 Undocumented
wire hf8 = alu_r[4]^op1[4]^op2[4];  // Half-Carry
wire oa8 = (op1[7] == op2[7]) & (op1[7] != alu_r[7]);
wire os8 = (op1[7] != op2[7]) & (op1[7] != alu_r[7]);

// Специальный расчет флага H
wire [4:0] ha8 = op1[3:0] + op2[3:0] + af[CF];
wire [4:0] hs8 = op1[3:0] - op2[3:0] - af[CF];

// Вычисление результата
wire [8:0] alu_r =
    alu_m == alu_add  ? op1 + op2 :
    alu_m == alu_adc  ? op1 + op2 + af[CF] :
    alu_m == alu_sub  ? op1 - op2 :
    alu_m == alu_sbc  ? op1 - op2 - af[CF] :
    alu_m == alu_and  ? op1 & op2 :
    alu_m == alu_xor  ? op1 ^ op2 :
    alu_m == alu_or   ? op1 | op2 :
    alu_m == alu_cp   ? op1 - op2 :
    alu_m == alu_inc  ? op1 + op2 :
    alu_m == alu_dec  ? op1 - op2 :
    // Сдвиговые операции
    alu_m == alu_rlca || alu_m == alu_rlc ? {op1[6:0], op1[7]}   : // a << 1
    alu_m == alu_rrca || alu_m == alu_rrc ? {op1[0],   op1[7:1]} : // a >> 1
    alu_m == alu_rla  || alu_m == alu_rl  ? {op1[6:0], af[CF]}   : // a << 1
    alu_m == alu_rra  || alu_m == alu_rr  ? {af[CF],   op1[7:1]} : // a >> 1
    alu_m == alu_sla ? {op1[6:0], 1'b0}   : // a << 1
    alu_m == alu_sll ? {op1[6:0], 1'b1}   : // a << 1
    alu_m == alu_sra ? {op1[7], op1[7:1]} : // a >> 1
    alu_m == alu_srl ? {1'b0,   op1[7:1]} : // a >> 1
    // Коррекции
    alu_m == alu_daa  ? daa_2 :
    alu_m == alu_cpl  ? ~op1 :
    // Все остальные
    op1;

// Результат флаговых вычислений [S Z F5 H F3 P/V N C]
wire [7:0] alu_f =

    // Группа ADD, ADC
    (alu_m == alu_add) ? {sf8, zf8, f58,    hf8,    f38,    oa8, 1'b0, cf8} :
    (alu_m == alu_adc) ? {sf8, zf8, f58,    ha8[4], f38,    oa8, 1'b0, cf8} :
    (alu_m == alu_sbc) ? {sf8, zf8, f58,    hs8[4], f38,    os8, 1'b1, cf8} :
    (alu_m == alu_sub) ? {sf8, zf8, f58,    hf8,    f38,    os8, 1'b1, cf8} :
    (alu_m == alu_cp)  ? {sf8, zf8, op2[5], hf8,    op2[3], os8, 1'b1, cf8} :
    // Для AND выставляет H=1
    (alu_m == alu_and) ? {sf8, zf8, f58, 1'b1, f38, pf8, 2'b00} :
    // Другие логические (XOR|OR)
    (alu_m == alu_xor || alu_m == alu_or) ? {sf8, zf8, f58, 1'b0, f38, pf8, 2'b00} :
    // INC, DEC не меняют флаг CF
    (alu_m == alu_inc)  ? {sf8, zf8, f58, hf8, f38, oa8, 1'b0, af[CF]} :
    (alu_m == alu_dec)  ? {sf8, zf8, f58, hf8, f38, os8, 1'b1, af[CF]} :
    // Сдвиговые
    (alu_m == alu_rlca || alu_m == alu_rla) ?
        {af[SF], af[ZF], f58, 1'b0, f38, af[PF], 1'b0, op1[7]} :

    (alu_m == alu_rrca || alu_m == alu_rra) ?
        {af[SF], af[ZF], f58, 1'b0, f38, af[PF], 1'b0, op1[0]} :

    (alu_m == alu_rlc || alu_m == alu_rl || alu_m == alu_sla || alu_m == alu_sll) ?
        {sf8, zf8, f58, 1'b0, f38, pf8, 1'b0, op1[7]} :

    (alu_m == alu_rrc || alu_m == alu_rr || alu_m == alu_sra || alu_m == alu_srl) ?
        {sf8, zf8, f58, 1'b0, f38, pf8, 1'b0, op1[0]} :

    // Специальные
    (alu_m == alu_daa) ? {sf8, zf8, f58, af[4]^daa_2[4], f38, pf8, af[NF], daa_cf} :
    (alu_m == alu_cpl) ? {af[SF], af[ZF], f58, 1'b1,   f38, af[PF], 1'b1, af[CF]} :
    (alu_m == alu_scf) ? {af[SF], af[ZF], f58, 1'b0,   f38, af[PF], 1'b0, 1'b1} :
    (alu_m == alu_ccf) ? {af[SF], af[ZF], f58, af[CF], f38, af[PF], 1'b0, ~af[CF]} :

    // Все остальные
        af[15:8];

// DAA
// -----------------------------------------------------------------------------

wire daa_hf = af[HF] | (af[3:0] > 8'h09);
wire daa_cf = af[CF] | (af[7:0] > 8'h99);

// Первый этап
wire [7:0] daa_1 =
    af[NF] ? (daa_hf ? af[7:0] - 6 : af[7:0]) : // SUB
             (daa_hf ? af[7:0] + 6 : af[7:0]);  // ADD

// Второй этап
wire [7:0] daa_2 =
    af[NF] ? (daa_cf ? daa_1 - 16'h60 : daa_1) : // SUB
             (daa_cf ? daa_1 + 16'h60 : daa_1);  // ADD

// -----------------------------------------------------------------------------

always @(posedge clock)
// Нажата кнопка сброса процессора
if (resetn == 1'b0) begin phase <= 0; pc <= 0; end
// Процессор в данный момент работает, если locked
else if (locked) begin

    we <= 0;
    
    // Прочитать первый опкод
    if (phase == 0) begin 
    
        ir <= i_data; 
        pc <= pc + 1; 
        
    end
    
    casex (opcode)
    
        // 1T EX AF, AF'
        8'b0000_1000: begin af <= af_prime; af_prime <= af; end
        
        // 3T LD r16, imm
        8'b00xx_0001: case (phase)

            0: begin phase <= 1; end
            1: begin 

                pc <= pc + 1; 
                phase <= 2;
                
                // Загрузка в LOW
                case (opcode[5:4])
                2'b00: bc[7:0] <= i_data;
                2'b01: de[7:0] <= i_data;
                2'b10: hl[7:0] <= i_data;
                2'b11: sp[7:0] <= i_data;
                endcase
                
            end
            2: begin 
            
                pc <= pc + 1; 
                phase <= 0;
                
                // Загрузка в HIGH
                case (opcode[5:4])
                2'b00: bc[15:8] <= i_data;
                2'b01: de[15:8] <= i_data;
                2'b10: hl[15:8] <= i_data;
                2'b11: sp[15:8] <= i_data;
                endcase
         
                
            end
                        
        endcase
    
        // 2T LD (BC|DE), A
        8'b000x_0010: case (phase)
        
            0: begin 
            
                phase   <= 1; 
                select  <= 1;
                cursor  <= opcode[4] ? de : bc;
                we      <= 1;
                o_data  <= af[15:8];
                
            end
            1: begin
            
                phase <= 0;
                select <= 0;
                
            end
        
        endcase
    
        // 1T INC/DEC r16
        8'b0000_0011: bc <= bc + 1; 8'b0000_1011: bc <= bc - 1; 
        8'b0001_0011: de <= de + 1; 8'b0001_1011: de <= de - 1;
        8'b0010_0011: hl <= hl + 1; 8'b0010_1011: hl <= hl - 1;
        8'b0011_0011: sp <= sp + 1; 8'b0010_1011: sp <= sp - 1;
        
        // 2T LD r, i8
        // 3T LD (HL), i8
        8'b00xx_x110: case (phase)
        
            0: begin phase <= 1; end
            1: begin 

                pc     <= pc + 1;
                phase  <= opcode[5:3] == 3'b110 ? 2 : 0;
                we     <= opcode[5:3] == 3'b110 ? 1 : 0;
                cursor <= hl;
                
                // Загрузка в регистры или в память
                case (opcode[5:3])
                0: bc[15:8] <= i_data; 1: bc[ 7:0] <= i_data;
                2: de[15:8] <= i_data; 3: de[ 7:0] <= i_data;
                4: hl[15:8] <= i_data; 5: hl[ 7:0] <= i_data;
                6: o_data   <= i_data; 7: af[15:8] <= i_data;
                endcase

            end            
            2: begin phase <= 0; we <= 0; select <= 0; end
        
        endcase
        
        // 1T HALT
        8'b0111_0110: begin pc <= pc; end
        
        // 2T LD r, (HL)
        8'b01xx_x110: case (phase)
        
            0: begin phase <= 1; select <= 1; cursor <= hl; end
            1: begin 

                case (opcode[5:3])
                0: bc[15:8] <= i_data; 1: bc[ 7:0] <= i_data;
                2: de[15:8] <= i_data; 3: de[ 7:0] <= i_data;
                4: hl[15:8] <= i_data; 5: hl[ 7:0] <= i_data;
                7: af[15:8] <= i_data;
                endcase
                
                phase  <= 0;
                select <= 0;
            
            end

        endcase

        // 1T LD r, r
        // 2T LD (HL), r
        8'b01xx_xxxx: case (phase)
        
            0: begin
            
                cursor <= hl;
            
                case (opcode[5:3])
                0: bc[15:8] <= r20; 1: bc[ 7:0] <= r20;
                2: de[15:8] <= r20; 3: de[ 7:0] <= r20;
                4: hl[15:8] <= r20; 5: hl[ 7:0] <= r20;
                6: o_data   <= r20; 7: af[15:8] <= r20;
                endcase
                
                // LD (HL), r
                if (opcode[5:3] == 3'h6) begin
                
                    we      <= 1;
                    select  <= 1;
                    phase   <= 1;
                    
                end
                // LD r, r
                else phase <= 0;

            end
            1: begin we <= 0; phase <= 0; select <= 0; end
        
        endcase

        // 2T ALU r
        // 3T ALU (HL)
        8'b10xx_xxxx: case (phase)
        
            0: begin 

                phase   <= opcode[2:0] == 6 ? 1 : 2; 
                select  <= opcode[2:0] == 6 ? 1 : 0;
                alu_m   <= opcode[5:3];
                op1     <= af[15:8];
                op2     <= r20;
                cursor  <= hl;

            end            
            1: begin phase <= 2; op2 <= i_data; select <= 0; end
            2: begin 
            
                phase   <= 0;               
                af[7:0] <= alu_f;

                if (opcode[5:3] != 3'h7) af[15:8] <= alu_r[7:0];
            
            end
        
        endcase

    endcase
    
end

endmodule
