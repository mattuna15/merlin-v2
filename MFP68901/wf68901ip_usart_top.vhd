------------------------------------------------------------------------
----                                                                ----
---- ATARI MFP compatible IP Core					                ----
----                                                                ----
---- This file is part of the SUSKA ATARI clone project.            ----
---- http://www.experiment-s.de                                     ----
----                                                                ----
---- Description:                                                   ----
---- MC68901 compatible multi function port core.                   ----
----                                                                ----
---- This is the SUSKA MFP IP core USART top level file.            ----
----                                                                ----
----                                                                ----
---- To Do:                                                         ----
---- -                                                              ----
----                                                                ----
---- Author(s):                                                     ----
---- - Wolfgang Foerster, wf@experiment-s.de; wf@inventronik.de     ----
----                                                                ----
------------------------------------------------------------------------
----                                                                ----
---- Copyright © 2006... Wolfgang Foerster - Inventronik GmbH.      ----
----                                                                ----
---- This source file may be used and distributed without           ----
---- restriction provided that this copyright statement is not      ----
---- removed from the file and that any derivative work contains    ----
---- the original copyright notice and the associated disclaimer.   ----
----                                                                ----
---- This source file is free software; you can redistribute it     ----
---- and/or modify it under the terms of the GNU Lesser General     ----
---- Public License as published by the Free Software Foundation;   ----
---- either version 2.1 of the License, or (at your option) any     ----
---- later version.                                                 ----
----                                                                ----
---- This source is distributed in the hope that it will be         ----
---- useful, but WITHOUT ANY WARRANTY; without even the implied     ----
---- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR        ----
---- PURPOSE. See the GNU Lesser General Public License for more    ----
---- details.                                                       ----
----                                                                ----
---- You should have received a copy of the GNU Lesser General      ----
---- Public License along with this source; if not, download it     ----
---- from http://www.gnu.org/licenses/lgpl.html                     ----
----                                                                ----
------------------------------------------------------------------------
-- 
-- Revision History
-- 
-- Revision 2K6A  2006/06/03 WF
--   Initial Release.
-- Revision 2K6B  2006/11/07 WF
--   Modified Source to compile with the Xilinx ISE.
-- Revision 2K8A  2008/07/14 WF
--   Minor changes.
-- Revision 2K13B  2013/12/24 WF
--   Separate Transmit and receive buffer and  some
--      minor changes. Thanks to Peter Neways (20121218).
-- Revision 2K15B  20151224 WF
--   Replaced the data type bit by std_logic.
-- Revision 2K21A 20211224 WF
--   Control: fixed a SDOUT_EN bug. Now the output is always active when transmitter is enabled.
--

use work.wf68901ip_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity WF68901IP_USART_TOP is
	port (  -- System control:
			CLK			: in std_logic;
			RESETn		: in std_logic;
			
			-- Asynchronous bus control:
			DSn			: in std_logic;
			CSn			: in std_logic;
			RWn			: in std_logic;
			
			-- Data and Adresses:
			RS			: in std_logic_vector(5 downto 1);
			DATA_IN		: in std_logic_vector(7 downto 0);
			DATA_OUT	: out std_logic_vector(7 downto 0);
			DATA_OUT_EN	: out std_logic;

			-- Serial I/O control:
			RC			: in std_logic; -- Receiver clock.
			TC			: in std_logic; -- Transmitter clock.
			SI			: in std_logic; -- Serial input.
			SO			: out std_logic; -- Serial output.
			SO_EN		: out std_logic; -- Serial output enable.
			
			-- Interrupt channels:
			RX_ERR_INT	: out std_logic; -- Receiver errors.
			RX_BUFF_INT	: out std_logic; -- Receiver buffer full.
			TX_ERR_INT	: out std_logic; -- Transmitter errors.
			TX_BUFF_INT	: out std_logic; -- Transmitter buffer empty.

			-- DMA control:
			RRn			: out std_logic;
			TRn			: out std_logic		;
			
			dtack_rx        : out std_logic	;
			dtack_tx  : out std_logic
	);
end entity WF68901IP_USART_TOP;

