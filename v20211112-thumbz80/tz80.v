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

assign address = select ? cursor : pc;

initial begin o_data = 0; we = 0; end

wire accept = loadedir[1] & (phase == 0);

reg [15:0]  pc = 16'h0000;
reg [ 7:0]  ir;
reg [ 7:0]  opcode;
reg [ 1:0]  loadedir    = 1'b0;
reg [ 3:0]  phase       = 1'b0;
reg [15:0]  cursor;
reg         select = 1'b0;

// Регистровый файл
reg  [15:0] bc = 16'h0005;
reg  [15:0] de = 16'h0000;
reg  [15:0] hl = 16'hEAB5;
reg  [15:0] af = 16'hE123;
reg  [15:0] sp = 16'h0000;

reg  [15:0] bc_prime = 16'h0000;
reg  [15:0] de_prime = 16'h0000;
reg  [15:0] hl_prime = 16'h0000;
reg  [15:0] af_prime = 16'h5423;

// Текущий IR
wire [7:0]  cir = loadedir == 3 ? opcode : ir;

always @(posedge clock)
// Нажата кнопка сброса процессора
if (resetn == 1'b0) begin phase <= 0; loadedir <= 0; pc <= 0; end
// Процессор в данный момент работает, если locked
else if (locked) begin

    // Загрузка в конвейер
    ir <= i_data;
    pc <= pc + 1;
    we <= 0;

    // Предзагрузка IR
    if (loadedir[1] == 1'b0) loadedir <= loadedir + 1;
    else begin

        // Сохранение опкода
        if (loadedir == 2) opcode <= ir;

        // Исполнение инструкции
        casex (cir)

            // 1T | EX AF,AF' Обмен регистровыми парами
            8'b0000_1000: begin af <= af_prime; af_prime <= af; end

            // 3T | LD r16, imm16
            8'b00xx_0001: case (phase)

                // Загрузка младшего байта
                0: begin

                    loadedir <= 3;
                    phase    <= 1;

                    case (cir[5:4])

                        0: bc[7:0] <= i_data;
                        1: de[7:0] <= i_data;
                        2: hl[7:0] <= i_data;
                        3: sp[7:0] <= i_data;

                    endcase

                end

                // Загрузка старшего байта
                1: begin

                    loadedir <= 1; // Перейти к предзагрузке
                    phase    <= 0;

                    case (cir[5:4])

                        0: bc[15:8] <= i_data;
                        1: de[15:8] <= i_data;
                        2: hl[15:8] <= i_data;
                        3: sp[15:8] <= i_data;

                    endcase

                end

            endcase

            // 4T | LD (BC|DE), A
            8'b000x_0010: case (phase)

                0: begin

                    phase    <= 1;
                    select   <= 1;
                    loadedir <= 3;
                    cursor   <= cir[4] ? de : bc;
                    we       <= 1;
                    o_data   <= af[15:8];

                end

                1: begin

                    phase    <= 0;
                    select   <= 0;
                    pc       <= pc - 2;
                    loadedir <= 0;

                end

            endcase

            // 4T | LD A, (BC|DE)
            8'b000x_1010: case (phase)

                0: begin

                    phase    <= 1;
                    select   <= 1;
                    loadedir <= 3;
                    cursor   <= cir[4] ? de : bc;

                end
                1: begin

                    phase   <= 2;
                    select  <= 0;        // Выбор шины PC
                    pc      <= pc - 2;   // Предзагрузка IR

                end
                2: begin

                    phase    <= 0;
                    af[15:8] <= i_data;
                    loadedir <= 1;

                end

            endcase

            // 1T | INC/DEC r16
            8'b0000_0011: bc <= bc + 1;
            8'b0000_1011: bc <= bc - 1;
            8'b0001_0011: de <= de + 1;
            8'b0001_1011: de <= de - 1;
            8'b0010_0011: hl <= hl + 1;
            8'b0010_1011: hl <= hl - 1;
            8'b0011_0011: sp <= sp + 1;
            8'b0011_1011: sp <= sp - 1;

            // 4T | LD (HL), i8
            8'b0011_0110: case (phase)

                0: begin

                    phase    <= 1;
                    select   <= 1;
                    loadedir <= 3;
                    cursor   <= hl;
                    we       <= 1;
                    o_data   <= i_data;

                end

                1: begin

                    phase    <= 0;
                    select   <= 0;
                    pc       <= pc - 1;
                    loadedir <= 0;

                end

            endcase

            // 2T | LD r8, i8
            8'b00xx_x110: begin

                case (cir[5:3])

                    0: bc[15:8] <= i_data;
                    1: bc[ 7:0] <= i_data;
                    2: de[15:8] <= i_data;
                    3: de[ 7:0] <= i_data;
                    4: hl[15:8] <= i_data;
                    5: hl[ 7:0] <= i_data;
                    7: af[15:8] <= i_data;

                endcase

                loadedir <= 1;

            end

            // 3T | JR *
            8'b0001_1000: begin

                loadedir <= 0;
                pc <= pc + {{8{i_data[7]}}, i_data[7:0]};

            end

        endcase

    end

end

endmodule