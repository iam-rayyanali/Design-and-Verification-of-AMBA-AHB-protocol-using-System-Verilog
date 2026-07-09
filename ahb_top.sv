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
