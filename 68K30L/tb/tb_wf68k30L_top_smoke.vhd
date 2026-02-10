library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_wf68k30L_top_smoke is
end entity tb_wf68k30L_top_smoke;

architecture sim of tb_wf68k30L_top_smoke is
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

  signal saw_fetch : std_logic := '0';
  signal saw_cycle : std_logic := '0';

  function rom_word(addr : std_logic_vector(31 downto 0)) return std_logic_vector is
  begin
    case to_integer(unsigned(addr(31 downto 2))) is
      when 0 => return x"00001000"; -- Initial SP
      when 1 => return x"00000020"; -- Initial PC
      when 8 => return x"4E714E71"; -- NOP; NOP
      when others     => return x"4E714E71";
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

  -- Minimal read responder for instruction/data cycles.
  responder: process(all)
  begin
    dsackn <= "11";
    data_in <= rom_word(adr_out);
    if asn = '0' then
      dsackn <= "00";
    end if;
  end process;

  tracker: process(clk)
  begin
    if rising_edge(clk) then
      if asn = '0' then
        saw_cycle <= '1';
      end if;
      if asn = '0' and rwn = '1' then
        saw_fetch <= '1';
      end if;
    end if;
  end process;

  stimulus: process
  begin
    report "Top smoke bench: start" severity note;

    -- Hold reset active (RESET_INn low), then release.
    for i in 0 to 20 loop
      wait until rising_edge(clk);
    end loop;
    reset_inn <= '1';
    halt_inn <= '1';

    -- Wait for fetch/bus activity.
    for i in 0 to 400 loop
      wait until rising_edge(clk);
      exit when saw_fetch = '1';
    end loop;

    assert saw_cycle = '1'
      report "No bus cycle observed on WF68K30L_TOP"
      severity failure;
    assert saw_fetch = '1'
      report "No read/fetch cycle observed on WF68K30L_TOP"
      severity failure;
    assert bus_en = '1'
      report "BUS_EN did not become active after reset release"
      severity failure;

    report "Top smoke bench: passed" severity note;
    finish;
  end process;

  watchdog: process
  begin
    wait for 12 us;
    assert false report "Top smoke bench timeout" severity failure;
  end process;
end architecture sim;
