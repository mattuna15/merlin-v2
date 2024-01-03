library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_flash is
 Port (clk_i, rst, read, write: in STD_LOGIC;
       spi_o: out STD_LOGIC_vector(3 downto 0) := "1111";
       spi_en: buffer STD_LOGIC_vector(3 downto 0);
       spi_in: in STD_LOGIC_VECTOR(3 downto 0);
       cs_n: out STD_LOGIC;

       address_in: in STD_LOGIC_VECTOR(31 downto 0);
       data_out: out STD_LOGIC_VECTOR(15 downto 0);

       done, in_progress: out STD_LOGIC
       );
end spi_flash;

architecture Behavioral of spi_flash is


signal buffered_read : std_logic_vector(3 downto 0);
signal hp_mode: std_logic := '0';

type IO_MODE is (SINGLE_SPI, DOUBLE_SPI, QUAD_SPI);
signal current_mode: IO_MODE := SINGLE_SPI;

type CONTROL_STATES is (SETUP, SEND_CMD, SEND_ADDR, TRANSFER_DATA, READ_DATA, FINISH);
signal CURRENT_STATE	: CONTROL_STATES;

type OPERATION is (RD, WRT, CMD);
signal operation_type: OPERATION := CMD;

subtype small_int is integer range 0 to 16;
subtype counter_int is integer range 0 to 128;
    signal counter : counter_int := 0;
    signal data_count : small_int := 0;

signal cfg_access : std_logic := '0'; --1 if access to config 
signal cmd_length : natural := 8; -- Command length in bits
signal mode_bytes : std_logic_vector(3 downto 0) := x"A";
signal addr_length : natural := 24; -- Address length in bits
signal data_length : natural := 16; -- Data length in bits
signal buffer_length : natural := 64; -- total length in bits
signal out_length : natural := 8;
signal spi_buffer : std_logic_vector(127 downto 0);

signal in_progress_reg, start_wren,read_done  : std_logic := '0';
signal start_init, init_done: std_logic := '1';



    constant WREG : std_logic_vector(7 DOWNTO 0) := X"01";
    constant WREN : std_logic_vector(7 DOWNTO 0) := X"06";
    constant WR_REG : std_logic_vector(7 DOWNTO 0) := X"01";
    -- fast reads only. 23 bit addresses
    constant READ_IO : std_logic_vector(7 DOWNTO 0) := X"0B";
    constant DUAL_IO : std_logic_vector(7 DOWNTO 0) := X"BB";
    constant QUAD_IO : std_logic_vector(7 DOWNTO 0) := X"EB";
    
--    attribute dont_touch : string;
--    attribute dont_touch of latch_data_in : label  is "true";
begin

in_progress <= in_progress_reg;

init: process(clk_i, rst) 
begin
    
    if (rst = '1') then
        start_wren <= '0';
        start_init <= '0';
    end if;

    if rising_edge(clk_i) then
        if rst = '0' and CURRENT_STATE = SETUP and init_done = '0' then
            if start_wren = '0' then
                start_wren <= '1';
                start_init <= '0';
            elsif start_wren = '1' then
                start_wren <= '0';
                start_init <= '1';
            end if;
        end if;
    end if;

end process;


bit_counter: process(clk_i, rst)
begin
if rst = '1' then
    counter <= 0;
elsif rising_edge(clk_i) then
    if (CURRENT_STATE = TRANSFER_DATA or CURRENT_STATE = READ_DATA) and in_progress_reg = '1' then
        if counter < cmd_length then
            counter <= counter + 1;
        else
            case current_mode is
                when SINGLE_SPI =>
                    counter <= counter + 1;
                when DOUBLE_SPI =>
                    counter <= counter + 2;
                when QUAD_SPI =>
                    counter <= counter + 4;
                when others =>
                    -- Handle other cases or add a default behavior if needed
            end case;
        end if;
    else
        counter <= 0;
    end if;
end if;

end process;

