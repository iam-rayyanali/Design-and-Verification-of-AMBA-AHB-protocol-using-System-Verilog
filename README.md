# Design-and-Verification-of-AMBA-AHB-protocol-using-System-Verilog
# AMBA AHB-Lite Multi-Slave Interconnect Subsystem

A hardware implementation of an **AMBA AHB-Lite** compliant bus subsystem designed in SystemVerilog. The project establishes a functional interconnect infrastructure featuring a single Master, a central Decoder, a Read Data/Response Multiplexer, and two memory-mapped independent Slaves with byte-accessible storage configurations.

---

## 📌 Architecture Overview

The design follows the standard AMBA AHB-Lite protocol, decoupling the **Address Phase** and **Data Phase** to achieve pipelined bus transfers. 

### Subsystem Components
* **AHB_Master**: Latches processor commands (`PADDR`, `PWDATA`, etc.) and drives them onto the AHB bus according to state transitions (`IDLE`, `NONSEQ`, `SEQ`, `BUSY`). Supports single and incremental undefined length burst transfers (`INCR`).
* **AHB_Decoder**: Evaluates the top two bits of the address bus (`HADDR[31:30]`) to selectively assert target slave selects (`HSELx_slaves`).
* **AHB_Slave_1**: A large verification memory module configured with an 8-bit width and 1024-byte depth. Completely synchronous interface utilizing state tracking registers.
* **AHB_Slave_2**: A smaller verification memory module (8-bit width, 64-byte depth) driven explicitly by an internal Finite State Machine (`IDLE`, `WRITE`, `READ`) for transactional tracking.
* **AHB_MUX**: Resolves bus routing by mapping selected slave read data (`HRDATA_Slave_x`), wait-states (`HREADYOUT_x`), and response properties (`HRESP_Slave_x`) back to the Master via central infrastructure signals.

---

## 🚀 Key Features

* **Pipelined Architecture**: Implements standard AHB address/data phase separation. Control signals are processed one cycle ahead of corresponding data vectors.
* **Dynamic Slave Selection**: Memory-mapped addressing space configured via top-level decoding bits:
    * `2'b00` ➡️ Target: **Slave 1** (Large Memory Array)
    * `2'b01` ➡️ Target: **Slave 2** (Small FSM-driven Memory)
* **Multi-Size Transfer Support**: Handles mixed-data widths inside the memory arrays by slicing transactions based on `HSIZE`:
    * `3'b000` (8-bit Byte)
    * `3'b001` (16-bit Half-Word)
    * `3'b010` (32-bit Word)
* **Burst Compatibility**: Supports Single transfers (`HBURST = 3'b000`) and Undefined Length Incremental Bursts (`HBURST = 3'b001`).

---

## 📁 Repository Structure

├── ahb_pkg.sv         # SystemVerilog Package defining AHB HTRANS transaction states
├── AHB_TOP.sv         # Top-level structural design stitching Master, Mux, Decoder & Slaves
├── AHB_tb.sv          # Complete comprehensive stimulus and validation testbench
└── README.md          # Project Documentation
