library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity IC_SPI_BUS_Decoder is
	port(
		Address 						: in Std_logic_vector(31 downto 0) ;
		IOSelect_H					: in std_logic ;
		UDS_L							: in std_logic ; -- output signal below depends on this being active low
		
		IICO_Enable_H				: out std_logic
	
	);
end entity IC_SPI_BUS_Decoder;

architecture behavioural of IC_SPI_BUS_Decoder is
Begin
	process(Address, IOSelect_H, UDS_L )
	begin
		-- default value of the output witch enables the tristates is '0' for off
		IICO_Enable_H <= '0' ;
		
		-- if both io select and uds signals are active, then check if we are in the right address range
		if ( IOSelect_H = '1' and UDS_L = '0' ) then
		
			if (Address(31 downto 4) = B"0000_0000_0100_0000_1000_0000_0000") then
				IICO_Enable_H <= '1' ;
			end if;
		
		end if ;
	
	
	
	end process ;
END ;