latch_data_in: process(rst, clk_i)
begin
    if rst = '1' then
        data_count <= 0;
        read_done <= '0';
    elsif rising_edge(clk_i) then
        if  CURRENT_STATE = TRANSFER_DATA then
            read_done <= '0';
            data_count <= 0;
        elsif  CURRENT_STATE = READ_DATA and counter >= 48 then
            if data_count < 16 then
                case current_mode is
                    when SINGLE_SPI =>
                        data_out(15 - data_count) <= spi_in(1);
                        data_count <= data_count + 1;
        
                    when DOUBLE_SPI =>
                        if data_count < 15 then -- Ensure data_count doesn't exceed 14
                            data_out(15 - data_count) <= spi_in(1);
                            data_out(14 - data_count) <= spi_in(0);
                            data_count <= data_count + 2;
                        end if;
        
                    when QUAD_SPI =>
                        if data_count < 13 then -- Ensure data_count doesn't exceed 12
                            data_out(15 - data_count) <= spi_in(3);
                            data_out(14 - data_count) <= spi_in(2);
                            data_out(13 - data_count) <= spi_in(1);
                            data_out(12 - data_count) <= spi_in(0);
                            data_count <= data_count + 4;
                        end if;
        
                    when others =>
                        -- Handle other cases or do nothing
                end case;
            elsif data_count >= 16 then
                read_done <= '1';
            end if;
        elsif in_progress_reg = '0' then
            data_count <= 0;
        end if;
    end if;
end process;



control : process (clk_i, rst)
variable start: integer := 0;
begin
    
    if rst = '1' then
        cs_n <= '1';
        done <= '0';
        in_progress_reg <= '0';
        init_done <= '0';
        spi_en <= "0000";
        CURRENT_STATE <= SETUP;
    elsif rising_edge(clk_i) then
        case CURRENT_STATE is
            when SETUP =>
                -- Setup phase based on operation_type, io_mode, cmd_length, etc.
                done <= '0';
                
                if start_wren = '1' and init_done = '0' then
                    operation_type <= CMD;
                    spi_buffer(127 downto 120) <= WREN;
                    spi_buffer(119 downto 0) <= (others => '0');
                    cs_n <= '0';
                    CURRENT_STATE <= SEND_CMD;
                elsif start_init = '1' and init_done = '0' then
                    init_done <= '1';
                    operation_type <= CMD;
                    spi_buffer(127 downto 120) <= WREG;
                    spi_buffer(119 downto 112) <= (others => '0');
                    spi_buffer(111 downto 104) <= "11000010"; -- update latency code and enable quad.
                    cmd_length <= 24;
                    cs_n <= '0';
                    CURRENT_STATE <= SEND_CMD;
                elsif(read = '1' or write = '1') then
                    cs_n <= '0';
                    
                    -- read or write
                    if read = '1' then 
                        operation_type <= RD;
                    elsif write = '1' then
                        operation_type <= WRT;
                    end if;
                    
                    -- high performance flag
--                    if hp_mode = '1' then
--                        CURRENT_STATE <= SEND_ADDR;
--                        buffer_length <= 0;
--                        out_length <= 0;
--                        cmd_length <= 0;
--                    else
                    --    hp_mode <= '1';
                        cmd_length <= 8;
                        CURRENT_STATE <= SEND_CMD;
      --              end if;
                end if;

            when SEND_CMD =>
                -- Send command based on cmd_length
                -- ...
      --          signal io_mode : std_logic_vector(1 downto 0); -- '001' for single, '010' for dual, '100' for quad
      --              signal operation_type : std_logic_vector(1 downto 0); -- Define operation types '00' - read '01' -write  '10' send '11'write reg 
                if operation_type = CMD then
                    buffer_length <= cmd_length;
                    out_length <= cmd_length;
                    current_mode <= SINGLE_SPI;
                    CURRENT_STATE <= TRANSFER_DATA;
                elsif operation_type = WRT then  --write
                
                else
                    current_mode <= QUAD_SPI; -- quad
                    spi_buffer(127 downto 120) <= QUAD_IO;
                    buffer_length <= cmd_length;
                    out_length <= cmd_length;
                    CURRENT_STATE <= SEND_ADDR;
                end if;

            when SEND_ADDR =>
                -- Send address based on addr_length
                -- ...
                
                start := 127-cmd_length;
                
                spi_buffer(start downto start-23) <= address_in(23 downto 0); 
                spi_buffer(start-24 downto start-31) <= mode_bytes & "ZZZZ"; -- mode
                --spi_buffer(start-32 downto start-32-4) <= (others => 'Z'); --dummy
                out_length <= out_length + 24 + 8;
                buffer_length <= buffer_length + 24 + 8 + 4 + 16; -- command/address/mode/dummy/data
                in_progress_reg <= '1';
                CURRENT_STATE <= TRANSFER_DATA;

            when TRANSFER_DATA =>
                -- Data transfer based on data_length and operation_type (read/write)
                -- ...
                    in_progress_reg <= '1';
                    if counter >= out_length and operation_type = RD then
                        CURRENT_STATE <= READ_DATA;
                    else 
                        spi_en <= "0000";
                    end if;
                
                if (in_progress_reg = '1' and counter >= buffer_length-1 and operation_type /= RD) then
                    spi_en <= "0000";
                    CURRENT_STATE <= FINISH;
                    in_progress_reg <= '0';
                end if;

            when READ_DATA =>
            
                case current_mode is
                   when SINGLE_SPI => spi_en <= "0010";
                   when DOUBLE_SPI => spi_en <= "0011";
                   when QUAD_SPI => spi_en <= "1111";
                end case;
                    
                if read_done = '1' then
                    spi_en <= "0000";
                    CURRENT_STATE <= FINISH;
                    in_progress_reg <= '0';
                end if;
                
            when FINISH =>
                -- Completion state
                -- ...
                cs_n <= '1';
                done <= '1';
                
                if (read = '0' and write = '0') then
                    CURRENT_STATE <= SETUP;
                end if;
                
            -- Include other necessary states
            when others =>
        end case;
    end if;

