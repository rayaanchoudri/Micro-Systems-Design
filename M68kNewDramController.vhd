---------------------------------------------------------------------------------------
-- Simple DRAM controller for the DE1 board, assuming a 50MHz dram controller/Dram memory clock
-- Assuming 8Mbyte SDRam organised as 4Mx16 bits with 4096 columns (12 bit column addr
-- 256 rows (8 bit row address) and 4 banks (2 bit bank address)
-- CAS latency is 2 clock periods
--
-- designed to work with TG68 (68000 based) cpu with 16 bit data bus and 32 bit address bus
-- separate upper and lowe data stobes for individual byte and also 16 bit word access
--
-- Copyright PJ Davies June 2011
---------------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;


entity M68kNewDramController is
	Port (
		Clock	 		: in std_logic ;						-- used to drive the state machine and various processes inside theis dram controller
		Reset_L    		: in std_logic ;     					-- active low reset in from the right most blue push button on the DE1
		Address    		: in std_logic_vector(31 downto 0);  	-- address bus in from 68000
		DataIn     		: in std_logic_vector(15 downto 0); 	-- data bus in from 68000
		UDS_L	   		: in std_logic ;						-- active low signal driven by 68000 when 68000 transferring data over data bits 15-8
		LDS_L	   		: in std_logic; 						-- active low signal driven by 68000 when 68000 transferring data over data bits 7-0
		DramSelect_L 	: in std_logic;     					-- active low signal indicating dram is being addressed by 68000, comes from address decoder logic inside this dram controller (you write it)
		WE_L 			: in std_logic;  						-- active low write signal from 68000, otherwise assumed to be read
		AS_L			: in std_logic;							-- address strobe from 68000 - good signal to have, assume that when it goes low, 68000 address is stable
																-- when it goes high, 68000 is terminating the dram read or write operation
		
		DataOut     	: out std_logic_vector(15 downto 0); 	-- data bus out to 68000, data from dram memory is presented to 68000 on this data bus during a read operation
		
		SDram_CKE_H   	: out std_logic;						-- active high clock enable out to the dram memory chip
		SDram_CS_L   	: out std_logic;						-- active low chip select for dram chip
		SDram_RAS_L   	: out std_logic;						-- active low RAS select for dram chip
		SDram_CAS_L   	: out std_logic;						-- active low CAS select for dram chip		
		SDram_WE_L   	: out std_logic;						-- active low Write enable for dram chip
		SDram_Addr   	: out std_logic_vector(11 downto 0);	-- 12 bit memory address bus to dram chip	
		SDram_BA   		: out std_logic_vector(1 downto 0) ;	-- 2 bit bank address to dram chip
		SDram_DQ   		: inout std_logic_vector(15 downto 0);  -- 16 bit bi-directional data lines to/from dram chip to this dram controller
		Dtack_L			: out std_logic ;						-- Dtack back to 68000 or used to introduce wait states
		ResetOut_L		: out std_logic; 						-- reset out to the CPU - this holds the CPU in a reset state after Reset_L above has been applied, until the Dram controller has finished
																-- initialising itself and is ready to accept read/write requests from 68000. This prevent the 68000 accessing the memory
																-- until the initialising of rmemory is complete. You have to drive this signal
	
		DramState 		: out std_logic_vector(4 downto 0) 		-- included for debugging so you can see how your state machine operarates
			
	);
end ;

architecture bhvr of M68kNewDramController is
	-- command constants for the Dram chip (combinations of 5 signals) use some or other of these
	
	constant PoweringUp 		    : std_logic_vector(4 downto 0) := "00000" ;		-- take CKE & CS low during power up phase, address and bank address = dont'care
	constant DeviceDeselect 		: std_logic_vector(4 downto 0) := "11111" ;		-- address and bank address = dont'care
	constant NOP 					: std_logic_vector(4 downto 0) := "10111" ;		-- address and bank address = dont'care
	constant BurstStop				: std_logic_vector(4 downto 0) := "10110" ;		-- address and bank address = dont'care
	constant ReadOnly 				: std_logic_vector(4 downto 0) := "10101" ;		-- A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = value
	constant ReadAutoPrecharge 		: std_logic_vector(4 downto 0) := "10101" ;		-- A10 should be logic 1, BA0, BA1 should be set to a value, other addreses = value
	constant WriteOnly 				: std_logic_vector(4 downto 0) := "10100" ;		-- A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = value
	constant WriteAutoPrecharge 	: std_logic_vector(4 downto 0) := "10100" ;		-- A10 should be logic 1, BA0, BA1 should be set to a value, other addreses = value
	constant AutoRefresh	 		: std_logic_vector(4 downto 0) := "10001" ;

	constant BankActivate			: std_logic_vector(4 downto 0) := "10011" ;		-- BA0, BA1 should be set to a value, address A11-0 should be value
	constant PrechargeSelectBank	: std_logic_vector(4 downto 0) := "10010" ;		-- A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = don't care
	constant PrechargeAllBanks		: std_logic_vector(4 downto 0) := "10010" ;		-- A10 should be logic 1, BA0, BA1 are dont'care, other addreses = don't care
	constant ModeRegisterSet		: std_logic_vector(4 downto 0) := "10000" ; 	-- A10=0, BA1=0, BA0=0, Address = don't care
	constant ExtModeRegisterSet		: std_logic_vector(4 downto 0) := "10000" ; 	-- A10=0, BA1=1, BA0=0, Address = value
	
	
	Signal  Command 				: std_logic_vector(4 downto 0) ;	-- 5 bit signal containing Dram_CKE_H, SDram_CS_L, SDram_RAS_L, SDram_CAS_L, SDram_WE_L
	Signal	Timer 					: std_logic_vector(15 downto 0) ;	-- 16 bit timer value
	Signal	TimerValue 				: std_logic_vector(15 downto 0) ;	-- 16 bit timer preload value
	Signal	TimerLoad_H 			: std_logic ;						-- logic 1 to load Timer on next clock
	Signal  TimerDone_H 			: std_logic ;						-- set to logic 1 when timer reaches 0
	Signal	RefreshTimer 			: std_logic_vector(15 downto 0) ;	-- 16 bit refresh timer value
	Signal	RefreshTimerValue 		: std_logic_vector(15 downto 0) ;	-- 16 bit refresh timer preload value
	Signal	RefreshTimerLoad_H 		: std_logic ;						-- logic 1 to load refresh timer on next clock
	Signal  RefreshTimerDone_H 		: std_logic ;						-- set to 1 when refresh timer reaches 0
	Signal  CurrentState 			: std_logic_vector(4 downto 0);		-- holds the current state of the dram controller
	Signal  NextState 				: std_logic_vector(4 downto 0);		-- holds the next state of the dram controller
	
	Signal  BankAddress 			: std_logic_vector(1 downto 0) ;	-- 2 bit bank address
	Signal  DramAddress 			: std_logic_vector(11 downto 0) ;	-- 12 bit row/column
	
	Signal	DramDataLatch_H			: std_logic ;						-- used to indicate that data from SDRAM should be latched and held for 68000 after the CAS latency period
	Signal  SDramWriteData			: std_logic_vector(15 downto 0) ;
	
	Signal  FPGAWritingtoSDram_H	: std_logic ;						-- When '1' enables FPGA data out lines leading to SDRAM to allow writing, otherwise they are set to Tri-State "Z"
	Signal  CPU_Dtack_L  			: std_logic ;						-- Dtack back to CPU
	Signal  CPUReset_L				: std_logic ;
	
	-- Dram controller states after power on and/or reset
	-- most dram chip data sheet imply only 2 auto refresh commands need be issued due power up, but
	-- Zental chip on DE1 says something about 8 auto refresh commands
	
-------------------------------------------------------------------------------------------------------------------------------------------------
-- Define some states for our dram controller add to these as required - only 4 will be defined at the moment - add your own as required
-------------------------------------------------------------------------------------------------------------------------------------------------
	
	constant InitialisingState			: std_logic_vector(4 downto 0) := "00000" ;	-- power on initialising state
	constant WaitingForPowerUpState		: std_logic_vector(4 downto 0) := "00001" ;	-- waiting for power up state to complete
	constant IssueFirstNOP				: std_logic_vector(4 downto 0) := "00010" ;	-- issuing 1st NOP after power up
	constant IssueSecondNOP				: std_logic_vector(4 downto 0) := "00011" ;	-- issuing 2nd NOP after power up
	constant PrechargingAllBanks		: std_logic_vector(4 downto 0) := "00100" ;	-- issuing precharge all command after power up
	constant IssuePreAutoRechargeNOP		: std_logic_vector(4 downto 0) := "00101" ;	-- issuing NOP after precharge all command
	constant Refresh						: std_logic_vector(4 downto 0) := "00110" ;	-- refresh for our 10 cycle refresh/tri-NOP
	constant Refresh_NOP_1				: std_logic_vector(4 downto 0) := "00111" ;	-- NOP 1 for our 10 cycle refresh/tri-NOP
	constant Refresh_NOP_2				: std_logic_vector(4 downto 0) := "01000" ;	-- NOP 2 for our 10 cycle refresh/tri-NOP
	constant Refresh_NOP_3				: std_logic_vector(4 downto 0) := "01001" ;	-- NOP 3 for our 10 cycle refresh/tri-NOP
	constant ProgramModeRegister		: std_logic_vector(4 downto 0) := "01010" ;	-- program the dram chip mode register command
	constant ProgramMR_NOP_1			: std_logic_vector(4 downto 0) := "01011" ;	-- NOP 1 after program mode register command
	constant ProgramMR_NOP_2			: std_logic_vector(4 downto 0) := "01100" ;	-- NOP 2 after program mode register command
	constant ProgramMR_NOP_3			: std_logic_vector(4 downto 0) := "01101" ;	-- NOP 3 after program mode register command
	constant IdleRefreshAndLoad			: std_logic_vector(4 downto 0) := "01110" ;	-- Load up refresh timers and refresh
	constant Idle						: std_logic_vector(4 downto 0) := "01111" ;	-- The idle state
	constant IssueRead						: std_logic_vector(4 downto 0) := "10000" ;	-- Issues read command
	constant IssueWriteOrWait			: std_logic_vector(4 downto 0) := "10001" ;	-- A wait state then writes to dram
	constant PostWriteWait			: std_logic_vector(4 downto 0) := "10010" ;	-- A wait state after dram write
	constant TerminateBusCycleWait			: std_logic_vector(4 downto 0) := "10011" ;	-- Wait for 68k to terminate bus cycle
	constant PostReadCASWait			: std_logic_vector(4 downto 0) := "10100" ;	-- Wait for CAS latency to expire
	constant IdleRefresh_NOP_1			: std_logic_vector(4 downto 0) := "10101" ;	-- Wait for CAS latency to expire
	
Begin
	
----------------------------------------------------------------------------------------------------------------------------------------------------------
-- General Timer for timing and counting things: Loadable and counts down on each clock then produced a TimerDone signal and stops counting
-- use for whatever purpose you want. Take TimerLoad_H to logic 1 to load the timer with the value = TimerValue (which you of course set to a value)
-- when the timer counts down on each clock and reaches 0, it drives TimerDone_H to a logic 1 and stops counting
----------------------------------------------------------------------------------------------------------------------------------------------------------

	Process(Clock, TimerLoad_H, Timer)
	BEGIN
		TimerDone_H <= '0' ;						-- default is not done
		if(rising_edge(Clock)) then
			if(TimerLoad_H = '1') then				-- if we get the signal from another process to load the timer
				Timer  <= TimerValue ;				-- Preload timer
			elsif(Timer /= 0) then					-- otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock		
				Timer <= Timer - 1 ;				-- subtract 1 from the timer value
			end if ;
		end if;
			
		if(Timer = 0) then							-- if timer has counted down to 0
			TimerDone_H <= '1' ;					-- output '1' to indicate time has elapsed
		end if ;
	END Process;			

----------------------------------------------------------------------------------------------------------------------------------------------------------
-- Refresh Timer: Loadable and counts down on each clock then produces a RefreshTimerDone signal and stops counting. Similar to above timer
----------------------------------------------------------------------------------------------------------------------------------------------------------

	Process(Clock, RefreshTimerLoad_H, RefreshTimer)
	BEGIN
		RefreshTimerDone_H <= '0' ;						-- default is not done
		if(rising_edge(Clock)) then
			if(RefreshTimerLoad_H = '1') then			-- if we get the signal from another process to load the timer
				RefreshTimer  <= RefreshTimerValue ;	-- Preload timer
			elsif(RefreshTimer /= 0) then				-- otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock		
				RefreshTimer <= RefreshTimer - 1 ;			-- subtract 1 from the timer value
			end if ;
		end if;
			
		if(RefreshTimer = 0) then						-- if timer has counted down to 0
			RefreshTimerDone_H <= '1' ;					-- output '1' to indicate time has elapsed
		end if ;
	END Process;			
	
---------------------------------------------------------------------------------------------------------------------
-- concurrent process state registers
-- this process RECORDS the current state of the system and produces the output signals to the Dram chip with every clock
----------------------------------------------------------------------------------------------------------------------

    process(Reset_L, Clock, NextState, FPGAWritingtoSDram_H)
	begin
		if(Reset_L = '0') then
			CurrentState <= InitialisingState ;			-- enter the Initialising state after a reset where we begin to program the dram chips with cas latency etc
			
		elsif (rising_edge(Clock)) then		-- state can change on low-to-high transition of clock. You decide what next state will be
			CurrentState <= NextState;		-- change to next state (state is only an output used for debugging - the dram chip does not need it)
			
			-- these are the raw signals that come from the dram controller to the dram memory chip. 
			-- This process expects the signals in the form of a 5 bit bus within the signal Command. The various Dram commands are defined above just beneath the architecture)

			SDram_CKE_H <= Command(4);		-- produce the Dram clock enable
			SDram_CS_L  <= Command(3);		-- produce the Dram Chip select
			SDram_RAS_L <= Command(2);		-- produce the dram RAS
			SDram_CAS_L <= Command(1);		-- produce the dram CAS
			SDram_WE_L  <= Command(0);		-- produce the dram Write enable
			
			SDram_Addr  <= DramAddress;		-- output the row/column address to the dram
			SDram_BA   	<= BankAddress;		-- output the bank address to the dram

			-- signals back to the 68000
			
			Dtack_L <= CPU_Dtack_L ;		-- output the Dtack back to the 68000
			ResetOut_L <= CPUReset_L ;		-- output the Reset out back to the 68000
			
			-- The signal FPGAWritingtoSDram_H can be driven by you when you need to turn on or tri-state the data bus out signals to the dram chip data lines DQ0-15
			-- when you are reading from the dram you have to ensure they are tristated (so the dram chip can drive them)
			-- when you are writing, you have to drive them to the value of SDramWriteData so that you 'present' your data to the dram chips
			-- of course during a write, the dram WE signal will need to be driven low and it will respond by tri-stating its outputs lines so you can drive data in to it
			-- remember the Dram chip has bi-directional data lines, when you read from it, it turns them on, when you write to it, it turns them off (tri-states them)
			
			if(FPGAWritingtoSDram_H = '1') then		-- if CPU is doing a write to dram, we need to turn on the FPGA data out lines to the SDRam and present Dram with CPU data 
				SDram_DQ	<= SDramWriteData ;
			else
				SDram_DQ	<= "ZZZZZZZZZZZZZZZZ" ;		-- otherwise tri-state the FPGA data output lines to the SDRAM for anything other than writing to it
			end if ;
			
			DramState <= CurrentState ;					-- output current state - useful for debugging so you can see you state machine changing states etc
		end if;
	end process;	
	
