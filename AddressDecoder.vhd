LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 

entity AddressDecoder is
	Port (
		Address 						: in Std_logic_vector(31 downto 0) ;		-- address directly from 68k
		
		-- outputs to activate rom,ram, sram, dram etc as per labs
		
		OnChipRomSelect_H 		: out Std_Logic ;
		OnChipRamSelect_H 		: out Std_Logic ;
		DramSelect_H 				: out Std_logic ;
		DE2_512KSRamSelect_H 	: out Std_logic;
		IOSelect_H 					: out Std_logic;
		FlashSelect_H 				: out Std_logic;
		DMASelect_L 				: out Std_logic;
		GraphicsCS_L 				: out Std_logic 
	);
end ;


architecture bhvr of AddressDecoder is
Begin
	process(Address)
	begin
		
		-- default values for all memory and IO Select Signals (default is NOT activated)
		-- override as required using if-endif statements based on range of addresses issued by 68k
		
		OnChipRomSelect_H <= '0' ;
		OnChipRamSelect_H <= '0' ;
		DramSelect_H <= '0' ;
		DE2_512KSRamSelect_H <= '0';
		IOSelect_H <= '0' ;
		FlashSelect_H <= '0' ;
		DMASelect_L <= '1' ;
		GraphicsCS_L <= '1' ;
	
		if(Address( 31 downto 15) = B"0000_0000_0000_0000_0") then 	-- ON CHIP ROM address hex 0000 0000 - 0000 7FFF 32k full decoding
			OnChipRomSelect_H <= '1' ;											-- DO NOT CHANGE - debugger expects rom at this address
		end if ;	
		
		if(Address( 31 downto 14) = B"0000_0000_0000_0001_00") then -- address hex 0001 0000 - 0001 3FFF 16k full decoding
			OnChipRamSelect_H <= '1' ;											-- DO NOT CHANGE - debugger expects Ram at this address
		end if ;	
			
		if(Address(31 downto 16) = B"0000_0000_0100_0000") then 		-- address hex 0040 0000 - 0040 FFFF Partial decoding
			IOSelect_H <= '1' ;													-- DO NOT CHANGE - debugger expects IO at this address
		end if ;
			
--		if(Address(31 downto 19) = B"0000_0000_1000_0") then 		-- address hex 0080 0000 - 0087 FFFF Partial decoding
--			DE2_512KSRamSelect_H <= '1' ;									-- DO NOT CHANGE - debugger expects 512KSRamSelect at this address
--		end if ;

		if(Address(31 downto 19) = B"1111_0000_0000_0") then 		-- address hex F000 0000 - F007 FFFF Partial decoding
			DE2_512KSRamSelect_H <= '1' ;									-- DO NOT CHANGE - debugger expects 512KSRamSelect at this address
		end if ;
		
		if(Address(31 downto 23) = B"0000_0001_0") then 		-- address hex 0100 0000 - 017F FFFF Partial decoding
			FlashSelect_H <= '1' ;									-- DO NOT CHANGE - debugger expects Flash at this address
		end if ;

--		if(Address(31 downto 23) = B"1111_0000_0") then 		-- address hex F000 0000 - F07F FFFF Partial decoding
--			DramSelect_H <= '1' ;									-- DO NOT CHANGE - debugger expects Dram at this address
--		end if ;
		
		if(Address(31 downto 23) = B"0000_0000_1") then 		-- address hex 0080 0000 - 00FF FFFF Partial decoding
			DramSelect_H <= '1' ;									-- DO NOT CHANGE - debugger expects Dram at this address
		end if ;
		
		if(Address(31 downto 8) = B"1111_1111_0001_0000_0000_0000") then 		-- address hex FF10 0000 - FF10 00FF Partial decoding
			GraphicsCS_L <= '0' ;									-- DO NOT CHANGE - debugger expects graphics controller at this address
		end if ;
		
		-- add other decoder signals here for Sram, Dram, Flash, Graphics etc to fix their range of addresses (see relavent Lab/Assignment)
		-- SRam (i.e. DE2_512KSramSelect_H) should be active high when 68k accesses address in range 00800000 - 0087FFFF
			
	end process ;
END ;