end process control;


ctr_fsm: process(clk_i, rst) 

begin
  if(rst = '1') then
    spi_o(3 downto 2) <= "11";
 --   first_read <= '1';
  elsif rising_edge(clk_i) then
  
    -- '001' for single, '010' for dual, '100' for quad
    -- Define operation types '00' - read '01' -write  '10' send 
    
    if counter < buffer_length and CURRENT_STATE = TRANSFER_DATA then
        if (operation_type = RD) then -- read
            if counter < out_length then
                   if counter < cmd_length then
                      spi_o(0) <= spi_buffer(127 - counter);
                      spi_o(3 downto 2) <= "11";
                   else
                      case current_mode is
                        when SINGLE_SPI =>
                            spi_o(0) <= spi_buffer(127 - counter);
                            spi_o(3 downto 2) <= "11";
                    
                        when DOUBLE_SPI =>
                            spi_o(0) <= spi_buffer(127 - counter);
                            spi_o(1) <= spi_buffer(127 - (counter + 1));
                            spi_o(3 downto 2) <= "11";
                    
                        when QUAD_SPI =>
                            spi_o(0) <= spi_buffer(127 - (counter + 3));
                            spi_o(1) <= spi_buffer(127 - (counter + 2));
                            spi_o(2) <= spi_buffer(127 - (counter + 1));
                            spi_o(3) <= spi_buffer(127 - counter);
                    
                        when others =>
                            -- Handle other cases or add a default behavior if needed
                    end case;
                end if;
            else
            --                if io_mode = "001" then
--                    data_out(15 - data_count) <= spi_in(1);
--                elsif io_mode = "010" then
--                    data_out(15 - data_count) <= spi_in(0);
--                    data_out(15 - (data_count + 1)) <= spi_in(1);
--                elsif io_mode = "100" then
--                    data_out(15 - data_count) <= spi_in(0);
--                    data_out(15 - (data_count + 1)) <= spi_in(1);
--                    data_out(15 - (data_count + 2)) <= spi_in(2);
--                    data_out(15 - (data_count + 3)) <= spi_in(3);
--                end if; 
--                if io_mode = "001" then
--                    data_out(15 - data_count) <= spi_in(1);
--                    spi_o(3 downto 2) <= "11";
--                    spi_en <= "0010";
--                elsif io_mode = "010" then
--                    data_out(15 - data_count) <= spi_in(0);
--                    data_out(15 - (data_count + 1)) <= spi_in(1);
--                    spi_o(3 downto 2) <= "11";
--                    spi_en <= "0011";
--                elsif io_mode = "100" then
--                    data_out(15 - data_count) <= spi_in(0);
--                    data_out(15 - (data_count + 1)) <= spi_in(1);
--                    data_out(15 - (data_count + 2)) <= spi_in(2);
--                    data_out(15 - (data_count + 3)) <= spi_in(3);
--                end if; 
            
                
            end if;
            
        else
            case current_mode is
                when SINGLE_SPI =>
                    spi_o(0) <= spi_buffer(127 - counter);
                    spi_o(3 downto 2) <= "11";
                when DOUBLE_SPI =>
                    spi_o(0) <= spi_buffer(127 - counter);
                    spi_o(1) <= spi_buffer(127 - (counter + 1));
                    spi_o(3 downto 2) <= "11";
                when QUAD_SPI =>
                    spi_o(0) <= spi_buffer(127 - counter);
                    spi_o(1) <= spi_buffer(127 - (counter + 1));
                    spi_o(2) <= spi_buffer(127 - (counter + 2));
                    spi_o(3) <= spi_buffer(127 - (counter + 3));
              end case;
        end if;
    end if;
    
  end if;
end process;

end Behavioral;