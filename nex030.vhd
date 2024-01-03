library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

entity nex030 is port(
	clk_i			: in std_logic;
	reset_i			: in std_logic;
	
	clk100 : in std_logic;
	
	led : out std_logic_vector(7 downto 0);
	sw : in std_logic_vector(7 downto 0);
	
	COM_TxD          : out std_logic;
	MFP_SI          : in std_logic;
	
	              -- HyperRAM device interface
      hr_resetn   : out   std_logic;
      hr_csn_a      : out   std_logic_vector(3 downto 0);
      hr_ck,hr_ck_n       : out   std_logic;
      hr_rwds     : inout std_logic;
      hr_dq       : inout std_logic_vector(7 downto 0);
      fl_spi_cs: out std_logic := '1';
      fl_spi_clk : out std_logic;
      dq : inout std_logic_vector(3 downto 0);
      
        --CLK_PLL_16000
    CLK_PLL_16000, CLK_PLL_1474   : in std_logic
	);
end entity nex030;

architecture rtl of nex030 is

component WF68K30L_TOP is
    generic(VERSION     : std_logic_vector(31 downto 0) := x"20211224"; -- CPU version number.
        -- The following two switches are for debugging purposes. Default for both is false.
        NO_PIPELINE     : boolean := false;  -- If true the main controller work in scalar mode.
        NO_LOOP         : boolean := false; -- If true the DBcc loop mechanism is disabled.
        NO_BFOPS        : boolean := false);
    port (
        CLK             : in std_logic;

        -- Address and data:
        ADR_OUT         : out std_logic_vector(31 downto 0);
        DATA_IN         : in std_logic_vector(31 downto 0);
        DATA_OUT        : out std_logic_vector(31 downto 0);
        DATA_EN         : out std_logic; -- Enables the data port.

        -- System control:
        BERRn           : in std_logic;
        RESET_INn       : in std_logic;
        RESET_OUT       : out std_logic; -- Open drain.
        HALT_INn        : in std_logic;
        HALT_OUTn       : out std_logic; -- Open drain.

        -- Processor status:
        FC_OUT          : out std_logic_vector(2 downto 0);

        -- Interrupt control:
        AVECn           : in std_logic;
        IPLn            : in std_logic_vector(2 downto 0);
        IPENDn          : out std_logic;

        -- Aynchronous bus control:
        DSACKn          : in std_logic_vector(1 downto 0);
        SIZE            : out std_logic_vector(1 downto 0);
        ASn             : out std_logic;
        RWn             : out std_logic;
        RMCn            : out std_logic;
        DSn             : out std_logic;
        ECSn            : out std_logic;
        OCSn            : out std_logic;
        DBENn           : out std_logic; -- Data buffer enable.
        BUS_EN          : out std_logic; -- Enables ADR, ASn, DSn, RWn, RMCn, FC and SIZE.

        -- Synchronous bus control:
        STERMn          : in std_logic;

        -- Status controls:
        STATUSn         : out std_logic;
        REFILLn         : out std_logic;

        -- Bus arbitration control:
        BRn             : in std_logic;
        BGn             : out std_logic;
        BGACKn          : in std_logic
    );
end component;

component WF68901IP_TOP_SOC is
	port (  -- System control:
			CLK			: in std_logic;
			RESETn		: in std_logic;
			
			-- Asynchronous bus control:
			DSn			: in std_logic;
			CSn			: in std_logic;
			RWn			: in std_logic;
			DTACKn		: out std_logic;
			
			-- Data and Adresses:
			RS			: in std_logic_vector(5 downto 1);
			DATA_IN		: in std_logic_vector(7 downto 0);
			DATA_OUT	: out std_logic_vector(7 downto 0);
			DATA_EN		: out std_logic;
			GPIP_IN		: in std_logic_vector(7 downto 0);
			GPIP_OUT	: out std_logic_vector(7 downto 0);
			GPIP_EN		: out std_logic_vector(7 downto 0);
			
			-- Interrupt control:
			IACKn		: in std_logic;
			IEIn		: in std_logic;
			IEOn		: out std_logic;
			IRQn		: out std_logic;
			
			-- Timers and timer control:
			XTAL1		: in std_logic; -- Use an oszillator instead of a quartz.
			TAI			: in std_logic;
			TBI			: in std_logic;
			TAO			: out std_logic;			
			TBO			: out std_logic;			
			TCO			: out std_logic;			
			TDO			: out std_logic;			
			
			-- Serial I/O control:
			RC			: in std_logic;
			TC			: in std_logic;
			SI			: in std_logic;
			SO			: out std_logic;
			SO_EN		: out std_logic;
			
			-- DMA control:
			RRn			: out std_logic;
			TRn			: out std_logic			
	);
