----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.11.2023 07:04:53
-- Design Name: 
-- Module Name: hyperram - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity hyperram is
 Port ( 
        sys_clock  : in std_logic;  -- Input clock
        cpu_resetn : in std_logic;  -- Reset signal (active-low)
        
        i_wstrb     : in std_logic_vector(3 downto 0);
        i_valid     : in std_logic;
        o_ready, o_init     : out std_logic;
        i_address   : in std_logic_vector(31 downto 0);
        i_write_data : in std_logic_vector(31 downto 0);
        o_read_data : out std_logic_vector(31 downto 0);
        
        o_csn        : out std_logic_vector(3 downto 0);
        o_clk        : out std_logic;
        o_clkn       : out std_logic;
        io_dq        : inout std_logic_vector(7 downto 0);
        io_rwds      : inout std_logic;
        o_resetn     : out std_logic);
end hyperram;

architecture Behavioral of hyperram is

       
-- State type declaration
    type STATE_TYPE is (IDLE, INIT_WRITE, WRITE, INIT_READ, READ, WAIT_READ, DONE);
    signal state : STATE_TYPE := IDLE;
     
    signal startup_wait : std_logic := '0';
      
          component hbc_wrapper is
    port (
        i_clk        : in  std_logic;
        i_rstn       : in  std_logic;
        i_cfg_access : in  std_logic;
        i_mem_valid  : in  std_logic;
        o_mem_ready  : out std_logic;
        i_mem_wstrb  : in  std_logic_vector(3 downto 0);
        i_mem_addr   : in  std_logic_vector(31 downto 0);
        i_mem_wdata  : in  std_logic_vector(31 downto 0);
        o_mem_rdata  : out std_logic_vector(31 downto 0);
        o_csn0       : out std_logic;
        o_clk        : out std_logic;
        o_clkn       : out std_logic;
        io_dq        : inout std_logic_vector(7 downto 0);
        io_rwds      : inout std_logic;
        o_resetn     : out std_logic
    );
end component;

        signal o_csn0       :  std_logic;

begin
        
hbc_wrapper_inst : hbc_wrapper
    port map (
        i_clk        => sys_clock,                -- Connect to the clock signal in your VHDL design
        i_rstn       => cpu_resetn,               -- Connect to the reset signal (active low) in your VHDL design
        i_cfg_access => '0',         -- Connect to configuration access signal in your VHDL design
        i_mem_valid  => i_valid,          -- Connect to memory valid signal in your VHDL design
        o_mem_ready  => o_ready,          -- Connect to memory ready signal in your VHDL design
        i_mem_wstrb  => i_wstrb,          -- Connect to memory write strobe signal in your VHDL design
        i_mem_addr   => i_address,           -- Connect to memory address signal in your VHDL design
        i_mem_wdata  => i_write_data,          -- Connect to memory write data signal in your VHDL design
        o_mem_rdata  => o_read_data,          -- Connect to memory read data signal in your VHDL design
        o_csn0       => o_csn0,               -- Connect to chip select 0 signal in your VHDL design
        o_clk        => o_clk,            -- Connect to clock output signal in your VHDL design
        o_clkn       => o_clkn,           -- Connect to inverted clock output signal in your VHDL design
        io_dq        => io_dq,                 -- Connect to data I/O signal in your VHDL design
        io_rwds      => io_rwds,               -- Connect to read/write data strobe I/O signal in your VHDL design
        o_resetn     => o_resetn              -- Connect to reset (active low) output signal in your VHDL design
    );
    
--    Chip 0: 0x00000000 to 0x007FFFFF
--Chip 1: 0x00800000 to 0x00FFFFFF
--Chip 2: 0x01000000 to 0x017FFFFF
--Chip 3: 0x01800000 to 0x01FFFFFF
    
chip_select: process(o_csn0)
begin    
    case i_address(23 downto 22) is
            when "00" =>
                o_csn(0) <= o_csn0; -- Activate chip 0
                o_csn(3 downto 1) <= (others => '1');
            when "01" =>
                o_csn(1) <= o_csn0; -- Activate chip 1
                o_csn(0) <= '1';
                o_csn(3 downto 2) <= (others => '1');
            when "10" =>
                o_csn(3) <= '1';
                o_csn(1 downto 0) <= (others => '1');
                o_csn(2) <= o_csn0; -- Activate chip 2
            when "11" =>
                o_csn(3) <= o_csn0; -- Activate chip 3
                o_csn(2 downto 0) <= (others => '1');
            when others =>
                o_csn <= (others => '1'); 
        end case;
end process;    


end Behavioral;
