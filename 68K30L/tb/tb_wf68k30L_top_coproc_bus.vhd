library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_wf68k30L_top_coproc_bus is
end entity tb_wf68k30L_top_coproc_bus;

architecture sim of tb_wf68k30L_top_coproc_bus is
  constant CLK_PERIOD : time := 10 ns;

  signal clk       : std_logic := '0';
  signal adr_out   : std_logic_vector(31 downto 0);
  signal data_in   : std_logic_vector(31 downto 0) := (others => '0');
  signal data_out  : std_logic_vector(31 downto 0);
  signal data_en   : std_logic;
  signal berrn     : std_logic := '1';
  signal reset_inn : std_logic := '0';
  signal reset_out : std_logic;
  signal halt_inn  : std_logic := '0';
  signal halt_outn : std_logic;
  signal fc_out    : std_logic_vector(2 downto 0);
  signal avecn     : std_logic := '1';
  signal ipln      : std_logic_vector(2 downto 0) := (others => '1');
  signal ipendn    : std_logic;
  signal dsackn    : std_logic_vector(1 downto 0) := "11";
  signal size      : std_logic_vector(1 downto 0);
  signal asn       : std_logic;
  signal rwn       : std_logic;
  signal rmcn      : std_logic;
  signal dsn       : std_logic;
  signal ecsn      : std_logic;
  signal ocsn      : std_logic;
  signal dbenn     : std_logic;
  signal bus_en    : std_logic;
  signal stermn    : std_logic := '1';
  signal statusn   : std_logic;
  signal refilln   : std_logic;
  signal brn       : std_logic := '1';
  signal bgn       : std_logic;
  signal bgackn    : std_logic := '1';

  signal target_cycle_active : std_logic := '0';
  signal wait_counter        : integer range 0 to 8 := 0;
  signal target_low_cycles   : integer range 0 to 64 := 0;
  signal saw_coproc_cycle    : std_logic := '0';

  function rom_word(addr : std_logic_vector(31 downto 0)) return std_logic_vector is
  begin
    case to_integer(unsigned(addr(31 downto 2))) is
      when 0  => return x"00001000"; -- Initial SP
      when 1  => return x"00000020"; -- Initial PC
      when 8  => return x"207C0000"; -- MOVEA.L #$00000100,A0 (upper immediate)
      when 9  => return x"0100F210"; -- MOVEA immediate lower + COPROC opword
      when 10 => return x"00004E71"; -- COPROC extension word + NOP
      when 64 => return x"11223344"; -- Operand source at 0x00000100
      when others => return x"4E714E71";
    end case;
  end function;
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut: entity work.WF68K30L_TOP
    port map (
      CLK       => clk,
      ADR_OUT   => adr_out,
      DATA_IN   => data_in,
      DATA_OUT  => data_out,
      DATA_EN   => data_en,
      BERRn     => berrn,
      RESET_INn => reset_inn,
      RESET_OUT => reset_out,
      HALT_INn  => halt_inn,
      HALT_OUTn => halt_outn,
      FC_OUT    => fc_out,
      AVECn     => avecn,
      IPLn      => ipln,
      IPENDn    => ipendn,
      DSACKn    => dsackn,
      SIZE      => size,
      ASn       => asn,
      RWn       => rwn,
      RMCn      => rmcn,
      DSn       => dsn,
      ECSn      => ecsn,
      OCSn      => ocsn,
      DBENn     => dbenn,
      BUS_EN    => bus_en,
      STERMn    => stermn,
      STATUSn   => statusn,
      REFILLn   => refilln,
      BRn       => brn,
      BGn       => bgn,
      BGACKn    => bgackn
    );

  responder: process(all)
  begin
    data_in <= rom_word(adr_out);
    dsackn <= "11";

    if asn = '0' then
      if target_cycle_active = '1' and wait_counter > 0 then
        dsackn <= "11";
      else
        dsackn <= "00";
      end if;
    end if;
  end process;

  tracker: process(clk)
  begin
    if rising_edge(clk) then
      if asn = '0' and target_cycle_active = '0' and fc_out = "111" and rwn = '1' and adr_out = x"00000100" then
        target_cycle_active <= '1';
        wait_counter <= 4;
        target_low_cycles <= 1;
      elsif asn = '0' and target_cycle_active = '1' then
        target_low_cycles <= target_low_cycles + 1;
        if wait_counter > 0 then
          wait_counter <= wait_counter - 1;
        end if;
      elsif asn = '1' and target_cycle_active = '1' then
        saw_coproc_cycle <= '1';
        assert target_low_cycles >= 4
          report "Coprocessor operand-transfer cycle did not stall for DSACK wait states"
          severity failure;
        target_cycle_active <= '0';
        wait_counter <= 0;
      end if;
    end if;
  end process;

  stimulus: process
  begin
    report "Top coprocessor bus bench: start" severity note;

    for i in 0 to 20 loop
      wait until rising_edge(clk);
    end loop;
    reset_inn <= '1';
    halt_inn <= '1';

    for i in 0 to 1200 loop
      wait until rising_edge(clk);
      exit when saw_coproc_cycle = '1';
    end loop;

    assert bus_en = '1'
      report "BUS_EN did not become active after reset release"
      severity failure;
    assert saw_coproc_cycle = '1'
      report "No coprocessor operand-transfer bus cycle observed"
      severity failure;

    report "Top coprocessor bus bench: passed" severity note;
    finish;
  end process;

  watchdog: process
  begin
    wait for 20 us;
    assert false report "Top coprocessor bus bench timeout" severity failure;
  end process;
end architecture sim;