architecture STRUCTURE of WF68901IP_USART_TOP is
	signal BF_I				: std_logic;
	signal BE_I				: std_logic;
	signal FE_I				: std_logic;
	signal OE_I				: std_logic;
	signal UE_I				: std_logic;
	signal PE_I				: std_logic;
	signal LOOPBACK_I		: std_logic;
	signal SD_LEVEL_I		: std_logic;
	signal SDATA_IN_I		: std_logic;
	signal SDATA_OUT_I		: std_logic;
	signal RXCLK_I			: std_logic;
	signal CLK_MODE_I		: std_logic;
	signal SCR_I			: std_logic_vector(7 downto 0);
	signal RX_SAMPLE_I		: std_logic;
	signal RX_DATA_I		: std_logic_vector(7 downto 0);
	signal TX_DATA_I		: std_logic_vector(7 downto 0);
	signal CL_I				: std_logic_vector(1 downto 0);
	signal ST_I				: std_logic_vector(1 downto 0);
	signal P_ENA_I			: std_logic;
	signal P_EOn_I			: std_logic;
	signal RE_I				: std_logic;
	signal TE_I				: std_logic;
	signal FS_CLR_I			: std_logic;
	signal SS_I				: std_logic;
	signal M_CIP_I			: std_logic;
	signal FS_B_I			: std_logic;
	signal BR_I				: std_logic;
	signal UDR_READ_I		: std_logic;
	signal UDR_WRITE_I		: std_logic;
	signal RSR_READ_I		: std_logic;
	signal TSR_READ_I		: std_logic;
	signal TX_END_I			: std_logic;
	
	component WF68901IP_USART_RX is
  port (
		CLK			: in std_logic;
        RESETn		: in std_logic;

		SCR			: in std_logic_vector(7 downto 0); -- Synchronous character. 
		RX_SAMPLE	: out std_logic; -- Flag indicating valid shift register data.
        RX_DATA		: out std_logic_vector(7 downto 0); -- Received data.

        RXCLK		: in std_logic; -- Receiver clock.
        SDATA_IN	: in std_logic; -- Serial data input.

		CL			: in std_logic_vector(1 downto 0); -- Character length.
		ST			: in std_logic_vector(1 downto 0); -- Start and stop bit configuration.
		P_ENA		: in std_logic; -- Parity enable.
		P_EOn		: in std_logic; -- Even or odd parity.
		CLK_MODE	: in std_logic; -- Clock mode configuration bit.
		REx			: in std_logic; -- Receiver enable.
		FS_CLR		: in std_logic; -- Clear the Found/Search flag for resynchronisation purpose.
		SS			: in std_logic; -- Synchronous strip enable.
		UDR_READ	: in std_logic; -- Flag indicating reading the data register.
		RSR_READ	: in std_logic; -- Flag indicating reading the receiver status register.

		M_CIP		: out std_logic; -- Match/Character in progress.
		FS_B		: out std_logic; -- Find/Search or Break detect flag.
		BF			: out std_logic; -- Buffer full.
		OE			: out std_logic; -- Overrun error.
		PE			: out std_logic; -- Parity error.
		FE			: out std_logic;  -- Framing error.
		dtack        : out std_logic
       );                                              
end component WF68901IP_USART_RX;

	component WF68901IP_USART_TX is
  port (
		CLK			: in std_logic;
        RESETn		: in std_logic;

		SCR			: in std_logic_vector(7 downto 0); -- Synchronous character.
		TX_DATA		: in std_logic_vector(7 downto 0); -- Normal data.

        SDATA_OUT	: out std_logic; -- Serial data output.
        TXCLK		: in std_logic;  -- Transmitter clock.

		CL			: in std_logic_vector(1 downto 0); -- Character length.
		ST			: in std_logic_vector(1 downto 0); -- Start and stop bit configuration.
		TEx			: in std_logic; -- Transmitter enable.
		BR			: in std_logic; -- BREAK character send enable (all '0' without stop bit).
		P_ENA		: in std_logic; -- Parity enable.
		P_EOn		: in std_logic; -- Even or odd parity.
		UDR_WRITE	: in std_logic; -- Flag indicating writing the data register.
		TSR_READ	: in std_logic; -- Flag indicating reading the transmitter status register.
		CLK_MODE	: in std_logic; -- Transmitter clock mode.

		TX_END		: out std_logic; -- End of transmission flag.
		UE			: out std_logic; -- Underrun Flag.
		BE			: out std_logic := '0'; -- Buffer empty flag.
		dtack        : out std_logic
       );                                              
end component WF68901IP_USART_TX;

