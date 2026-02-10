library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

library work;
use work.WF68K30L_PKG.all;

entity tb_wf68k30L_coproc_decode is
end entity tb_wf68k30L_coproc_decode;

architecture sim of tb_wf68k30L_coproc_decode is
begin
  stimulus: process
  begin
    assert DECODE_COPROC_EW_FORMAT(x"F200", x"0000") = COPROC_EW_FMOVE
      report "Expected FMOVE-class decode"
      severity failure;

    assert DECODE_COPROC_EW_FORMAT(x"F200", x"A000") = COPROC_EW_ARITH_TRANSC
      report "Expected arithmetic/transcendental decode"
      severity failure;

    assert DECODE_COPROC_EW_FORMAT(x"F3C0", x"0000") = COPROC_EW_FSAVE_FRESTORE
      report "Expected FSAVE/FRESTORE-class decode"
      severity failure;

    assert DECODE_COPROC_EW_FORMAT(x"F280", x"0000") = COPROC_EW_BRANCH
      report "Expected FP-branch decode"
      severity failure;

    assert DECODE_COPROC_EW_FORMAT(x"F2C0", x"0000") = COPROC_EW_TRAP
      report "Expected FP-trap decode"
      severity failure;

    assert DECODE_COPROC_EW_FORMAT(x"4E71", x"0000") = COPROC_EW_NONE
      report "Expected non-coprocessor decode to return COPROC_EW_NONE"
      severity failure;

    report "Coprocessor extension-word decode bench: passed" severity note;
    finish;
  end process;

  watchdog: process
  begin
    wait for 500 ns;
    assert false report "Coprocessor extension-word decode bench timeout" severity failure;
  end process;
end architecture sim;
