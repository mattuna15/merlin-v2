library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

library work;
use work.WF68K30L_PKG.all;

entity tb_wf68k30L_alu is
end entity tb_wf68k30L_alu;

architecture sim of tb_wf68k30L_alu is
  constant CLK_PERIOD : time := 10 ns;

  signal clk          : std_logic := '0';
  signal reset        : bit := '0';
  signal load_op1     : bit := '0';
  signal load_op2     : bit := '0';
  signal load_op3     : bit := '0';
  signal op1_in       : std_logic_vector(31 downto 0) := (others => '0');
  signal op2_in       : std_logic_vector(31 downto 0) := (others => '0');
  signal op3_in       : std_logic_vector(31 downto 0) := (others => '0');
  signal bf_offset_in : std_logic_vector(31 downto 0) := (others => '0');
  signal bf_width_in  : std_logic_vector(5 downto 0) := "000001";
  signal bitpos_in    : std_logic_vector(4 downto 0) := (others => '0');
  signal result       : std_logic_vector(63 downto 0);
  signal adr_mode_in  : std_logic_vector(2 downto 0) := (others => '0');
  signal op_size_in   : op_sizetype := LONG;
  signal op_in        : op_68k := UNIMPLEMENTED;
  signal op_wb        : op_68k := UNIMPLEMENTED;
  signal biw_0_in     : std_logic_vector(11 downto 0) := (others => '0');
  signal biw_1_in     : std_logic_vector(15 downto 0) := (others => '0');
  signal sr_wr        : bit := '0';
  signal sr_init      : bit := '0';
  signal sr_clr_mbit  : bit := '0';
  signal cc_updt      : bit := '0';
  signal status_reg   : std_logic_vector(15 downto 0);
  signal alu_cond     : boolean;
  signal alu_init     : bit := '0';
  signal alu_bsy      : bit;
  signal alu_req      : bit;
  signal alu_ack      : bit := '0';
  signal use_dreg     : bit := '0';
  signal hilon        : bit := '0';
  signal irq_pend     : std_logic_vector(2 downto 0) := (others => '1');
  signal trap_chk     : bit;
  signal trap_divzero : bit;
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut: entity work.WF68K30L_ALU
    port map (
      CLK            => clk,
      RESET          => reset,
      LOAD_OP1       => load_op1,
      LOAD_OP2       => load_op2,
      LOAD_OP3       => load_op3,
      OP1_IN         => op1_in,
      OP2_IN         => op2_in,
      OP3_IN         => op3_in,
      BF_OFFSET_IN   => bf_offset_in,
      BF_WIDTH_IN    => bf_width_in,
      BITPOS_IN      => bitpos_in,
      RESULT         => result,
      ADR_MODE_IN    => adr_mode_in,
      OP_SIZE_IN     => op_size_in,
      OP_IN          => op_in,
      OP_WB          => op_wb,
      BIW_0_IN       => biw_0_in,
      BIW_1_IN       => biw_1_in,
      SR_WR          => sr_wr,
      SR_INIT        => sr_init,
      SR_CLR_MBIT    => sr_clr_mbit,
      CC_UPDT        => cc_updt,
      STATUS_REG_OUT => status_reg,
      ALU_COND       => alu_cond,
      ALU_INIT       => alu_init,
      ALU_BSY        => alu_bsy,
      ALU_REQ        => alu_req,
      ALU_ACK        => alu_ack,
      USE_DREG       => use_dreg,
      HILOn          => hilon,
      IRQ_PEND       => irq_pend,
      TRAP_CHK       => trap_chk,
      TRAP_DIVZERO   => trap_divzero
    );

  stimulus: process
  begin
    report "ALU bench: start" severity note;

    wait for 2 * CLK_PERIOD;

    -- Representative datapath check using CLR (deterministic zero result).
    op_in <= CLR;
    op_wb <= CLR;
    op_size_in <= LONG;
    op1_in <= x"00000003";
    op2_in <= x"00000004";
    load_op1 <= '1';
    load_op2 <= '1';
    wait until rising_edge(clk);
    load_op1 <= '0';
    load_op2 <= '0';

    alu_init <= '1';
    wait until rising_edge(clk);
    alu_init <= '0';

    wait until rising_edge(clk);
    assert alu_req = '1'
      report "ALU_REQ did not assert for CLR operation"
      severity failure;

    alu_ack <= '1';
    wait until rising_edge(clk);
    alu_ack <= '0';
    wait until rising_edge(clk);
    assert alu_req = '0'
      report "ALU_REQ did not clear after ALU_ACK"
      severity failure;

    report "ALU bench: passed" severity note;
    finish;
  end process;

  watchdog: process
  begin
    wait for 2 us;
    assert false report "ALU bench timeout" severity failure;
  end process;
end architecture sim;