begin
	SO <= SDATA_OUT_I when TE_I = '1' else SD_LEVEL_I;
	-- Loopback mode:
	SDATA_IN_I 	<= 	SDATA_OUT_I when LOOPBACK_I = '1' and TE_I = '1' else 	  -- Loopback, transmitter enabled.
					'1' 		when LOOPBACK_I = '1' and TE_I = '0' else SI; -- Loopback, transmitter disabled.

	RXCLK_I 	<= 	TC when LOOPBACK_I = '1' else RC;
	RRn <= '0' when BF_I = '1' and PE_I = '0' and FE_I = '0' else '1';
	TRn <= not BE_I;

	-- Interrupt sources:
	RX_ERR_INT 	<= OE_I or PE_I or FE_I or FS_B_I;
	RX_BUFF_INT	<= BF_I;
	TX_ERR_INT 	<= UE_I or TX_END_I;
	TX_BUFF_INT <= BE_I;

	I_USART_CTRL: WF68901IP_USART_CTRL
	port map(
			CLK				=> CLK,
	        RESETn			=> RESETn,
			DSn				=> DSn,
			CSn				=> CSn,
	        RWn     		=> RWn,
	        RS				=> RS,
			DATA_IN			=> DATA_IN,
			DATA_OUT		=> DATA_OUT,
			DATA_OUT_EN		=> DATA_OUT_EN,
			LOOPBACK		=> LOOPBACK_I,
			SDOUT_EN		=> SO_EN,
			SD_LEVEL		=> SD_LEVEL_I,
			CLK_MODE		=> CLK_MODE_I,
			RE				=> RE_I,
			TE				=> TE_I,
			P_ENA			=> P_ENA_I,
			P_EOn			=> P_EOn_I,
			BF				=> BF_I,
			BE				=> BE_I,
			FE				=> FE_I,
			OE				=> OE_I,
			UE				=> UE_I,
			PE				=> PE_I,
			M_CIP			=> M_CIP_I,	
			FS_B			=> FS_B_I,
			SCR_OUT			=> SCR_I,
			TX_DATA			=> TX_DATA_I,
			RX_SAMPLE		=> dtack_rx,
			RX_DATA			=> RX_DATA_I,
			SS				=> SS_I,
			BR				=> BR_I,
			CL				=> CL_I,
			ST				=> ST_I,
			FS_CLR			=> FS_CLR_I,
			UDR_READ		=> UDR_READ_I,
			UDR_WRITE		=> UDR_WRITE_I,
			RSR_READ		=> RSR_READ_I,
			TSR_READ		=> TSR_READ_I,
			TX_END			=> TX_END_I
	);                                              

	I_USART_RECEIVE: WF68901IP_USART_RX
	port map (
			CLK				=> CLK,
	        RESETn			=> RESETn,
			SCR				=> SCR_I,
			RX_SAMPLE		=> RX_SAMPLE_I,
			RX_DATA			=> RX_DATA_I,
			CL				=> CL_I,
			ST				=> ST_I,
			P_ENA			=> P_ENA_I,
			P_EOn			=> P_EOn_I,
			CLK_MODE		=> '1',
			REx				=> RE_I,
			FS_CLR			=> FS_CLR_I,
			SS				=> SS_I,
			RXCLK			=> RXCLK_I,
			SDATA_IN		=> SDATA_IN_I,
			RSR_READ		=> RSR_READ_I,
			UDR_READ		=> UDR_READ_I,
			M_CIP			=> M_CIP_I,	
			FS_B			=> FS_B_I,
			BF				=> BF_I,
			OE				=> OE_I,
			PE				=> PE_I,
			FE				=> FE_I,
						dtack => dtack_rx
	);                                              

	I_USART_TRANSMIT: WF68901IP_USART_TX
	port map (
			CLK				=> CLK,
	        RESETn			=> RESETn,
			SCR				=> SCR_I,
			TX_DATA			=> TX_DATA_I,
	        SDATA_OUT		=> SDATA_OUT_I,
	        TXCLK			=> TC,
			CL				=> CL_I,
			ST				=> ST_I,
			TEx				=> TE_I,
			BR				=> BR_I,
			P_ENA			=> P_ENA_I,
			P_EOn			=> P_EOn_I,
			UDR_WRITE		=> UDR_WRITE_I,
			TSR_READ		=> TSR_READ_I,
			CLK_MODE		=> '0',
			TX_END			=> TX_END_I,
			UE				=> UE_I,
			BE				=> BE_I,
						dtack => dtack_tx
	);                  
end architecture STRUCTURE;
