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

initial begin o_data = 0; we = 0; end

// Выбор текущего положения указателя в память
assign address = select ? cursor : pc;

reg [15:0]  pc          = 16'h0000;
reg [ 7:0]  ir          = 8'h00;
reg [ 3:0]  phase       = 1'b0;
reg         select      = 1'b0;
reg [15:0]  cursor      = 16'h0000;
wire [7:0]  opcode      = phase ? ir : i_data;

// Регистровый файл
reg  [15:0] bc = 16'h0005;
reg  [15:0] de = 16'h0000;
reg  [15:0] hl = 16'h0004;
reg  [15:0] af = 16'hE123;
reg  [15:0] sp = 16'h0000;

reg  [15:0] bc_prime = 16'h0000;
reg  [15:0] de_prime = 16'h0000;
reg  [15:0] hl_prime = 16'h0000;
reg  [15:0] af_prime = 16'h5423;

// -----------------------------------------------------------------------------

always @(posedge clock)
// Нажата кнопка сброса процессора
if (resetn == 1'b0) begin phase <= 0; pc <= 0; end
// Процессор в данный момент работает, если locked
else if (locked) begin

    // Прочитать первый опкод
    if (phase == 0) begin 
    
        ir <= i_data; 
        pc <= pc + 1; 
        
    end
    
    we <= 0;
    
    casex (opcode)
    
        // 1T EX AF, AF'
        8'b0000_1000: begin af <= af_prime; af_prime <= af; phase <= 0; end
        
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
                0: bc[15:8] <= i_data; 1: bc[7:0] <= i_data;
                2: de[15:8] <= i_data; 3: de[7:0] <= i_data;
                4: hl[15:8] <= i_data; 5: hl[7:0] <= i_data;
                6: o_data   <= i_data; 7: af[15:8] <= i_data;
                endcase

            end            
            2: begin phase <= 0; we <= 0; end
        
        endcase

    endcase
    
end

endmodule
