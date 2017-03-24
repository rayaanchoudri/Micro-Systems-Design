LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 

-- this circuit produces the Dtack_L signal back to the 68k
-- you must ensure 68k gets a Dtack_L when it issues an address otherwise it will generate WAIT states for ever

entity Dtack_Generator is
	Port (
		AS_L	: in std_logic ;  				-- address strobe	from 68k
		DE2512kRamSelect_H : in std_logic;	-- Modification for Assignment 1 step 3
		DramSelect_H : in std_logic ;			-- from address decoder
		FlashSelect_H : in std_logic ;		-- from address decoder
	   DramDtack_L : in std_logic ;			-- from Dram controller
	   FlashDtack_L : in std_logic ;			-- from Flash controller
	   GraphicsCS_L : in std_logic ;			-- from address decoder
	   DtackOut_L : out std_logic 			-- to CPU
	);
end ;


architecture bhvr of Dtack_Generator is
Begin
	process(AS_L, DE2512kRamSelect_H,  DramSelect_H, FlashSelect_H, DramDtack_L, FlashDtack_L, GraphicsCS_L)
	begin
		
		DtackOut_L <= '1' ;					-- default is no Dtack IN BETWEEN bus cycles (when AS_L = '1')

--		-- MODIFIED TO GIVE AN ACTIVE LOW DtackOut_L when DE2512kRamSelect_H is high
--			if(DE2512kRamSelect_H = '1')	then 
--				DtackOut_L <= '0' ;
--			end if;
--			
--		-- MODIFIED TO GIVE AN ACTIVE LOW DtackOut_L when DE2512kRamSelect_H is high
--			if(GraphicsCS_L = '0')	then 
--				DtackOut_L <= '0' ;
--			end if;

		-- however in VHDL we can override the above "default output" with other outputs
		-- e.g. if the address decoder is telling us that the CPU is access say the Flash memory (e.g. FlashSelect_H above is logic 1), then we could delay
		-- producing a Dtack back to the CPU until sometime later (i.e. introduce wait states)
		--
		-- This would be done by getting the Flash controller to load a pre-loadable timer when AS_L is '1' and let it count down to zero when AS_L = '0'
		-- when the time delay elapses we could take a signal from the timer saying it has reached 0 and use this to provide the dtack back the 68k
		-- it could provide the DramDtack_L input that could be used to provide rthe 68k Dtack
				
		
		if(AS_L = '0' )	then 					-- When AS active 68k is accessing something so we get to produce a Dtack here if we chose
			if(FlashSelect_H = '0' and DramSelect_H = '0' )	then		-- if flash is being selected and for example it needed wait states
				DtackOut_L <= '0';	-- copy the timeout signal from the flash controller and give this as the dtack to the 68k
			end if ;													-- this will be the default that covers things like on chip RAM/ROM and IO devices like LEDs, switches, graphics, DMA etc
													-- this default may or may not work for off chip devices like Flash, Dram etc
			--
			-- if however the memory or IO is known to be slow and thus wait states ARE needed, i.e. we cannot just produce the dtack immediately as above
			-- then we can override the above DtackOut_L <= '0' statement with another based on an IF test
			-- e.g. if Flash is being selected then take the dtack signal produced from the flash controller (which may well come from a timer/counter) and give that to the 68k
			-- However you only need to override the above default DtackOut_L <= '0' when you KNOW you need to introduce wait states
			-- For devices that are fast enough NOT to need wait states, the above default will work
			-- IMPORTANT - if you modify this file, realise that this circuit produces Dtack for ALL devices/chips in the system so make sure it still works for those chips after you modify this circuit
			-- If your system hangs after modifications, run the simulator and check whether Dtack is being produced with each access. If not - you've screwed up
			--
			
			-- here's an example that show how we overrider the default DtackOut_L <= '0' above so that DtackOut_L is produced when we want (not straight away)
			-- in this example the dtack generator looks at the address decoder output and if the 68k is accessing the Flash chip (i.e. FlashSelect_H equals '1')
			-- we generate DtackOut_L as a copy of the signal produced by the Flash controller (i.e. the signal FlashDtack_L) which comes from a timer built into the flash controller
			-- we can add extra 'if' tests to cover all the other kinds of things that may need a dtack other than the deafult above e.g. dram controller etc
			
			if(FlashSelect_H = '1')	then		-- if flash is being selected and for example it needed wait states
				DtackOut_L <= FlashDtack_L;	-- copy the timeout signal from the flash controller and give this as the dtack to the 68k
			end if ;

		-- MODIFIED TO GIVE AN ACTIVE LOW DtackOut_L when DramSelect_H is 1 and DramDtack_L is 0
			if(DramSelect_H = '1')	then 
				DtackOut_L <= DramDtack_L ;
			end if;
		
		-- MODIFIED TO GIVE AN ACTIVE LOW DtackOut_L when DE2512kRamSelect_H is high
			if(DE2512kRamSelect_H = '1')	then 
				DtackOut_L <= '0' ;
			end if;
			
		-- MODIFIED TO GIVE AN ACTIVE LOW DtackOut_L when GraphicsCS_L is low
			if(GraphicsCS_L = '0')	then 
				DtackOut_L <= '0' ;
			end if;	

		end if ;	
	end process ;
END ;

