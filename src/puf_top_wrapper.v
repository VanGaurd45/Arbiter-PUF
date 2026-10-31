`timescale 1ns / 1ps

module puf_top_wrapper (
    inout  [14:0] DDR_addr,
    inout  [2:0]  DDR_ba,
    inout         DDR_cas_n,
    inout         DDR_ck_n,
    inout         DDR_ck_p,
    inout         DDR_cke,
    inout         DDR_cs_n,
    inout  [3:0]  DDR_dm,
    inout  [31:0] DDR_dq,
    inout  [3:0]  DDR_dqs_n,
    inout  [3:0]  DDR_dqs_p,
    inout         DDR_odt,
    inout         DDR_ras_n,
    inout         DDR_reset_n,
    inout         DDR_we_n,
    inout         FIXED_IO_ddr_vrn,
    inout         FIXED_IO_ddr_vrp,
    inout  [53:0] FIXED_IO_mio,
    inout         FIXED_IO_ps_clk,
    inout         FIXED_IO_ps_porb,
    inout         FIXED_IO_ps_srstb
);

    wire [31:0] araddr, awaddr, rdata, wdata;
    wire [2:0]  arprot, awprot;
    wire [1:0]  bresp, rresp;
    wire [3:0]  wstrb;
    wire        arvalid, arready, awvalid, awready;
    wire        wvalid, wready, bvalid, bready, rvalid, rready;

    wire        aclk;
    wire        aresetn;

    design_1_wrapper design_1_i (
        .DDR_addr(DDR_addr), .DDR_ba(DDR_ba), .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n), .DDR_ck_p(DDR_ck_p), .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n), .DDR_dm(DDR_dm), .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n), .DDR_dqs_p(DDR_dqs_p), .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n), .DDR_reset_n(DDR_reset_n), .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn), .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio), .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb), .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),

        .M00_AXI_0_araddr(araddr),
        .M00_AXI_0_arburst(), .M00_AXI_0_arcache(), .M00_AXI_0_arlen(),
        .M00_AXI_0_arlock(), .M00_AXI_0_arprot(arprot), .M00_AXI_0_arqos(),
        .M00_AXI_0_arready(arready), .M00_AXI_0_arsize(), .M00_AXI_0_arvalid(arvalid),

        .M00_AXI_0_awaddr(awaddr),
        .M00_AXI_0_awburst(), .M00_AXI_0_awcache(), .M00_AXI_0_awlen(),
        .M00_AXI_0_awlock(), .M00_AXI_0_awprot(awprot), .M00_AXI_0_awqos(),
        .M00_AXI_0_awready(awready), .M00_AXI_0_awsize(), .M00_AXI_0_awvalid(awvalid),

        .M00_AXI_0_bready(bready),
        .M00_AXI_0_bresp(bresp),
        .M00_AXI_0_bvalid(bvalid),

        .M00_AXI_0_rdata(rdata),
        .M00_AXI_0_rlast(1'b1),
        .M00_AXI_0_rready(rready),
        .M00_AXI_0_rresp(rresp),
        .M00_AXI_0_rvalid(rvalid),

        .M00_AXI_0_wdata(wdata),
        .M00_AXI_0_wlast(1'b1),
        .M00_AXI_0_wready(wready),
        .M00_AXI_0_wstrb(wstrb),
        .M00_AXI_0_wvalid(wvalid),

        .fclk_aresetn_out(aresetn),
        .fclk_clk0_out(aclk)
    );

    puf_axi_ip_slave_lite_v1_0_S00_AXI #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(5)
    ) puf_slave_i (
        .S_AXI_ACLK(aclk),
        .S_AXI_ARESETN(aresetn),
        .S_AXI_AWADDR(awaddr[4:0]),
        .S_AXI_AWPROT(awprot),
        .S_AXI_AWVALID(awvalid),
        .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata),
        .S_AXI_WSTRB(wstrb),
        .S_AXI_WVALID(wvalid),
        .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp),
        .S_AXI_BVALID(bvalid),
        .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr[4:0]),
        .S_AXI_ARPROT(arprot),
        .S_AXI_ARVALID(arvalid),
        .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata),
        .S_AXI_RRESP(rresp),
        .S_AXI_RVALID(rvalid),
        .S_AXI_RREADY(rready)
    );

endmodule