end component;

component hyperram is
 Port ( 
        sys_clock  : in std_logic;  -- Input clock
        cpu_resetn : in std_logic;  -- Reset signal (active-low)
        
        i_wstrb     : in std_logic_vector(3 downto 0);
        i_valid     : in std_logic;
        o_ready,o_init     : out std_logic;
        i_address   : in std_logic_vector(31 downto 0);
        i_write_data : in std_logic_vector(31 downto 0);
        o_read_data : out std_logic_vector(31 downto 0);
 
        o_csn        : out std_logic_vector(3 downto 0);
        o_clk        : out std_logic;
        o_clkn       : out std_logic;
        io_dq        : inout std_logic_vector(7 downto 0);
        io_rwds      : inout std_logic;
        o_resetn     : out std_logic);
end component;

component ROM_controller_SPI is
    PORT(clk_50, rst, read, write: in STD_LOGIC;
       si_i, si_o : out STD_LOGIC;
       si_t, wp_t: out STD_LOGIC;
       cs_n: out STD_LOGIC;
       wp: out STD_LOGIC;
       qd: in STD_LOGIC_VECTOR(3 downto 0);
      -- so, acc, hold: in STD_LOGIC;
       address_in: in STD_LOGIC_VECTOR(31 downto 0);
       data_out: out STD_LOGIC_VECTOR(15 downto 0);
       done, in_progress: out STD_LOGIC);
end component;

component spi_flash is
 Port (clk_i, rst, read, write: in STD_LOGIC;
       spi_o: out STD_LOGIC_vector(3 downto 0);
       spi_en: buffer STD_LOGIC_vector(3 downto 0);
       spi_in: in STD_LOGIC_VECTOR(3 downto 0);
       cs_n: out STD_LOGIC;

       address_in: in STD_LOGIC_VECTOR(31 downto 0);
       data_out: out STD_LOGIC_VECTOR(15 downto 0);

       done, in_progress: out STD_LOGIC
       );
end component;

--: std_logic_vector(31 downto 0);

component blk_mem_gen_1 IS
  PORT (
    clka : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    wea   : in std_logic_vector(3 downto 0)
  );
END component;