-----------------------------------------------------------------------------------------------------------------------
-- Concurrent process to Latch Data from Sdram after Cas Latency during read
-----------------------------------------------------------------------------------------------------------------------

-- this process will latch whatever data is coming out of the dram data lines on the falling edge of the clock you have to drive DramDataLatch_H to logic 1
-- remember there is a programmable CAS latency for the Zentel dram chip on the DE1 board it's 2 or 3 clock cycles which has to be programmed by you during the initialisation
-- phase of the dram controller following a reset/power on
--
-- During a read, after you have presented CAS command to the dram chip you will have to wait 2 or 3 clock cyles and then latch the data out here and present it back
-- to the 68000 until the end of the 68000 bus cycle

	process(Clock, DramDataLatch_H)
	begin
		if(falling_edge(Clock)) then
			if(DramDataLatch_H = '1') then     		-- asserted by your system controller during the read operation
				Dataout <= SDram_DQ ;				-- store 16 bits of data regardless of width of data requested by CPU
			end if ;
		end if ;
	end process ;
	
---------------------------------------------------------------------------------------------------------------------
-- next state and output logic
----------------------------------------------------------------------------------------------------------------------	
	
	process(Clock, Reset_L, Address, DataIn, AS_L, UDS_L, LDS_L, DramSelect_L, WE_L, CurrentState, TimerDone_H, RefreshTimerDone_H, Timer)
	begin
	
	-- In VHDL - you will recall - that combinational logic (i.e. logic with no storage) is created as long as you
	-- provide a specific value for a signal in each and every possible path through a process
	-- 
	-- You can do this of course, but it gets tedious to specify a value for each signal inside every process state and every if-else test within those states
	-- so the common way to do this is to define default values for all your signals and then override them with new values as and when you need to.
	-- By doing this here, righ at the start of a process, we ensure the VHDL compiler does not infer any storage for the signal, i.e. it creates
	-- pure combinational logic (which is what we want)
	--
	-- Let's start with default values for every signal and override as necessary, 
	--
	
		Command <= NOP ;							-- assume no operation command for Dram chip
		NextState <= InitialisingState ;			-- assume next state will always be initialising state unless overridden the value used here is not important, we cimple have to assign something to prevent storage on the signal so anything will do
		
		TimerValue <= "0000000000000000";			-- no timer value 
		RefreshTimerValue <= "0000000000000000" ;	-- no refresh timer value
		TimerLoad_H <= '0';							-- don't load Timer
		RefreshTimerLoad_H <= '0' ;					-- don't load refresh timer
		DramAddress <= "000000000000" ;				-- no particular dram address
		BankAddress <= "00" ;						-- no particular dram bank address
		DramDataLatch_H <= '0';						-- don't latch data yet
		CPU_Dtack_L <= '1' ;						-- don't acknowledge back to 68000
		SDramWriteData <= "0000000000000000" ;		-- nothing to write in particular
		CPUReset_L <= '0' ;							-- default is reset to CPU (for the moment, though this will change when design is complete so that reset-out goes high at the end of the dram initialisation phase to allow CPU to resume)
		FPGAWritingtoSDram_H <= '0' ;				-- default is to tri-state the FPGA data lines leading to bi-directional SDRam data lines, i.e. assume a read operation

	-- put your current state/next state decision making logic here - here are a few states to get you started
	-- during the initialising state, the drams have to power up and we cannot access them for a specified period of time (100 us)
	-- we are going to load the timer above with a value equiv to 100us and then wait for timer to time out
	
		if(CurrentState = InitialisingState ) then
			TimerValue <= "0000000000001000";				-- chose a value equivalent to 100us at 50Mhz clock - you might want to shorten it to somthing small for simulation purposes
			TimerLoad_H <= '1' ;							-- on next edge of clock, timer will be loaded and start to time out
			Command <= PoweringUp ;							-- clock enable and chip select to the Zentel Dram chip must be held low (disabled) during a power up phase
			NextState <= WaitingForPowerUpState ;			-- once we have loaded the timer, go to a new state where we wait for the 100us to elapse
		
		elsif(CurrentState = WaitingForPowerUpState) then
			Command <= PoweringUp ;							-- no DRam clock enable or CS while witing for 100us timer
			if(TimerDone_H = '1') then						-- if timer has timed out i.e. 100us have elapsed
				NextState <= IssueFirstNOP ;				-- take CKE and CS to active and issue a 1st NOP command
			else
				NextState <= WaitingForPowerUpState ;		-- otherwise stay here until power up time delay finished
			end if ;
		
		elsif(CurrentState = IssueFirstNOP) then	 		-- issue a valid NOP
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= IssueSecondNOP;
		-- add your other states and conditions here	
		elsif(CurrentState = IssueSecondNOP) then	 		-- issue a valid NOP
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= PrechargingAllBanks;
			
		elsif(CurrentState = PrechargingAllBanks) then	 		-- precharge all banks
			DramAddress(10) <= '1';										-- A10 must be 1
			Command <= PrechargeAllBanks ;
			NextState <= IssuePreAutoRechargeNOP;
			
		elsif(CurrentState = IssuePreAutoRechargeNOP) then	 		-- issue a valid NOP
			RefreshTimerValue <= "0000000000100111" ;					-- begin loading refresh timer to count down from 39 (b"100111") cycles (got 10 auto-refresh/tri-nop cycles)
			RefreshTimerLoad_H <= '1' ;
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= Refresh;
			
		elsif(CurrentState = Refresh) then	 		-- precharge all banks
			Command <= AutoRefresh ;
			NextState <= Refresh_NOP_1;
		elsif(CurrentState = Refresh_NOP_1) then	 		-- issue a valid NOP
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= Refresh_NOP_2;
		elsif(CurrentState = Refresh_NOP_2) then	 		-- issue a valid NOP
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= Refresh_NOP_3;
		elsif(CurrentState = Refresh_NOP_3) then	 		-- issue a valid NOP
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			if(RefreshTimerDone_H = '1') then						-- if timer has timed out i.e. 100us have elapsed
				NextState <= ProgramModeRegister ;				-- take CKE and CS to active and issue a 1st NOP command
			else
				NextState <= Refresh ;		-- otherwise stay here until power up time delay finished
			end if ;
			
		elsif(CurrentState = ProgramModeRegister) then	 		-- program mode register command
			Command <= ModeRegisterSet ;
			NextState <= ProgramMR_NOP_1;
		elsif(CurrentState = ProgramMR_NOP_1) then	 		-- issue a valid NOP
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= ProgramMR_NOP_2;
		elsif(CurrentState = ProgramMR_NOP_2) then	 		-- issue a valid NOP
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= ProgramMR_NOP_3;
		elsif(CurrentState = ProgramMR_NOP_3) then	 		-- issue a valid NOP
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <=   IdleRefreshAndLoad;
			
		elsif(CurrentState = IdleRefreshAndLoad) then	 		-- issue a valid NOP
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			RefreshTimerValue <= "0000000101110101" ;					-- begin loading refresh timer to count down from 373 (b"101110101") cycles to refesh every 7.5 us
			RefreshTimerLoad_H <= '1' ;
			Command <= AutoRefresh ;								-- refresh the chip
			NextState <=  IdleRefresh_NOP_1 ;								-- refreshes in idle states needs NOP states after the refresh
			
		elsif(CurrentState = IdleRefresh_NOP_1) then	 		-- issue a valid NOP
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= Idle;	
			
		elsif(CurrentState = Idle) then	 		-- issue a valid NOP
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			if (RefreshTimerDone_H = '1') then		-- once the refresh timer has counted down from 7.5 us go to the refresh state, otherwise wait
				NextState <= IdleRefreshAndLoad;
			elsif (DramSelect_L = '0' and AS_L = '0') then
				DramAddress <= Address(20 downto 9) ;	-- issue row address to SDRam (CPU A20-A9)
				BankAddress <= Address(22 downto 21) ;  -- issue bank address to SDRam (CPU A22-A21)
				Command <= BankActivate ;
				if ( WE_L = '1' ) then		-- command is read, next state is read state
					NextState <= IssueRead ;
				else								-- otherwise next state is a wait until signals are ready for write
					NextState <= IssueWriteOrWait ;
				end if ;
			else
				NextState <= Idle ;
			end if;
			
		elsif(CurrentState = IssueWriteOrWait) then	 		-- for writes, must first wait for UDS or LDS to go low, then write
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			if ( UDS_L = '0' or LDS_L = '0' ) then
				DramAddress <= "0100" & Address(8 downto 1) ;
				BankAddress <= Address(22 downto 21) ;  -- issue bank address to SDRam (CPU A22-A21)
				Command <= WriteAutoPrecharge ;		-- issue write auto precharge bank
				CPU_Dtack_L <= '0' ;						-- issue a dtack signal
				FPGAWritingtoSDram_H <= '1' ;   -- turn on the bidirectional data lines
				SDramWriteData <= DataIn;
				NextState <= PostWriteWait ;		-- next state is a wait cycle after dram write
			else
				Command <= NOP ;								-- send a valid NOP command to to the dram chip
				NextState <= IssueWriteOrWait ;		-- return to this state until uds and lds goes low
			end if;
			
		elsif(CurrentState = PostWriteWait) then	 		-- wait state after a write command was issued
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			CPU_Dtack_L <= '0' ;						-- issue a dtack signal
			Command <= NOP ;
			FPGAWritingtoSDram_H <= '1' ;   -- keep driving the bidirectional data lines
			SDramWriteData <= DataIn;
			NextState <= TerminateBusCycleWait ;			-- next state we wait for the 68k to terminate the current bs cycle

		elsif(CurrentState = IssueRead) then	 		-- issue read command state
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			DramAddress <= "0100" & Address(8 downto 1) ;
			BankAddress <= Address(22 downto 21) ;  -- issue bank address to SDRam (CPU A22-A21)
			Command <= ReadAutoPrecharge ;
			TimerValue <= "0000000000000010";				-- issue timer value of 2 clock cycles
			TimerLoad_H <= '1' ;							-- on next edge of clock, timer will be loaded and start to time out
			NextState <= PostReadCASWait ; -- wait for CAS latency to expire
			
		elsif(CurrentState = PostReadCASWait) then	 		-- wait for CAS latency to expire
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			CPU_Dtack_L <= '0' ;						-- issue a dtack signal
			Command <= NOP ;
			
			if (TimerDone_H = '1') then
				DramDataLatch_H <= '1' ;
				NextState <= Idle ;
			else
				NextState <= PostReadCASWait ;
			end if ;
			
		elsif(CurrentState = TerminateBusCycleWait) then	 		-- wait for 68k to terminate the current bus cycle
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			Command <= NOP ;
			if ( UDS_L = '0' or LDS_L = '0' ) then
				CPU_Dtack_L <= '0' ;						-- issue a dtack signal
				NextState <= TerminateBusCycleWait ;
			else
				NextState <= Idle ;
			end if ;

		else	 		-- catch all state
			CPUReset_L <= '1';											-- reset is off during after initialisation is complete
			Command <= NOP ;								-- send a valid NOP command to to the dram chip
			NextState <= Idle ;
			
		
		end if ;			

	end process;
end ;