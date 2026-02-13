module wb_decode
  #(
    parameter SLAVES = 2,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    localparam SEL_WIDTH = DATA_WIDTH >> 3,
    // Explicitly define widths to prevent parameter mismatch
    parameter S0_ENABLE = 1,
    parameter S0_RANGE_WIDTH = 4,
    parameter S0_RANGE_MATCH = 4'b0000,
    
    parameter S1_ENABLE = 1,
    parameter S1_RANGE_WIDTH = 4,
    parameter S1_RANGE_MATCH = 4'b0001
  )
  (
    input                              clk_i,
    input                              rst_i,

    // Master Interface
    input [ADDR_WIDTH-1:0]             m_adr_i,
    input [DATA_WIDTH-1:0]             m_dat_i,
    input                              m_cyc_i,
    input                              m_stb_i,
    input [(DATA_WIDTH/8)-1:0]         m_sel_i,
    input                              m_we_i,
    input [2:0]                        m_cti_i,
    input [1:0]                        m_bte_i,

    output reg [DATA_WIDTH-1:0]        m_dat_o,
    output reg                         m_ack_o,
    output reg                         m_err_o,
    output reg                         m_rty_o,

    // Flattened Slave Interfaces
    output reg [ADDR_WIDTH*SLAVES-1:0] s_adr_o,
    output reg [DATA_WIDTH*SLAVES-1:0] s_dat_o,
    output reg [SLAVES-1:0]            s_cyc_o,
    output reg [SLAVES-1:0]            s_stb_o,
    output reg [(DATA_WIDTH/8)*SLAVES-1:0] s_sel_o,
    output reg [SLAVES-1:0]            s_we_o,
    output reg [SLAVES*3-1:0]          s_cti_o,
    output reg [SLAVES*2-1:0]          s_bte_o,

    input [DATA_WIDTH*SLAVES-1:0]      s_dat_i,
    input [SLAVES-1:0]                 s_ack_i,
    input [SLAVES-1:0]                 s_err_i,
    input [SLAVES-1:0]                 s_rty_i
  );

   wire [SLAVES-1:0] s_select;

   generate
      if (SLAVES > 0)
        assign s_select[0] = S0_ENABLE & (m_adr_i[ADDR_WIDTH-1 -: S0_RANGE_WIDTH] == S0_RANGE_MATCH[S0_RANGE_WIDTH-1:0]);
      if (SLAVES > 1)
        assign s_select[1] = S1_ENABLE & (m_adr_i[ADDR_WIDTH-1 -: S1_RANGE_WIDTH] == S1_RANGE_MATCH[S1_RANGE_WIDTH-1:0]);
   endgenerate

   wire                            bus_error;
   assign bus_error = ~^s_select;

   reg                             m_ack, m_err, m_rty;

   // --- DATA & CONTROL MUX ---
   always @(*) begin : bus_s_mux
      integer i;
      m_dat_o = {DATA_WIDTH{1'b0}};
      m_ack = 1'b0;
      m_err = 1'b0;
      m_rty = 1'b0;
      for (i = 0; i < SLAVES; i = i + 1) begin
         s_adr_o[i*ADDR_WIDTH +: ADDR_WIDTH] = m_adr_i;
         s_dat_o[i*DATA_WIDTH +: DATA_WIDTH] = m_dat_i;
         s_sel_o[i*SEL_WIDTH +: SEL_WIDTH] = m_sel_i;
         s_we_o[i] = m_we_i;
         s_cti_o[i*3 +: 3] = m_cti_i;
         s_bte_o[i*2 +: 2] = m_bte_i;

         s_cyc_o[i] = m_cyc_i & s_select[i];
         s_stb_o[i] = m_stb_i & s_select[i];

         if (s_select[i]) begin
            m_dat_o = s_dat_i[i*DATA_WIDTH +: DATA_WIDTH];
            m_ack = s_ack_i[i];
            m_err = s_err_i[i];
            m_rty = s_rty_i[i];
         end
      end
   end

   assign m_ack_o = m_ack & !bus_error;
   assign m_err_o = m_err | bus_error;
   assign m_rty_o = m_rty & !bus_error;

endmodule