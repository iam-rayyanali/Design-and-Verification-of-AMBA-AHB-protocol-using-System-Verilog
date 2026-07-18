# Design and Verification of AMBA AHB-Lite Protocol Using SystemVerilog

## AMBA AHB-Lite Multi-Slave Interconnect Subsystem

This project presents a complete hardware implementation and functional verification of an **AMBA AHB-Lite compliant bus subsystem** developed entirely in **SystemVerilog**. The design demonstrates how an AHB-Lite based system interconnect enables communication between a single Bus Master and multiple memory-mapped Slave peripherals while adhering to the AMBA protocol specifications.

The subsystem has been designed with modularity, scalability, and protocol compliance in mind. Each functional block—including the Master, Address Decoder, Read Data/Response Multiplexer, and individual Slave interfaces—is implemented as an independent SystemVerilog module, making the architecture easy to understand, verify, and extend.

The project also includes a comprehensive verification environment that validates both read and write transactions across multiple slaves under various transfer sizes and burst conditions.

---

# Project Objectives

The primary objectives of this project are:

* Design a fully functional **AMBA AHB-Lite** interconnect using SystemVerilog.
* Understand the pipelined architecture of the AHB protocol.
* Implement address decoding for multiple slave devices.
* Support memory-mapped communication between one master and multiple slaves.
* Implement different transfer sizes (Byte, Half-Word, and Word).
* Support both single and burst data transfers.
* Verify protocol correctness through a comprehensive SystemVerilog testbench.
* Create a modular design that can easily be expanded with additional peripherals.

---

# AMBA AHB-Lite Overview

The **Advanced High-performance Bus (AHB-Lite)** is one of the bus protocols defined under ARM's **Advanced Microcontroller Bus Architecture (AMBA)** family. Unlike the full AHB protocol, AHB-Lite is intended for systems containing **only one Bus Master**, thereby eliminating the need for bus arbitration logic while maintaining high throughput.

AHB-Lite achieves high performance through a **two-stage pipelined architecture**, where the **Address Phase** of the next transaction overlaps with the **Data Phase** of the current transaction. This overlapping significantly improves bus utilization and overall system performance.

Key characteristics of the protocol include:

* Single-master architecture
* High-speed synchronous communication
* Pipelined address and data phases
* Memory-mapped addressing
* Burst transfer capability
* Multiple transfer sizes
* Wait-state support
* Error response mechanism

---

# System Architecture

The implemented subsystem follows the standard AMBA AHB-Lite communication flow.

```
                  +----------------+
                  |   AHB Master   |
                  +-------+--------+
                          |
                          |
                 Address / Control
                          |
                 +--------v---------+
                 |   AHB Decoder    |
                 +----+--------+----+
                      |        |
                  HSEL1      HSEL2
                      |        |
        +-------------+        +-------------+
        |                                  |
+-------v-------+                  +--------v--------+
|  AHB Slave 1  |                  |  AHB Slave 2    |
|1024 Byte RAM  |                  |64 Byte RAM/FSM  |
+-------+-------+                  +--------+--------+
        |                                   |
        +-------------+   +-----------------+
                      |   |
              +-------v---v-------+
              |   AHB MUX         |
              | HRDATA/HRESP/...  |
              +-------+-----------+
                      |
                 Back to Master
```

The design is composed of five major hardware blocks:

* AHB Master
* Address Decoder
* Slave 1
* Slave 2
* Read Data & Response Multiplexer

Each module performs a dedicated task while collectively implementing the complete bus subsystem.

---

# Module Description

## 1. AHB Master

The **AHB Master** is responsible for initiating all bus transactions. It accepts processor-side commands and converts them into valid AHB bus operations.

The master generates:

* Address (`HADDR`)
* Write data (`HWDATA`)
* Transfer type (`HTRANS`)
* Transfer size (`HSIZE`)
* Burst information (`HBURST`)
* Write enable (`HWRITE`)

The Master operates according to the AHB transaction state machine and supports:

* IDLE transfers
* NONSEQ transfers
* SEQ transfers
* BUSY cycles

The implementation also supports both:

* Single transactions
* Undefined-length Incrementing Burst (INCR)

The design ensures that address/control information is presented one clock cycle ahead of the associated write/read data, following the AHB pipeline requirements.

---

## 2. Address Decoder

The Decoder performs memory-mapped slave selection based on the incoming address.

The two most significant bits of the address bus are examined:

```
HADDR[31:30]
```

Address map:

| Address Bits | Selected Device |
| ------------ | --------------- |
| 2'b00        | Slave 1         |
| 2'b01        | Slave 2         |
| Others       | Reserved        |

The decoder generates dedicated slave select signals:

* HSEL_Slave1
* HSEL_Slave2

Only one slave is enabled during any valid transaction.

---

## 3. AHB Slave 1

Slave 1 represents a relatively large on-chip memory intended for functional verification.

Characteristics:

* 8-bit memory organization
* 1024-byte storage
* Fully synchronous interface
* Registered transaction tracking
* Supports reads and writes
* Handles multiple transfer sizes

The memory supports:

* Byte transfers
* Half-word transfers
* Word transfers

Depending on the value of `HSIZE`, the slave automatically accesses one, two, or four consecutive memory locations.

---

## 4. AHB Slave 2

Slave 2 demonstrates an alternative implementation using an explicit finite-state machine.

Characteristics:

* 64-byte memory
* 8-bit memory organization
* FSM-controlled operations
* Transaction monitoring

Internal FSM states include:

* IDLE
* WRITE
* READ

The FSM makes transaction progression easier to observe during simulation and provides a good educational example of protocol implementation.

---

## 5. Read Data / Response Multiplexer

The AHB Multiplexer connects the outputs of all slaves back to the Master.

Its responsibilities include selecting:

* Read data (`HRDATA`)
* Ready signal (`HREADYOUT`)
* Response signal (`HRESP`)

Only the currently selected slave is allowed to drive these signals.

This guarantees proper routing of data while preventing bus contention.

---

# Address Mapping

The memory map used in the design is summarized below.

| Address Range        | Target                        |
| -------------------- | ----------------------------- |
| HADDR[31:30] = 2'b00 | Slave 1                       |
| HADDR[31:30] = 2'b01 | Slave 2                       |
| Others               | Reserved for future expansion |

The decoder can easily be modified to support additional slave devices by expanding the address decoding logic.

---

# Supported Transfer Types

The implementation currently supports the following AHB transfer types.

| HTRANS | Description                                |
| ------ | ------------------------------------------ |
| IDLE   | No data transfer                           |
| NONSEQ | First transfer of a transaction            |
| SEQ    | Remaining burst transfers                  |
| BUSY   | Inserts wait cycle while maintaining burst |

---

# Supported Transfer Sizes

The subsystem supports variable-width memory accesses.

| HSIZE  | Transfer  | Bytes |
| ------ | --------- | ----- |
| 3'b000 | Byte      | 1     |
| 3'b001 | Half Word | 2     |
| 3'b010 | Word      | 4     |

The slave memories automatically split larger transfers into consecutive byte accesses within the memory arrays.

---

# Burst Support

The current implementation supports:

| HBURST | Description               |
| ------ | ------------------------- |
| 3'b000 | Single Transfer           |
| 3'b001 | Incrementing Burst (INCR) |

The INCR burst allows an undefined number of sequential transfers where the address automatically increments after each successful transfer.

---

# Pipelined Operation

One of the defining characteristics of AHB-Lite is its pipelined architecture.

Each transaction consists of two phases:

### Address Phase

During this phase the master drives:

* HADDR
* HTRANS
* HWRITE
* HSIZE
* HBURST

### Data Phase

During the following clock cycle:

* Write data is transferred to the slave.
* Read data is returned from the slave.
* Response information is generated.
* Ready signals determine whether additional wait states are required.

This overlap between consecutive transactions significantly increases bus throughput.

---

# Verification Environment

A dedicated SystemVerilog testbench verifies the correctness of the implementation.

The testbench performs:

* Reset generation
* Clock generation
* Single write transactions
* Single read transactions
* Byte accesses
* Half-word accesses
* Word accesses
* Burst write operations
* Burst read operations
* Slave switching
* Address decoding verification
* Read data validation
* Protocol timing verification

Simulation waveforms can be used to observe:

* HADDR
* HWRITE
* HWDATA
* HRDATA
* HREADY
* HRESP
* HSEL signals
* HTRANS
* HBURST
* HSIZE

---

# Design Highlights

* Fully modular SystemVerilog implementation
* AMBA AHB-Lite compliant architecture
* Two-stage pipelined bus protocol
* Multi-slave memory-mapped interconnect
* Dynamic address decoding
* Independent slave implementations
* Configurable memory modules
* Multiple transfer size support
* Incrementing burst transfers
* Clean structural top-level design
* Comprehensive functional verification testbench
* Easily extendable to additional slave peripherals

---

# Repository Structure

```
├── ahb_pkg.sv
│   ├── Defines AHB protocol constants
│   ├── Enumerations for HTRANS states
│   └── Common package definitions

├── AHB_TOP.sv
│   ├── Top-level structural module
│   ├── Instantiates Master
│   ├── Decoder
│   ├── MUX
│   ├── Slave 1
│   └── Slave 2

├── AHB_Master.sv
│   └── Bus master implementation

├── AHB_Decoder.sv
│   └── Address decoder

├── AHB_MUX.sv
│   └── Read data and response multiplexer

├── AHB_Slave_1.sv
│   └── 1024-byte verification memory

├── AHB_Slave_2.sv
│   └── 64-byte FSM-based memory

├── AHB_tb.sv
│   ├── Clock generation
│   ├── Reset generation
│   ├── Functional testcases
│   ├── Burst verification
│   └── Output checking

└── README.md
```

---

# Future Enhancements

The modular nature of this design allows several enhancements to be incorporated with minimal architectural changes.

Possible future improvements include:

* Support for additional slave peripherals
* Fixed-length burst types (INCR4, INCR8, INCR16)
* BUSY transfer optimization
* Error response generation
* Protection control (`HPROT`)
* Master-side FSM optimization
* Parameterized memory sizes
* Functional coverage collection
* Assertion-Based Verification (SVA)
* UVM-based verification environment
* Randomized constrained stimulus generation
* Scoreboard and protocol checker integration

---

# Conclusion

This project demonstrates the complete design and verification of a simplified **AMBA AHB-Lite Multi-Slave Interconnect Subsystem** using **SystemVerilog**. The implementation faithfully models the pipelined nature of the AHB-Lite protocol while supporting memory-mapped communication between a single master and multiple slaves. Through modular design, configurable memory interfaces, burst transfer capability, and comprehensive verification, the project serves as an excellent reference for students, FPGA developers, and verification engineers seeking to understand the internal operation of the AMBA AHB-Lite protocol and modern on-chip bus architectures.
