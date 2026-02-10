library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

library work;
use work.WF68K30L_PKG.all;

entity tb_wf68k30L_opcode_decoder is
end entity tb_wf68k30L_opcode_decoder;

architecture sim of tb_wf68k30L_opcode_decoder is
  constant CLK_PERIOD : time := 10 ns;

  signal clk           : std_logic := '0';
  signal ow_req_main   : bit := '0';
  signal ew_req_main   : bit := '0';
  signal exh_req       : bit := '0';
  signal busy_exh      : bit := '0';
  signal busy_main     : bit := '0';
  signal busy_opd      : bit;
  signal bkpt_insert   : bit := '0';
  signal bkpt_data     : std_logic_vector(15 downto 0) := (others => '0');
  signal loop_exit     : bit := '0';
  signal loop_bsy      : bit;
  signal opd_ack_main  : bit;
  signal ew_ack        : bit;
  signal pc_inc        : bit;
  signal pc_inc_exh    : bit := '0';
  signal pc_adr_offset : std_logic_vector(7 downto 0);
  signal pc_ew_offset  : std_logic_vector(3 downto 0);
  signal pc_offset     : std_logic_vector(7 downto 0);
  signal opcode_rd     : bit;
  signal opcode_rdy    : bit := '0';
  signal opcode_valid  : std_logic := '1';
  signal opcode_data   : std_logic_vector(15 downto 0) := (others => '0');
  signal ipipe_fill    : bit := '1';
  signal ipipe_flush   : bit := '0';
  signal ow_valid      : std_logic;
  signal rc            : std_logic;
  signal rb            : std_logic;
  signal fc            : std_logic;
  signal fb            : std_logic;
  signal sbit          : std_logic := '0';
  signal trap_code     : traptype_opc;
  signal op            : op_68k;
  signal biw_0         : std_logic_vector(15 downto 0);
  signal biw_1         : std_logic_vector(15 downto 0);
  signal biw_2         : std_logic_vector(15 downto 0);
  signal ext_word      : std_logic_vector(15 downto 0);

  procedure push_opcode(
    signal clk_s        : in std_logic;
    signal opcode_rdy_s : out bit;
    signal opcode_data_s: out std_logic_vector(15 downto 0);
    signal opcode_valid_s : out std_logic;
    constant data       : std_logic_vector(15 downto 0)
  ) is
  begin
    opcode_data_s <= data;
    opcode_valid_s <= '1';
    opcode_rdy_s <= '1';
    wait until rising_edge(clk_s);
    opcode_rdy_s <= '0';
    wait until rising_edge(clk_s);
  end procedure;
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut: entity work.WF68K30L_OPCODE_DECODER
    generic map (
      NO_LOOP  => true,
      NO_BFOPS => true
    )
    port map (
      CLK           => clk,
      OW_REQ_MAIN   => ow_req_main,
      EW_REQ_MAIN   => ew_req_main,
      EXH_REQ       => exh_req,
      BUSY_EXH      => busy_exh,
      BUSY_MAIN     => busy_main,
      BUSY_OPD      => busy_opd,
      BKPT_INSERT   => bkpt_insert,
      BKPT_DATA     => bkpt_data,
      LOOP_EXIT     => loop_exit,
      LOOP_BSY      => loop_bsy,
      OPD_ACK_MAIN  => opd_ack_main,
      EW_ACK        => ew_ack,
      PC_INC        => pc_inc,
      PC_INC_EXH    => pc_inc_exh,
      PC_ADR_OFFSET => pc_adr_offset,
      PC_EW_OFFSET  => pc_ew_offset,
      PC_OFFSET     => pc_offset,
      OPCODE_RD     => opcode_rd,
      OPCODE_RDY    => opcode_rdy,
      OPCODE_VALID  => opcode_valid,
      OPCODE_DATA   => opcode_data,
      IPIPE_FILL    => ipipe_fill,
      IPIPE_FLUSH   => ipipe_flush,
      OW_VALID      => ow_valid,
      RC            => rc,
      RB            => rb,
      FC            => fc,
      FB            => fb,
      SBIT          => sbit,
      TRAP_CODE     => trap_code,
      OP            => op,
      BIW_0         => biw_0,
      BIW_1         => biw_1,
      BIW_2         => biw_2,
      EXT_WORD      => ext_word
    );

  stimulus: process
    variable saw_opcode_rd : boolean := false;
  begin
    report "Opcode decoder bench: start" severity note;

    -- Initialize internal instruction-pipe state.
    ipipe_flush <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    ipipe_flush <= '0';

    -- Push NOP in D stage and one extension in C stage.
    push_opcode(clk, opcode_rdy, opcode_data, opcode_valid, x"4E71");
    push_opcode(clk, opcode_rdy, opcode_data, opcode_valid, x"0000");

    ow_req_main <= '1';
    for i in 0 to 40 loop
      wait until rising_edge(clk);
      if opcode_rd = '1' then
        saw_opcode_rd := true;
        exit;
      end if;
    end loop;
    ow_req_main <= '0';

    assert saw_opcode_rd
      report "OPCODE_RD did not assert during decode activity"
      severity failure;
    assert loop_bsy = '0'
      report "LOOP_BSY asserted unexpectedly while NO_LOOP=true"
      severity failure;

    -- Verify F-line dispatch enters the coprocessor path without an immediate trap.
    push_opcode(clk, opcode_rdy, opcode_data, opcode_valid, x"F200");
    ow_req_main <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    ow_req_main <= '0';

    assert op = COPROC
      report "F-line opcode did not decode as COPROC"
      severity failure;
    assert trap_code = NONE
      report "F-line opcode raised trap during decode"
      severity failure;

    report "Opcode decoder bench: passed" severity note;
    finish;
  end process;

  watchdog: process
  begin
    wait for 3 us;
    assert false report "Opcode decoder bench timeout" severity failure;
  end process;
end architecture sim;
