library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

library work;
use work.WF68K30L_PKG.all;

entity tb_wf68k30L_bus_interface is
end entity tb_wf68k30L_bus_interface;

architecture sim of tb_wf68k30L_bus_interface is
  constant CLK_PERIOD : time := 10 ns;
  constant READ_DATA  : std_logic_vector(31 downto 0) := x"12345678";

  signal clk            : std_logic := '0';
  signal adr_in_p       : std_logic_vector(31 downto 0) := x"00000010";
  signal adr_out_p      : std_logic_vector(31 downto 0);
  signal fc_in          : std_logic_vector(2 downto 0) := "111";
  signal fc_out         : std_logic_vector(2 downto 0);
  signal data_port_in   : std_logic_vector(31 downto 0) := READ_DATA;
  signal data_port_out  : std_logic_vector(31 downto 0);
  signal data_from_core : std_logic_vector(31 downto 0) := x"A5A55A5A";
  signal data_to_core   : std_logic_vector(31 downto 0);
  signal opcode_to_core : std_logic_vector(15 downto 0);
  signal data_port_en   : std_logic;
  signal bus_en         : std_logic;
  signal size           : std_logic_vector(1 downto 0);
  signal op_size        : op_sizetype := LONG;
  signal rd_req         : bit := '0';
  signal wr_req         : bit := '0';
  signal data_rdy       : bit;
  signal data_valid     : std_logic;
  signal opcode_req     : bit := '0';
  signal opcode_rdy     : bit;
  signal opcode_valid   : std_logic;
  signal rmc            : bit := '0';
  signal busy_exh       : bit := '0';
  signal inbuffer       : std_logic_vector(31 downto 0);
  signal outbuffer      : std_logic_vector(31 downto 0);
  signal ssw_80         : std_logic_vector(8 downto 0);
  signal dsackn         : std_logic_vector(1 downto 0) := "11";
  signal asn            : std_logic;
  signal dsn            : std_logic;
  signal rwn            : std_logic;
  signal rmcn           : std_logic;
  signal ecsn           : std_logic;
  signal ocsn           : std_logic;
  signal dbenn          : std_logic;
  signal stermn         : std_logic := '1';
  signal brn            : std_logic := '1';
  signal bgackn         : std_logic := '1';
  signal bgn            : std_logic;
  signal reset_in       : std_logic := '1';
  signal reset_strb     : bit := '0';
  signal reset_out      : std_logic;
  signal reset_cpu      : bit;
  signal avecn          : std_logic := '1';
  signal haltn          : std_logic := '0';
  signal berrn          : std_logic := '1';
  signal aerr           : bit := '0';
  signal bus_bsy        : bit;

  signal saw_write_cycle : std_logic := '0';
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut: entity work.WF68K30L_BUS_INTERFACE
    port map (
      CLK            => clk,
      ADR_IN_P       => adr_in_p,
      ADR_OUT_P      => adr_out_p,
      FC_IN          => fc_in,
      FC_OUT         => fc_out,
      DATA_PORT_IN   => data_port_in,
      DATA_PORT_OUT  => data_port_out,
      DATA_FROM_CORE => data_from_core,
      DATA_TO_CORE   => data_to_core,
      OPCODE_TO_CORE => opcode_to_core,
      DATA_PORT_EN   => data_port_en,
      BUS_EN         => bus_en,
      SIZE           => size,
      OP_SIZE        => op_size,
      RD_REQ         => rd_req,
      WR_REQ         => wr_req,
      DATA_RDY       => data_rdy,
      DATA_VALID     => data_valid,
      OPCODE_REQ     => opcode_req,
      OPCODE_RDY     => opcode_rdy,
      OPCODE_VALID   => opcode_valid,
      RMC            => rmc,
      BUSY_EXH       => busy_exh,
      INBUFFER       => inbuffer,
      OUTBUFFER      => outbuffer,
      SSW_80         => ssw_80,
      DSACKn         => dsackn,
      ASn            => asn,
      DSn            => dsn,
      RWn            => rwn,
      RMCn           => rmcn,
      ECSn           => ecsn,
      OCSn           => ocsn,
      DBENn          => dbenn,
      STERMn         => stermn,
      BRn            => brn,
      BGACKn         => bgackn,
      BGn            => bgn,
      RESET_IN       => reset_in,
      RESET_STRB     => reset_strb,
      RESET_OUT      => reset_out,
      RESET_CPU      => reset_cpu,
      AVECn          => avecn,
      HALTn          => haltn,
      BERRn          => berrn,
      AERR           => aerr,
      BUS_BSY        => bus_bsy
    );

  -- Simple memory/peripheral responder.
  slave_model: process(all)
  begin
    dsackn <= "11";
    data_port_in <= READ_DATA;
    if asn = '0' then
      dsackn <= "00";
    end if;
  end process;

  write_tracker: process(clk)
  begin
    if rising_edge(clk) then
      if asn = '0' and dsn = '0' and rwn = '0' then
        saw_write_cycle <= '1';
      end if;
    end if;
  end process;

  stimulus: process
    variable got_data_rdy   : boolean := false;
    variable got_opcode_rdy : boolean := false;
  begin
    report "Bus interface bench: start" severity note;

    -- Reset filter sequence: assert RESET_IN with HALT low, then release.
    for i in 0 to 15 loop
      wait until rising_edge(clk);
    end loop;
    reset_in <= '0';
    wait until rising_edge(clk);
    haltn <= '1';
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    assert reset_cpu = '0'
      report "RESET_CPU did not deassert after reset filter sequence"
      severity failure;
    assert bus_en = '1'
      report "BUS_EN not asserted after reset release"
      severity failure;

    -- Read cycle.
    rd_req <= '1';
    got_data_rdy := false;
    for i in 0 to 60 loop
      wait until rising_edge(clk);
      if data_rdy = '1' then
        got_data_rdy := true;
        exit;
      end if;
    end loop;
    rd_req <= '0';
    assert got_data_rdy
      report "DATA_RDY did not assert for RD_REQ cycle"
      severity failure;
    assert data_to_core = READ_DATA
      report "DATA_TO_CORE mismatch in read cycle"
      severity failure;

    -- Write cycle.
    wr_req <= '1';
    got_data_rdy := false;
    for i in 0 to 60 loop
      wait until rising_edge(clk);
      if data_rdy = '1' then
        got_data_rdy := true;
        exit;
      end if;
    end loop;
    wr_req <= '0';
    assert got_data_rdy
      report "DATA_RDY did not assert for WR_REQ cycle"
      severity failure;
    assert saw_write_cycle = '1'
      report "No write transfer observed on bus outputs"
      severity failure;

    -- Opcode prefetch cycle.
    opcode_req <= '1';
    got_opcode_rdy := false;
    for i in 0 to 60 loop
      wait until rising_edge(clk);
      if opcode_rdy = '1' then
        got_opcode_rdy := true;
        exit;
      end if;
    end loop;
    opcode_req <= '0';
    assert got_opcode_rdy
      report "OPCODE_RDY did not assert for OPCODE_REQ cycle"
      severity failure;

    -- Arbitration sample: BRn low should grant bus.
    brn <= '0';
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    assert bgn = '0'
      report "BGn did not assert low during arbitration request"
      severity failure;
    brn <= '1';
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    assert bgn = '1'
      report "BGn did not return high after arbitration release"
      severity failure;

    report "Bus interface bench: passed" severity note;
    finish;
  end process;

  watchdog: process
  begin
    wait for 5 us;
    assert false report "Bus interface bench timeout" severity failure;
  end process;
end architecture sim;