component boot_rom IS
  PORT (
    clka : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END component;

component cdc_control_data_addr is
    Port (
  clk_CPU : in STD_LOGIC;   -- CPU clock
        clk_MFP : in STD_LOGIC;   -- MFP clock
        reset_n : in STD_LOGIC;   -- Reset signal

        -- Control signals from CPU to MFP
        DSn_CPU : in STD_LOGIC;
        CSn_CPU : in STD_LOGIC;
        RWn_CPU : in STD_LOGIC;

        -- Address from CPU to MFP
        addr_CPU : in STD_LOGIC_VECTOR(5 downto 1);

        -- Data from CPU to MFP
        DATA_OUT_CPU : in STD_LOGIC_VECTOR(7 downto 0);

        -- Data from MFP to CPU
        DATA_OUT_MFP : in STD_LOGIC_VECTOR(7 downto 0);
        DTACKn_MFP : in STD_LOGIC;

        -- Synchronized control signals and data for MFP
        DSn_MFP_sync : out STD_LOGIC;
        CSn_MFP_sync : out STD_LOGIC;
        RWn_MFP_sync : out STD_LOGIC;
        addr_MFP_sync : out STD_LOGIC_VECTOR(5 downto 1);
        DATA_IN_MFP_sync : out STD_LOGIC_VECTOR(7 downto 0);

        -- Synchronized data and control signal for CPU
        DATA_IN_CPU_sync : out STD_LOGIC_VECTOR(7 downto 0);
        DTACKn_CPU_sync : out STD_LOGIC
    );
end component cdc_control_data_addr;


signal romdata_s		: std_logic_vector(15 downto 0);
signal sdram_data_out_s		: std_logic_vector(31 downto 0) := (others => '0');
signal sdram_data_in_s		: std_logic_vector(31 downto 0) := (others => '0');

signal stackram_out_s : std_logic_vector(31 downto 0);
signal stackram_cs : std_logic := '1';

signal cpu_data_in_s		: std_logic_vector(31 downto 0);
signal cpu_addr_s		: std_logic_vector(31 downto 0);
signal cpu_data_out_s		: std_logic_vector(31 downto 0);
signal cpu_fc_s			: std_logic_vector(2 downto 0);
signal cpu_size_s		: std_logic_vector(1 downto 0);
signal cpu_dsack_n_s		: std_logic_vector(1 downto 0);
signal cpu_ipl_n_s		: std_logic_vector(2 downto 0);
signal cpu_reset_n_s		: std_logic;
signal cpu_reset_out_s		: std_logic;
signal cpu_sterm_n_s		: std_logic;
signal cpu_lds_n_s		: std_logic;
signal cpu_uds_n_s		: std_logic;
signal cpu_br_n_s		: std_logic;
signal cpu_bg_n_s		: std_logic;
signal cpu_bgack_n_s		: std_logic;
signal cpu_berr_n_s		: std_logic;
signal cpu_as_n_s		: std_logic;
signal cpu_rw_n_s		: std_logic;
signal cpu_avec_n_s		: std_logic;
signal cpu_ds_s			: std_logic_vector(3 downto 0);

--signal fb_data_s		: std_logic_vector(15 downto 0);
signal resetcnt_s		: std_logic_vector(15 downto 0);
signal led_s			: std_logic_vector(7 downto 0);

signal sdram_we_s		: std_logic := '0';
signal sdram_busy_s		: std_logic := '0';
signal sdram_req_s		: std_logic := '0';
signal sdram_addr_s		: std_logic_vector(31 downto 0) := (others => '0');
signal sdram_cs_s		: std_logic := '0';
signal sdram_ds_s		: std_logic_vector(3 downto 0) := (others => '0');

signal reset_probe_s		: std_logic;
signal bootrom_cs_s		: std_logic;

signal gpib_cs_s		: std_logic;

signal clk_div_s		: std_logic_vector(1 downto 0);

signal high_s			: std_logic := '1';
signal low_s			: std_logic := '0';
type state_type is ( IDLE, SDRAM_WAIT, MFP_WAIT, ACK, ERROR );
signal bus_state_s		: state_type;

signal CLK_0M5,CLK_2M0,CLK_3686,CLK_115200, CLK115200x16, CLK_8 ,CLK_MFP_UART_TX,CLK_MFP_UART_RX  : std_logic := '0';
signal MFP_UART_FIXED_SPEED : std_logic := '1';

signal DATA_OUT_MFP         : std_logic_vector(7 downto 0);
signal DATA_EN_MFP          : std_logic;
signal DTACK_OUT_MFPn       : std_logic;
signal IACKn                : std_logic;
signal IPLn                 : std_logic_vector(2 downto 0);
signal MFP_CS_In            : std_logic;
signal MFP_SO_EN,MFP_SO            : std_logic;
signal MFPINTn              : std_logic;
signal TCO,TDO                  : std_logic;

signal fl_cs_s : std_logic; -- Start signal for read operation
signal fl_data_o  : std_logic_vector(15 downto 0);  -- Data output
signal fl_dtack : std_logic;

signal s_rst, s_read: std_logic;
signal clock_gate, gated_clock : std_logic := '1';
signal done, in_progress: std_logic;
signal s_cs_n, s_t_si, s_t_wp: std_logic;
signal si,so,acc,hold,wp : std_logic;
signal locked: std_logic;
signal qd, spi_o, spi_en: std_logic_vector(3 downto 0);
signal init_boot :std_logic := '0';

signal flash_address: std_logic_vector(31 downto 0);

attribute dont_touch : string;
attribute dont_touch of cpu_addr_s, DTACK_OUT_MFPn, cpu_data_in_s,cpu_data_out_s, cpu_dsack_n_s, cpu_as_n_s, cpu_rw_n_s, sdram_addr_s, bus_state_s, sdram_req_s, sdram_busy_s, sdram_cs_s :   signal is "true";
attribute dont_touch of Flash : label  is "true";

begin

  cpu_i: WF68K30L_TOP 
  port map(
    CLK => clk_i,
    DATA_IN => cpu_data_in_s,
    DATA_OUT => cpu_data_out_s,
    ADR_OUT => cpu_addr_s,
    BERRn => cpu_berr_n_s,
    RESET_INn => cpu_reset_n_s,
    HALT_INn => cpu_reset_n_s,
    RESET_OUT => cpu_reset_out_s,
    FC_OUT => cpu_fc_s,
    AVECn => cpu_avec_n_s,
    IPLn => cpu_ipl_n_s,
    DSACKn => cpu_dsack_n_s,
    SIZE => cpu_size_s,
    ASn => cpu_as_n_s,
    RWn => cpu_rw_n_s,
    STERMn => cpu_sterm_n_s,
    BRn => cpu_br_n_s,
    BGACkn => cpu_bgack_n_s);
    
      I_MFP: WF68901IP_TOP_SOC
        port map(
            -- System control:
            CLK                 => CLK_PLL_16000,
            RESETn              => cpu_reset_n_s,

            -- Asynchronous bus control:
            DSn                 => cpu_lds_n_s,
            CSn                 => MFP_CS_In,
            RWn                 => cpu_rw_n_s,
            DTACKn              => DTACK_OUT_MFPn,

            -- Data and Adresses:
            RS                  => cpu_addr_s(5 downto 1),
            DATA_IN             => cpu_data_out_s(7 downto 0),
            DATA_OUT            => DATA_OUT_MFP(7 downto 0),
            DATA_EN             => DATA_EN_MFP,
            GPIP_IN => sw,
            GPIP_OUT  => led,
            GPIP_EN  => open, -- Not used; all GPIPs are direction input.

            -- Interrupt control:
            IACKn               => IACKn,
            IEIn                => '0',
            -- IEOn             =>, -- Not used.
            IRQn                => MFPINTn,

            -- Timers and timer control:
            XTAL1               => CLK_3686,
            TAI                 => '0',
            TBI                 => '0',
            TAO              => open, -- Not used.
            TBO              => open, -- Not used.
            TCO              => TCO, -- Not used.
            TDO                 => TDO,

            -- Serial I/O control:
            RC                  => CLK_MFP_UART_RX,
            TC                  => CLK_MFP_UART_TX,
            SI                  => MFP_SI,--COM_RxD,
            SO                  => MFP_SO,
            SO_EN               => MFP_SO_EN

            -- DMA control:
            -- RRn              =>, -- Not used.
            -- TRn              => -- Not used.
        );

stack: blk_mem_gen_1 
  PORT map (
    clka => clk_i,
    addra => cpu_addr_s(13 downto 2), 
    douta => stackram_out_s,
    dina => cpu_data_out_s,
    wea => not (cpu_ds_s) and stackram_cs and not cpu_rw_n_s
  );
  
boot: boot_rom 
  PORT map (
    clka => clk_i,
    addra => cpu_addr_s( 8 downto 1), 
    douta => romdata_s
  );
  
Flash : Spi_Flash
 port map(
        clk_i => clk_i,
        rst => not cpu_reset_n_s,
        read => cpu_rw_n_s and fl_cs_s,
        write => not cpu_rw_n_s and fl_cs_s,
        spi_o => spi_o,
        spi_en => spi_en,
        cs_n => fl_spi_cs,
        spi_in => qd,

        address_in => x"00" & flash_address(23 downto 1) & '0', --x"00A00042", -- x"00" & flash_address(23 downto 0),  x"00" & flash_address(23 downto 0), -- x"00000000", --  --, ---- 
        data_out => fl_data_o,
        in_progress => in_progress,
        done => fl_dtack); 
        
 process(clk_i, cpu_reset_n_s) begin
    if( cpu_reset_n_s = '0') then
        clock_gate <= '1';
    elsif(rising_edge(clk_i)) then
        if(in_progress = '1') then
            clock_gate <= '0';
        else
            clock_gate <= '1';
        end if;
    end if;
end process;       
fl_spi_clk <= '1' when clock_gate = '1' else not(clk_i); 

dq(0) <= 'Z' when spi_en(0) = '1' else spi_o(0);
dq(1) <= 'Z' when spi_en(1) = '1' else spi_o(1);
dq(2) <= 'Z' when spi_en(2) = '1' else spi_o(2);
dq(3) <= 'Z' when spi_en(3) = '1' else spi_o(3);

-- QD is from the chip to us
qd(0) <= dq(0) when spi_en(0) = '1' else 'Z';
qd(1) <= dq(1) when spi_en(1) = '1' else 'Z';
qd(2) <= dq(2) when spi_en(2) = '1' else 'Z';
qd(3) <= dq(3) when spi_en(3) = '1' else 'Z';


  memory:  hyperram 
    port map (
        sys_clock  => clk100,
        cpu_resetn => cpu_reset_n_s,  -- Reset signal (active-low)
        
        i_wstrb     => sdram_ds_s,
        i_valid     => sdram_cs_s,
        o_init      => open,
        o_ready     => sdram_busy_s,
        i_address   => sdram_addr_s,
        i_write_data => sdram_data_in_s,
        o_read_data => sdram_data_out_s,
        o_csn       => hr_csn_a,               -- Connect to chip select 0 signal in your VHDL design
        o_clk        => hr_ck,            -- Connect to clock output signal in your VHDL design
        o_clkn       => hr_ck_n,           -- Connect to inverted clock output signal in your VHDL design
        io_dq        => hr_dq,                 -- Connect to data I/O signal in your VHDL design
        io_rwds      => hr_rwds,               -- Connect to read/write data strobe I/O signal in your VHDL design
        o_resetn     => hr_resetn
    );

cpu_bgack_n_s <= '1';
cpu_br_n_s <= '1';
cpu_sterm_n_s <= '1';
cpu_uds_n_s <= cpu_ds_s(3) and cpu_ds_s(1);
cpu_lds_n_s <= cpu_ds_s(2) and cpu_ds_s(0);
cpu_reset_n_s <= not reset_i;

clkdiv: process(reset_i, clk_i)
begin
	if (reset_i = '1') then
		clk_div_s <= (others => '0');
	elsif rising_edge(clk_i) then
		clk_div_s <= clk_div_s + 1;
	end if;
end process;


    P_AUX_CLOCKS: process
    -- The sound wave clock CLK_2M0 and the UART receiver,
    -- UART transmitter and sound clock CLK_0M5 are slow
    -- and therefore not possible to be provided by a PLL.
    -- Therefore this clock divider is adjusted to produce
    -- the required frequencies of 2MHz for the CLK_2M0 and
    -- 500kHz for the CLK_0M5. The Clocks are not used as
    -- clocks for d type flip-flops and therefore allowed
    -- as gated clocks.
    variable TMP: std_logic_vector(3 downto 0) := "0000";
    begin
        wait until CLK_PLL_16000 = '1' and CLK_PLL_16000' event; -- 16MHz.
        TMP := TMP + '1';
        case TMP is
            when "0000" =>
                CLK_0M5 <= not CLK_0M5;
                CLK_2M0 <= not CLK_2M0;
            when "0100" | "1000" | "1100" =>
                CLK_2M0 <= not CLK_2M0;
            when others => null;
        end case;
    end process P_AUX_CLOCKS;

--P_ClocksMFP: process (clk_i)
--    -- Constants for division factors
--    constant DIVISOR_3686: integer := 7;
--    variable counter_3686: integer := 0;
--begin
--    if rising_edge(clk_i) then
--        -- Counter and toggle for 38,400 baud clock (x16)
--        counter_3686 := counter_3686 + 1;
--        if counter_3686 >= DIVISOR_3686 then
--            counter_3686 := 0;
--            CLK_3686 <= not CLK_3686;
--        end if;
--    end if;
--end process P_ClocksMFP;

process(CLK_PLL_1474)
variable counter: integer := 0;
    begin
        if rising_edge(CLK_PLL_1474) then
            if counter = 1 then
                counter := 0;
                CLK_3686 <= not CLK_3686;  -- Toggle the output clock
            else
                counter := counter + 1;  -- Increment the counter
            end if;
        end if;
    end process;


P_ClocksSerial: process (CLK_PLL_16000)
    -- Constants for division factors
    constant DIVISOR_115200x16: integer := 4; --69;  -- Adjust for 115200 baud
    variable counter_115200x16: integer := 0;
    constant DIVISOR_115200: integer := 69;  -- Adjust for 115200 baud
    variable counter_115200: integer := 0;
begin
    if rising_edge(CLK_PLL_16000) then
        -- Counter and toggle for clock 
        counter_115200 := counter_115200 + 1;
        
        if counter_115200 >= DIVISOR_115200 then
            counter_115200 := 0;
            CLK_115200 <= not CLK_115200;
        end if;
        
        counter_115200x16 := counter_115200x16 + 1;
        
        if counter_115200x16 >= DIVISOR_115200x16 then
            counter_115200x16 := 0;
            CLK115200x16 <= not CLK115200x16;
        end if;
 
    end if;
end process P_ClocksSerial;

     CLK_MFP_UART_TX <= TDO when MFP_UART_FIXED_SPEED = '0' else CLK_115200;
     CLK_MFP_UART_RX <= TCO when MFP_UART_FIXED_SPEED = '0' else CLK115200x16;
    -- Serial port:
    COM_TxD <= MFP_SO when MFP_SO_EN = '1' else 'Z';

ipl: process(reset_i, clk_i)
begin
	if (reset_i = '1') then
		cpu_ipl_n_s <= (others => '1');
	elsif rising_edge(clk_i) then
	    cpu_ipl_n_s <= "111";
	end if;
end process;

dsgen: process(clk_i)
begin
	if (rising_edge(clk_i)) then
		cpu_ds_s(3) <= not(cpu_rw_n_s or (not cpu_addr_s(0) and not cpu_addr_s(1)));
		cpu_ds_s(2) <= not(cpu_rw_n_s or (not cpu_size_s(0) and not cpu_addr_s(1)) or (not cpu_addr_s(1) and cpu_addr_s(0)) or (cpu_size_s(1) and not cpu_addr_s(1)));
		cpu_ds_s(1) <= not(cpu_rw_n_s or (not cpu_addr_s(0) and cpu_addr_s(1)) or (not cpu_addr_s(1) and not cpu_size_s(0) and not cpu_size_s(1)) or (cpu_size_s(1) and cpu_size_s(0) and not cpu_addr_s(1)) or (not cpu_size_s(0) and not cpu_addr_s(1) and cpu_addr_s(0)));
		cpu_ds_s(0) <= not(cpu_rw_n_s or (cpu_addr_s(0) and cpu_size_s(0) and cpu_size_s(1)) or (not cpu_size_s(0) and not cpu_size_s(1)) or (cpu_addr_s(0) and cpu_addr_s(1)) or (cpu_addr_s(1) and cpu_size_s(1)));
	end if;
end process;

addr_decode: process(reset_i, clk_i)
    variable offset: std_logic_vector(31 downto 0);
begin
	if (reset_i = '1') then
		bus_state_s <= IDLE;
		init_boot <= '0';
	elsif (rising_edge(clk_i)) then
		case bus_state_s is
			when IDLE =>
			     sdram_cs_s <= '0';
				cpu_dsack_n_s <= "11";
				cpu_berr_n_s <= '1';
				bootrom_cs_s <= '0';
				stackram_cs <= '0';
				MFP_CS_In <= '1';
				fl_cs_s <= '0';
				if (cpu_as_n_s = '0' and cpu_fc_s /= 7) then
					cpu_avec_n_s <= '1';
					if (cpu_addr_s(31 downto 16) = x"00fc" or  (cpu_addr_s >= x"00000000" and cpu_addr_s <= x"00000007" and init_boot = '0') ) then
						bootrom_cs_s <= '1';
						bus_state_s <= ACK;
				    elsif (cpu_addr_s < x"00001000") then
				        stackram_cs <= '1';
				        bus_state_s <= ACK;
				    elsif (cpu_addr_s(31 downto 16) = x"00fe") then
				        offset := cpu_addr_s - x"FE0000";
				        flash_address <= x"a00000" + offset;
					   	fl_cs_s <= '1';
					    if fl_dtack = '1' then
						  bus_state_s <= ACK;
						end if;
					elsif (cpu_addr_s(31 downto 16) = x"00FD") then
					   	MFP_CS_In <= '0';
					    if DTACK_OUT_MFPn = '0' then
						  bus_state_s <= MFP_WAIT;
						end if;
				    elsif (cpu_addr_s < x"fc0000") then -- hyperram apart from stack
				            bus_state_s <= SDRAM_WAIT;
				            sdram_addr_s <= cpu_addr_s;
                            sdram_data_in_s <= cpu_data_out_s;
                            sdram_req_s <= '1';
                            sdram_we_s <= not cpu_rw_n_s;
                            sdram_data_in_s <= cpu_data_out_s;
					else
						cpu_berr_n_s <= '0';
						bus_state_s <= ERROR;
					 end if;
				elsif (cpu_as_n_s = '0' and cpu_fc_s = 7) then
					cpu_avec_n_s <= '0';
				else
					cpu_avec_n_s <= '1';
				end if;
				
		    when MFP_WAIT =>
		      	MFP_CS_In <= '0';
		      	bus_state_s <= ACK;
		      	
			when SDRAM_WAIT =>
			    sdram_cs_s <= '1';
                if (cpu_rw_n_s = '0') then
                    sdram_ds_s <= not cpu_ds_s;
                else
                    sdram_ds_s <= "0000";
                end if;

				if (sdram_busy_s = '1') then
				    sdram_req_s <= '0';
					bus_state_s <= ACK;
				end if;

		  	when ACK =>
					if(stackram_cs = '1' or sdram_cs_s = '1') then
						cpu_dsack_n_s <= "00";
				    elsif (bootrom_cs_s = '1' or fl_cs_s = '1') then
				        cpu_dsack_n_s <= "01";
					else
						cpu_dsack_n_s <= "10";
					end if;
					
			    if cpu_addr_s = x"00000006" then
			         init_boot <= '1';
			    end if;

				if (cpu_as_n_s = '1') then
					cpu_dsack_n_s <= "11";
					bus_state_s <= IDLE;
					bootrom_cs_s <= '0';
					stackram_cs <= '0';
					sdram_cs_s <= '0';
					fl_cs_s <= '0';
                    MFP_CS_In <= '1';
				 end if;

			when ERROR =>
				cpu_berr_n_s <= '0';
				if (cpu_as_n_s = '1') then
					bus_state_s <= IDLE;
				end if;
		end case;
	end if;
end process;

cpu_data_in_s <= 
        x"00000000" when cpu_addr_s = x"00000000" else
        x"10001000" when cpu_addr_s = x"00000002" else
        x"00fc00fc" when cpu_addr_s = x"00000004" else
        x"00000000" when cpu_addr_s = x"00000006" else
        romdata_s & romdata_s when bootrom_cs_s = '1' else
        stackram_out_s when stackram_cs = '1' else
        DATA_OUT_MFP & DATA_OUT_MFP & DATA_OUT_MFP & DATA_OUT_MFP when MFP_CS_In = '0' else
		sdram_data_out_s when sdram_cs_s = '1' else
		fl_data_o & fl_data_o when fl_cs_s = '1' else 
		x"ffffffff";

end rtl;
