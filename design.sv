module AHB_Slave_2 #(
    parameter MEM_WIDTH = 8,
    parameter MEM_DEPTH = 64
)(
    input logic HCLK,
    input logic HRESETn,

    // Input from master
    input logic [31:0] HADDR,
    input logic [31:0] HWDATA,

    // Input from decoder
    input logic [1:0] HSELx_slaves,

    // Control signals
    input logic HWRITE,
    input logic [2:0] HSIZE,
    input logic [1:0] HTRANS,
    input logic [2:0] HBURST,
    input logic HREADY,

    // Outputs to MUX
    output logic HREADYOUT,
    output logic HRESP,
    output logic [31:0] HRDATA
);

    // FSM States
    typedef enum logic [1:0] {
        IDLE,
        WRITE,
        READ
    } state_t;

    state_t curr_state, next_state;

    // Memory_2 declaration
    logic [MEM_WIDTH-1:0] memory_2 [MEM_DEPTH-1:0];

    // Internal registers for address phase capture
    logic [31:0] HADDR_reg;
    logic HWRITE_reg;
    logic [2:0] HSIZE_reg;
    logic [1:0] HTRANS_reg;
    logic [2:0] HBURST_reg;

    // internal signlas
    logic [31:0] HADDR_Half; // address that incerements the HADDR by 1 to write 16 bits
    logic [31:0] HADDR_Full_1; // address that incerements the HADDR by 1 to write 32 bits
    logic [31:0] HADDR_Full_2; // address that incerements the HADDR by 2 to write 32 bits
    logic [31:0] HADDR_Full_3; // address that incerements the HADDR by 3 to write 32 bits

    // FSM Sequential Logic
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    // FSM Combinational Logic
    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE: begin
                if (HREADY && HSELx_slaves == 2'b01 && (HTRANS == 2'b10 || HTRANS == 2'b11)) begin
                    if (HWRITE) next_state = WRITE;
                    else        next_state = READ;
                end
            end
            WRITE: begin
                if (!(HTRANS == 2'b10 || HTRANS == 2'b11)) next_state = IDLE;  // If not in valid transfer state, go to IDLE
                else if (!HWRITE) next_state = READ;
                else next_state = WRITE;
            end
            READ: begin
                if (!(HTRANS == 2'b10 || HTRANS == 2'b11)) next_state = IDLE;
                else if (HWRITE) next_state = WRITE; // If write request comes, switch to WRITE state
                else next_state = READ;
            end
        endcase
    end

    
    // output logic
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HRDATA    <= 32'h0;
            HREADYOUT <= 1'b1;
            HRESP     <= 1'b0;
        end
        else begin

            if (next_state == READ) begin
                if ((HBURST == 3'b000 || HBURST == 3'b001)) begin
                    case (HSIZE)
                        3'b000: begin // 8-bit
                            HRDATA <= {24'h000000, memory_2[HADDR[29:0]]}; // Read 8 bits from memory_2
                        end
                        3'b001: begin // 16-bit
                            HRDATA <= {16'h0000, memory_2[HADDR_Half], memory_2[HADDR[29:0]]}; // Read 16 bits from memory_2
                        end
                        3'b010: begin // 32-bit
                            HRDATA <= {memory_2[HADDR_Full_3], memory_2[HADDR_Full_2], memory_2[HADDR_Full_1], memory_2[HADDR[29:0]]}; // Read 32 bits from memory_2
                        end
                    endcase
                end
            end

            else if (curr_state == WRITE) begin
                if ((HBURST_reg == 3'b000 || HBURST_reg == 3'b001)) begin
                    case (HSIZE_reg)
                        3'b000: begin // 8-bit
                            memory_2[HADDR_reg[29:0]] <= HWDATA[7:0];
                        end
                        3'b001: begin // 16-bit
                            memory_2[HADDR_reg[29:0]] <= HWDATA[7:0]; // Write 8 bits to memory_2
                            memory_2[HADDR_Half] <= HWDATA[15:8]; // Write next 8 bits to memory_2
                        end
                        3'b010: begin // 32-bit
                            memory_2[HADDR_reg[29:0]] <= HWDATA[7:0]; // Write first 8 bits to memory_2
                            memory_2[HADDR_Full_1] <= HWDATA[15:8]; // Write next 8 bits to memory_2
                            memory_2[HADDR_Full_2] <= HWDATA[23:16]; // Write next 8 bits to memory_2
                            memory_2[HADDR_Full_3] <= HWDATA[31:24]; // Write last 8 bits to memory_2
                        end
                    endcase
                end
            end

        end
        
    end


    // always block for address to respect address phase and data phase and to enable pipelining in the address
    always_ff @(posedge HCLK) begin
        if (HREADY && HSELx_slaves == 2'b01) begin  // so if not ready the value of the prev. address will be stored in HADDR_reg (wait states)
            HADDR_reg   <= HADDR;
            HWRITE_reg  <= HWRITE;
            HSIZE_reg   <= HSIZE;
            HTRANS_reg  <= HTRANS;
            HBURST_reg  <= HBURST;
        end
    end


    // always block for address managing to respect wait states
    always @(*) begin
        if (HREADY) begin
            // write transfer
            if (HWRITE) begin
                HADDR_Half = HADDR_reg[29:0] + 1; // Half address for 16 bits transfer, incerement by 1 
                HADDR_Full_1 =  HADDR_reg[29:0] + 1; // Full address for 32 bits transfer, incerement by 1
                HADDR_Full_2 =  HADDR_reg[29:0] + 2;  // Full address for 32 bits transfer incerement by 2
                HADDR_Full_3 =  HADDR_reg[29:0] + 3; // Full address for 32 bits transfer, incerement by 3
            end
            // read transfer
            else begin
                HADDR_Half = HADDR[29:0] + 1; // Half address for 16 bits transfer, incerement by 1 
                HADDR_Full_1 =  HADDR[29:0] + 1; // Full address for 32 bits transfer, incerement by 1
                HADDR_Full_2 =  HADDR[29:0] + 2;  // Full address for 32 bits transfer incerement by 2
                HADDR_Full_3 =  HADDR[29:0] + 3; // Full address for 32 bits transfer, incerement by 3
            end
        end
    end
endmodule

module AHB_Slave_1 #(
    parameter MEM_WIDTH = 8 , parameter MEM_DEPTH = 1024 // I chose 128 bits for the width as 128 = 32*4 to enable transfers of 8 bits size 
) (
    // Global Signals
    input HCLK,
    input HRESETn,
    // input from master
    input [31:0] HADDR,
    input [31:0] HWDATA,
    // input from decoder
    input [1:0] HSELx_slaves,
    // control signals
    input HWRITE,
    input [2:0] HSIZE,
    input [1:0] HTRANS,
    input [2:0] HBURST,
    input HREADY,
    // output to MUX
    output logic HREADYOUT,
    output logic HRESP,
    output logic [31:0] HRDATA // Read data to master
);
    // we made this salve as a memory to test read and write operations
    logic [MEM_WIDTH-1:0] memory [MEM_DEPTH-1:0]; // Memory array

    // internal signlas
    logic [31:0] HADDR_Half; // address that incerements the HADDR by 1 to write 16 bits
    logic [31:0] HADDR_Full_1; // address that incerements the HADDR by 1 to write 32 bits
    logic [31:0] HADDR_Full_2; // address that incerements the HADDR by 2 to write 32 bits
    logic [31:0] HADDR_Full_3; // address that incerements the HADDR by 3 to write 32 bits


    // storing all control signals to use them in write states as control signals are sent first then data (address phase & data phase)
    logic [31:0] HADDR_reg; // to store the address value to use it in write states as control signals are sent first then data (address phase & data phase)
    logic HWRITE_reg; // to store write control signal value to use it in write states as control signals are sent first then data (address phase & data phase)
    logic [2:0] HSIZE_reg; // to store the size of the transfer to use it in write states as control signals are sent first then data (address phase & data phase)
    logic [1:0] HTRANS_reg; // to store the type of transfer to use it in write states as control signals are sent first then data (address phase & data phase)
    logic [2:0] HBURST_reg; // to store the burst type to use it in write states as control signals are sent first then data (address phase & data phase)



    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HREADYOUT <= 1'b1; // Initially ready
            HRESP <= 1'b0; // No error response
            HRDATA <= 32'h00000000; // Default read data
        end

        // choose salve 1
        else if (!HSELx_slaves && HREADY) begin // select Slave 1 if HSELx is 2'b00

            // Write operation for both single and incermental burst transfers (HBURST = 0 or HBURST = 1)
            if (HWRITE_reg && (HTRANS_reg == 2'b10 || HTRANS_reg == 2'b11)) begin // as the state is NONSEQ or SEQ we can write
                // 8 bits transfer 
                if ((HBURST_reg == 3'b000 || HBURST_reg == 3'b001) && HSIZE_reg == 3'b000) begin 
                    memory[HADDR_reg[29:0]] <= HWDATA[7:0]; // Write 8 bits to memory
                end 
                // 16 bits transfer 
                else if ((HBURST_reg == 3'b000 || HBURST_reg == 3'b001) && HSIZE_reg == 3'b001) begin // 16 bits transfer
                    memory[HADDR_reg[29:0]] <= HWDATA[7:0]; // Write 8 bits to memory
                    memory[HADDR_Half] <= HWDATA[15:8]; // Write next 8 bits to memory
                end 
                // 32 bits transfer 
                else if ((HBURST_reg == 3'b000 || HBURST_reg == 3'b001) && HSIZE_reg == 3'b010) begin // 32 bits transfer
                    memory[HADDR_reg[29:0]] <= HWDATA[7:0]; // Write first 8 bits to memory
                    memory[HADDR_Full_1] <= HWDATA[15:8]; // Write next 8 bits to memory
                    memory[HADDR_Full_2] <= HWDATA[23:16]; // Write next 8 bits to memory
                    memory[HADDR_Full_3] <= HWDATA[31:24]; // Write last 8 bits to memory
                end
            end
            // Read operation for both single and incermental burst transfers (HBURST = 0 or HBURST = 1) 
            else if (!HWRITE && (HTRANS == 2'b10 || HTRANS == 2'b11)) begin // as the state is NONSEQ or SEQ we can read
                // 8 bits transfer 
                if ((HBURST == 3'b000 || HBURST == 3'b001) && HSIZE == 3'b000) begin 
                    HRDATA <= {24'h000000, memory[HADDR[29:0]]}; // Read 8 bits from memory
                end 
                // 16 bits transfer 
                else if ((HBURST == 3'b000 || HBURST == 3'b001) && HSIZE == 3'b001) begin // 16 bits transfer
                    HRDATA <= {16'h0000, memory[HADDR_Half], memory[HADDR[29:0]]}; // Read 16 bits from memory
                end 
                // 32 bits transfer 
                else if ((HBURST == 3'b000 || HBURST == 3'b001) && HSIZE == 3'b010)  begin // 32 bits transfer
                    HRDATA <= {memory[HADDR_Full_3], memory[HADDR_Full_2], memory[HADDR_Full_1], memory[HADDR[29:0]]}; // Read 32 bits from memory
                end
            end
        end
    end

    // always block for address to respect address phase and data phase and to enable pipelining in the address
    always @(posedge HCLK) begin
        if (HREADY) begin 
            HADDR_reg <= HADDR; // so if not ready the value of the prev. address will be stored in HADDR_reg (wait states)
            HWRITE_reg <= HWRITE;
            HSIZE_reg <= HSIZE;
            HBURST_reg <= HBURST;
            HTRANS_reg <= HTRANS;
        end
    end

    // always block for address managing to respect wait states
    always @(*) begin
        if (HREADY) begin
            // write transfer
            if (HWRITE) begin
                HADDR_Half = HADDR_reg[29:0] + 1; // Half address for 16 bits transfer, incerement by 1 
                HADDR_Full_1 =  HADDR_reg[29:0] + 1; // Full address for 32 bits transfer, incerement by 1
                HADDR_Full_2 =  HADDR_reg[29:0] + 2;  // Full address for 32 bits transfer incerement by 2
                HADDR_Full_3 =  HADDR_reg[29:0] + 3; // Full address for 32 bits transfer, incerement by 3
            end
            // read transfer
            else begin
                HADDR_Half = HADDR[29:0] + 1; // Half address for 16 bits transfer, incerement by 1 
                HADDR_Full_1 =  HADDR[29:0] + 1; // Full address for 32 bits transfer, incerement by 1
                HADDR_Full_2 =  HADDR[29:0] + 2;  // Full address for 32 bits transfer incerement by 2
                HADDR_Full_3 =  HADDR[29:0] + 3; // Full address for 32 bits transfer, incerement by 3
            end
        end
    end
endmodule

module AHB_MUX (
    // inputs from slave 1
    input HRESP_Slave_1, // response from first slave
    input HREADYOUT_1, // ready signal from first slave
    input [31:0] HRDATA_Slave_1, // read data from first slave

    // inputs from slave 2
    input HRESP_Slave_2, // response from second slave
    input HREADYOUT_2, // ready signal from second slave
    input [31:0] HRDATA_Slave_2, // read data from second slave


    // inputs from decoder
    input [1:0] HSELx_Mux, // Slave select signal

    // outputs
    output logic [31:0] HRDATA,
    output logic HREADY,
    output logic HRESP
);
    // to select between multiple slaves (we will insert more slaves later) 
    always @(*) begin
        case (HSELx_Mux)
            2'b00: begin
                HRDATA = HRDATA_Slave_1; // Read data from first slave
                HREADY = HREADYOUT_1; // Ready signal from mux ( to indicate the completeness of the transfer for other Slaves)
                HRESP = HRESP_Slave_1; // Response from first slave
            end
            2'b01: begin
                HRDATA = HRDATA_Slave_2; // Read data from first slave
                HREADY = HREADYOUT_2; // Ready signal from mux ( to indicate the completeness of the transfer for other Slaves)
                HRESP = HRESP_Slave_2; // Response from first slave
            end
            default: begin
                HRDATA = 32'h00000000; // Default case, can be modified as needed
                HREADY = 1'b0; // Default ready signal
                HRESP = 1'b0; // Default response signal
            end
        endcase
    end
endmodule

package ahb_pkg;
  typedef enum logic [1:0] { // for better visualization of the states
    // AHB states
    IDLE    = 2'b00,
    BUSY    = 2'b01,
    NONSEQ  = 2'b10,
    SEQ     = 2'b11
  } state_t;
endpackage


import ahb_pkg::*;

module AHB_Master (
    // Global Signals
    input HCLK,
    input HRESETn,
    // Processor signals (we will act as the Processor in the testbench)
    input [31:0] PADDR,
    input [31:0] PWDATA,
    input PWRITE,
    input [2:0] PSIZE,
    input [1:0] PTRANS,
    input [2:0] PBURST,
    // Transfer response (from mux)
    input HREADY, // to indicate the completeness of the transfer
    input HRESP,
    // Data
    input [31:0] HRDATA, // from slave
    // outputs
    output reg [31:0] HADDR, // note that the Most significant two bits are used to select which slave we will access
    output reg [31:0] HWDATA,
    output reg HWRITE,
    output reg [2:0] HSIZE,
    output reg [1:0] HTRANS,
    output reg [2:0] HBURST,
    output reg PDONE // just a flag to indicate the transfer is done
);
    // next state logic, cuurent state
    //reg [1:0] cs, ns;

    reg [31:0] HWDATA_reg; // to store the value of HWDATA_reg in case of wait state transfers

    state_t cs, ns;

    // state memory
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            cs <= IDLE;
        else 
            cs <= ns;
    end

    // next state logic
    always @(*) begin
        case (cs)
            IDLE: begin
                if (PTRANS == 2'b10) // Non-sequential transfer
                    ns = NONSEQ; // start new transfer
                else
                    ns = IDLE;
            end
            BUSY: begin
                if (PTRANS == 2'b11)
                    ns = SEQ; // Go to SEQ state if transfer is sequential
                else if (PTRANS == 2'b10) 
                    ns = NONSEQ; // Non-sequential transfer
                else if (PTRANS == 2'b00)
                    ns = IDLE; // go to IDLE if no transfer
                else
                    ns = BUSY; // Stay in BUSY state
            end
            NONSEQ: begin
                if (PTRANS == 2'b11)
                    ns = SEQ; // Sequential transfer
                else if (PTRANS == 2'b00)
                    ns = IDLE; // go to IDLE if no transfer (single transfer)
                else if (PTRANS == 2'b10 && PBURST == 3'b000) // to enable multiple Non-sequential transfer with single burst every cycle
                    ns = NONSEQ; // Stay in NONSEQ state
                else 
                    ns = SEQ; // Go to SEQ state
            end
            SEQ: begin
                if (PTRANS == 2'b00)
                    ns = IDLE; // go to IDLE if no transfer
                else if (PTRANS == 2'b10)
                    ns = NONSEQ; // Non-sequential transfer (start new transfer)
                else
                    ns = SEQ; // Stay in SEQ state
            end
        endcase
    end

    // output logic
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HADDR <= 32'b0;
            HWDATA_reg <= 32'b0;
            HWRITE <= 1'b0;
            HSIZE <= 3'b000; // 8-bit transfer
            HTRANS <= 2'b00; // IDLE state
            HBURST <= 3'b000; // Single transfer
        end 
        else begin
            if (cs == IDLE) begin
                HADDR <= 32'b0; 
                HWDATA_reg <= 32'b0; 
                HWRITE <= 1'b0; 
                HSIZE <= 3'b000; 
                HTRANS <= 2'b00;  
            end 
            else if (cs == BUSY) begin
                HADDR <= PADDR; 
                HWDATA_reg <= PWDATA; 
                HWRITE <= PWRITE; 
                HSIZE <= PSIZE; 
                HTRANS <= PTRANS; 
                HBURST <= PBURST; 
            end 
            else if (cs == NONSEQ) begin
                HADDR <= PADDR; 
                HWDATA_reg <= PWDATA; 
                HWRITE <= PWRITE; 
                HSIZE <= PSIZE; 
                HTRANS <= PTRANS; 
                HBURST <= PBURST; 
            end
            else if (cs == SEQ) begin
                if (PBURST == 3'b001 && !PSIZE) begin // INCREMENTAL burst, size is 8 bits so we will incerement address by 1
                    HADDR <= HADDR + 1 ; 
                    HWDATA_reg <= {24'h000000, PWDATA[7:0]}; 
                    HWRITE <= PWRITE; 
                    HSIZE <= PSIZE; 
                    HTRANS <= PTRANS; 
                    HBURST <= PBURST; 
                end
                else if (PBURST == 3'b001 && PSIZE == 3'b001) begin // INCREMENTAL burst, size is 16 bits so we will incerement address by 2
                    HADDR <= HADDR + 2 ; 
                    HWDATA_reg <= {16'h0000, PWDATA[15:0]}; 
                    HWRITE <= PWRITE; 
                    HSIZE <= PSIZE; 
                    HTRANS <= PTRANS; 
                    HBURST <= PBURST; 
                end
                else if (PBURST == 3'b001 && PSIZE == 3'b010) begin // INCREMENTAL burst, size is 32 bits so we will incerement address by 4
                    HADDR <= HADDR + 4 ; 
                    HWDATA_reg <= PWDATA; 
                    HWRITE <= PWRITE; 
                    HSIZE <= PSIZE; 
                    HTRANS <= PTRANS; 
                    HBURST <= PBURST; 
                end
                else if (!PBURST) begin // SINGLE transfer
                    HADDR <= PADDR; 
                    HWDATA_reg <= PWDATA; 
                    HWRITE <= PWRITE; 
                    HSIZE <= PSIZE; 
                    HTRANS <= PTRANS; 
                    HBURST <= PBURST; 
                end
            end
        end
    end

    // special always block to respect the data phase as data should come after address phase by on clock
    always @(posedge HCLK) begin
        if (HREADY) HWDATA <= HWDATA_reg;
    end

    // special always block for flag done
    always @(*) begin
        if ((cs == NONSEQ || cs == SEQ) && ns == IDLE) begin
            PDONE = 1'b1; // transfer is done
        end 
        else begin
            PDONE = 1'b0; // transfer is not done
        end
    end
endmodule

module AHB_Decoder (
    // inputs from master
    input [31:0] HADDR, // Address from master (Most significant two bits are used to select slave)
    // outputs
    output logic [1:0] HSELx_slaves, // Slave select signal
    output logic [1:0] HSELx_Mux // Slave select signal for MUX 
);

    // Decode the address to select the appropriate slave
    always @(*) begin
        case (HADDR[31:30]) // Using the two most significant bits for slave selection
            2'b00: HSELx_slaves = 2'b00; // Select Slave 1
            2'b01: HSELx_slaves = 2'b01; // Select Slave 2
            2'b10: HSELx_slaves = 2'b10; // Select Slave 3 
            2'b11: HSELx_slaves = 2'b11; // Select Slave 4 
            default: HSELx_slaves = 2'b00; // Default case, can be modified as needed
        endcase
        HSELx_Mux = HSELx_slaves; // Connect the slave select signal to the MUX
    end 
endmodule
module AHB_TOP (
    // Global Signals
    input HCLK,
    input HRESETn,
    // Processor signals (we will act as the Processor in the testbench)
    input [31:0] PADDR,
    input [31:0] PWDATA,
    input PWRITE,
    input [2:0] PSIZE,
    input [1:0] PTRANS,
    input [2:0] PBURST,
    output PDONE // just a flag to indicate the transfer is done (i added this to enable synthesis)
);
    // internal connections between master and slaves
    // from Master to slaves
    logic [31:0] HADDR;
    logic [31:0] HWDATA;
    logic HWRITE;
    logic [2:0] HSIZE;
    logic [1:0] HTRANS;
    logic [2:0] HBURST;
    logic HREADY;
    logic HRESP;
    logic HRESP_Slave_1;
    logic HRESP_Slave_2;
    
    // from Slave to Master
    logic HREADYOUT_1;
    logic HREADYOUT_2;

    // from Decoder 
    logic [1:0] HSELx_slaves; // Slave select signal
    logic [1:0] HSELx_Mux; // Slave select signal for MUX

    // from Slaves to Master
    logic [31:0] HRDATA;
    logic [31:0] HRDATA_1;
    logic [31:0] HRDATA_2;

    // instantiate the AHB Master
    AHB_Master master (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PWRITE(PWRITE),
        .PSIZE(PSIZE),
        .PTRANS(PTRANS),
        .PBURST(PBURST),
        .HADDR(HADDR),
        .HWDATA(HWDATA),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),
        .HTRANS(HTRANS),
        .HBURST(HBURST),
        .HREADY(HREADY),
        .HRESP(HRESP),
        .HRDATA(HRDATA),
        .PDONE(PDONE)
        );

    // instantaite the decoder to select the slave based on the most signficant two bits of the address
    AHB_Decoder decoder (
        .HADDR(HADDR),
        .HSELx_slaves(HSELx_slaves),
        .HSELx_Mux(HSELx_Mux)
    );

    // instantiate the AHB Slave 1
    AHB_Slave_1 slave1 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR),
        .HWDATA(HWDATA),
        .HSELx_slaves(HSELx_slaves),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),
        .HTRANS(HTRANS),
        .HBURST(HBURST),
        .HREADY(HREADY),
        .HREADYOUT(HREADYOUT_1),
        .HRESP(HRESP_Slave_1),
        .HRDATA(HRDATA_1)
    );

    // instantiate the AHB Slave 2
    AHB_Slave_2 slave2 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR),
        .HWDATA(HWDATA),
        .HSELx_slaves(HSELx_slaves),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),
        .HTRANS(HTRANS),
        .HBURST(HBURST),
        .HREADY(HREADY),
        .HREADYOUT(HREADYOUT_2),
        .HRESP(HRESP_Slave_2),
        .HRDATA(HRDATA_2)
    );

    // instantiate the Multiplexer
    AHB_MUX mux (
        .HRESP_Slave_1(HRESP_Slave_1),
        .HREADYOUT_1(HREADYOUT_1),
        .HRDATA_Slave_1(HRDATA_1),
        .HRESP_Slave_2(HRESP_Slave_2),
        .HREADYOUT_2(HREADYOUT_2),
        .HRDATA_Slave_2(HRDATA_2),        
        .HSELx_Mux(HSELx_Mux),
        .HRDATA(HRDATA),
        .HREADY(HREADY),
        .HRESP(HRESP)
    );
        

endmodule
