LIBRARY ieee;
USE ieee.Std_Logic_1164.all;
-- use ieee.Std_Logic_arith.all; 
-- use ieee.Std_Logic_signed.all; 
use ieee.numeric_std.all; 
-------------------------------------------------------------------------------------------------------------------------------------- 
entity GraphicsController is
 Port ( 
  		Clk,Reset_L 									: in Std_Logic;										-- 50Mhz clock and an active low reset		 
		
-- 68k interface signals

		AddressIn 										: in  Std_Logic_Vector(31 downto 0);			-- 32 bit address bus from 68k 
		DataIn68k 										: in  Std_Logic_Vector(15 downto 0);			-- 16 bit data bus into graphics controller from 68k
		DataOut68k									   : out Std_Logic_Vector(15 downto 0);			-- 16 bit data bus out from graphics controller back to 68k


		AS_L, UDS_L, LDS_L, RW 						: in Std_Logic;										-- address and upper/lower data strobes and R/W* from 68k
		GraphicsCS_L									: in Std_Logic; 		 								-- CS from main computer address decoder 
																														
																														-- currently activated for addresses in range FF100000 - FF1000FF
-- VGA display driver signals (the circuit actually displaying the contents of the frame buffer)

		HSync_L											: in Std_Logic;										-- Horizontal sync from VGA controller
		InterleaveDraw_L								: in Std_Logic;										-- this signal i active LOW whenever it is safe from Graphics
																														-- controller to read/write (i.e. draw) to SRam memory (Frame buffer)
																														-- without producing interference on screen (use this to decide when to read/write)

-- Sram interface signals (The 512k Sram on the DE2 that represents the frame buffer - it holds the image that we display)
-- each byte represents a pixel. The data for each pixel represents the number of a entry in the colour pallette ROM, that is
-- each byte contains a pallette number which in turn represents a colour composed of 24 bit RGB

		SRam_DataIn										: in Std_Logic_Vector(15 downto 0);				-- 16 bit data bus in from Sram (16 bit represents 2 pixels worth of data)
		Sram_AddressOut								: out Std_Logic_Vector(17 downto 0);			-- graphics controller address out 256k locations = 18 address lines
		Sram_DataOut									: out Std_Logic_Vector(15 downto 0);			-- graphics controller Data out to the Sram (represents 2 pixels)
		Sram_UDS_Out_L 								: out Std_Logic;										-- drive this low to read or write from upper half of the Sram data bus
		Sram_LDS_Out_L 								: out Std_Logic;										-- drive this low to read or write from lower half of the Sram data bus
		Sram_RW_Out										: out Std_Logic;										-- drive this low to write to Sram, 1 to read from Sram
		Sram_CE_L										: out Std_Logic; 										-- Drive this low to enable the Sram (for reading or writing)
		Sram_OE_L										: out Std_Logic;										-- Drive this low to turn on SRam outputs during a read operation

--		a 10 bit offset that's added to the Address issued by the VGA controller
-- 	This value from a register inside the graphics controller that can be written to by the 68k
-- 	It's purpose is to allow verical scrolling if you want to treat the graphics controller as a terminal (i.e. terminal emulation) for text

		ScrollValue 									: out Std_Logic_Vector(9 downto 0);  			-- scroll value for terminal emulation (allows screen scrolling up/down)
		GraphicsBusy_H									: out Std_logic;										-- this signal should be set to 1 whenever graphics controller
																														-- is accessing the Sram. This signal is connected to a big MUX
																														-- which switches over the SRam signals and connects them to the graphics controller
																														-- normally, the Sram signals are connected to the VGAController so that it can access
																														-- the SRam and display the image in the frame buffer
-- interface signals to a Character generator ROM

		CharGenData										: in Std_Logic_Vector(7 downto 0);				-- 8 bit data in from a character generator lookup ROM 
		CharGenAddr										: out Std_Logic_Vector(9 downto 0)  			-- 10 bit address to the rom 
																														-- used for drawing 5x7 pixel chars on screen.
	);
end;
 
architecture bhvr of GraphicsController is
--
-- These signals represent registers in VHDL - the 68K can write to these registers to store 16 values
-- depending upon the size of the registers
-- They are here to provide a means for the 68k to write coordinates to the graphcis controller
-- e.g. [X1,Y1] for a point, [X1,Y1],[X2,Y2] for a line, [X1,Y1],[X2,Y2], [X3,Y3] for a triangle etec
--
	Signal X1, Y1, 
			 X2, Y2, 
			 X3, Y3, 
			 Colour, 							-- holds the pallete number (i.e.) colour of the shape to be drawn e.g. a line in RED
			 BackGroundColour,				-- can be used if you want the 68k to be able to specify a background colour e.g. clear screen night erase pixels to background colour
			 Command, 							-- writing to this registers causes the Graphics Controller to do something e.g draw a line etc
													-- the value written determines the action
			 Mode									-- mode of graphics contrller - can be written to by the 68k,
													-- but you probably just want to accept the default value after a reset (affects when the
													-- the graphics controller can access Sram (any time or during HSync or interleaving)
			 : Std_Logic_Vector(15 downto 0);
			
-- the register that holds a scroll value for terminal emulation (can be written to by the 68k)
			
	Signal	ScrollValue_Data					: Std_Logic_Vector(9 downto 0);
			
			
	Signal	dx,dx_IN, dy, dy_IN, err, err_IN : signed(15 downto 0);
	Signal	err_Load_H, bresenham_Load_H, minus_dy_Load_H, plus_dx_Load_H, minus_plus_both_Load_H :	std_logic ;
	Signal	sx, sx_IN, sy,sy_IN : integer;
			 
	-- signals to control the registers above
	Signal 	X1_Select_H, 						-- high when 68k Writes to X1 Register address (used to enable writing to the register)
				X2_Select_H,						-- ditto for X2
				X3_Select_H,						-- ditto X3
				Y1_Select_H, 						-- ditto Y1
				Y2_Select_H, 						-- ditto Y2
				Y3_Select_H,						-- ditto Y3
				IncX1_H, 							-- you can drive this high as part of your state machine to cause X1 to increment
				IncY1_H, 							-- ditto Y1
				DecrX1_H, 							-- you can drive this high as part of your state machine to cause X1 to decrement
				DecrY1_H, 							-- ditto Y1
				Colour_Select_H,					-- high when 68k Writes to Colour Register address (used to enable writing to the register)
				BackGroundColour_Select_H,		-- ditto backgroundcolour
				Command_Select_H,					-- high when 68k Writes to Command Register address (used to enable writing to the register)
				Mode_Select_H						-- high when the 68k writes to the Mode register
				: Std_Logic; 	
				
-- register variables to save results of process calculations
	
	Signal 	Colour_Latch 						: Std_Logic_Vector(15 downto 0);		-- registers
	Signal 	CommandWritten_H, 
				ClearCommandWritten_H,	
				Idle_H, 
				SetBusy_H, 
				ClearBusy_H							: Std_Logic;					-- signals to control status of the graphics chip				
	
	-- signals that drive the SRam
	
	Signal 	Sig_AddressOut 																	: Std_Logic_Vector(17 downto 0);		-- 18 bit address bus
	Signal 	Sig_DataOut 																		: Std_Logic_Vector(15 downto 0); 	-- 16 bit data bus
	Signal 	Sig_UDS_Out_L, 					-- upper data strobe
				Sig_LDS_Out_L, 					-- lower data strobe
				Sig_RW_Out, 						-- read/write
				Sig_CE_L,							-- chip enable
				Sig_OE_L 																			: Std_Logic;
	
	
	signal	Sig_CE_Temp_L 								: Std_Logic;		-- a temporary/intermediate value for SRam Chip enable signal (CE_L)				
	Signal	Sig_Busy_H									: Std_Logic;

	-- signals to control the Colour Latch register -  When the 68k executes a read pixel command, this register holds the colour of the read pixel (8 bits)
	Signal	Colour_Latch_Data							: Std_Logic_Vector(15 downto 0);		-- 15 bit register, but same 8 bit data is read into both halves
	Signal	Colour_Latch_Load_H						: Std_Logic ;
	
	-- counter/timer
	Signal	EndCLK_H, StartClk_H					: Std_Logic;
	Signal   OkToDraw_L									: Std_Logic;
	
-------------------------------------------------------------------------------------------------------------------------------------------------
-- Signals for MOORE MODEL state machine
-------------------------------------------------------------------------------------------------------------------------------------------------
	Signal 	CurrentState, 
				NextState 								: Std_Logic_Vector(7 downto 0);
	
-------------------------------------------------------------------------------------------------------------------------------------------------
-- State value constants for state machine - these are just example
-- Feel Free to ADD MORE as your design evolves
-------------------------------------------------------------------------------------------------------------------------------------------------

	constant Idle						 				: Std_Logic_Vector(7 downto 0) := X"00";		-- main waiting state
	constant ProcessCommand			 				: Std_Logic_Vector(7 downto 0) := X"01";		-- State is figure out what command
	constant DrawPixel							 	: Std_Logic_Vector(7 downto 0) := X"02";		-- State for drawing a pixel
	constant ReadPixel							 	: Std_Logic_Vector(7 downto 0) := X"03";		-- State 1 or 2 for reading a pixel
	constant ReadPixel1							 	: Std_Logic_Vector(7 downto 0) := X"04";		-- State 2 of 2 for reading a pixel
	constant DrawHline			 	 				: Std_Logic_Vector(7 downto 0) := X"05";		-- State for drawing a Horizontal line
	constant DrawVline			 	 				: Std_Logic_Vector(7 downto 0) := X"06";		-- State for drawing a Vertical line
	constant DrawAnyline			 	 				: Std_Logic_Vector(7 downto 0) := X"07";		-- State 1 of 2 for drawing a Vertical line
	constant DrawAnyline2			 	 				: Std_Logic_Vector(7 downto 0) := X"08";		-- State 2 of 2 for drawing a Vertical line

	
-------------------------------------------------------------------------------------------------------------------------------------------------
-- Commands that can be written to command register by 68k to get graphics controller to draw a shape
-- You won't get all these working. At the moment only the PutPixel and GetPixel commands are imeplemented as an example
-- for you to understand what to do i.e. how to drive the Sram and when to do it etc
-------------------------------------------------------------------------------------------------------------------------------------------------
	constant Hline								 		: Std_Logic_Vector(15 downto 0) := X"0001";	-- command is draw Horizontal line
	constant Vline									 	: Std_Logic_Vector(15 downto 0) := X"0002";	-- command is draw Vertical line
	constant ALine									 	: Std_Logic_Vector(15 downto 0) := X"0003";	-- command is draw any line
	constant ACircle									: Std_Logic_Vector(15 downto 0) := X"0004";	-- command is draw a circle
	constant AFilledCircle							: Std_Logic_Vector(15 downto 0) := X"0005";	-- command is draw a filled circle
	constant AChar										: Std_Logic_Vector(15 downto 0) := X"0006";	-- command is draw a char
	constant ACharBackgroundFill					: Std_Logic_Vector(15 downto 0) := X"0007";	-- command is draw a char but fill non displayable pixels to background colour 
	constant AFilledTriangle						: Std_Logic_Vector(15 downto 0) := X"0008";	-- command for a filled triangle
	constant AFilledRectangle						: Std_Logic_Vector(15 downto 0) := X"0009";	-- command for a filled rectangle
	constant	PutPixel									: Std_Logic_Vector(15 downto 0) := X"000a";	-- command to draw a pixel
	constant	GetPixel									: Std_Logic_Vector(15 downto 0) := X"000b";	-- command to read a pixel
Begin

------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Secondary address decoder within the graphics controller
-- this is Simple combinatorial logic so we must supply default values to ensure no latches are generated to remember previous values
------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	process(AddressIn, GraphicsCS_L, RW, AS_L, UDS_L, LDS_L, Idle_H)
	begin
		X1_Select_H 					<= '0';			-- default value (overridden below)
		Y1_Select_H 					<= '0';
		X2_Select_H 					<= '0';
		Y2_Select_H 					<= '0';
		X3_Select_H 					<= '0';
		Y3_Select_H						<= '0';
		Colour_Select_H 				<= '0';
		BackGroundColour_Select_H  <= '0' ;
		Command_Select_H 				<= '0';
		Mode_Select_H 					<= '0';
		
		-- Base address of the graphics chip is set by the Primary Address decoder on the top level schematic
		-- Currently this is set at Hex [FF100000] (assuming you don't change it)
		--
		-- Command Register is currently at address hex [FF100000] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes)
		-- Graphics Status Register shares the same address as the command register but you have to read not write (see circuit later)
		-- X1 Register is currently at address hex [FF100002] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes)	
		-- Y1 Register is currently at address hex [FF100004] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes)	
		-- X2 Register is currently at address hex [FF100006] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes)	
		-- Y2 Register is currently at address hex [FF100008] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes)	
		-- X3 Register is currently at address hex [FF10000A] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes)	
		-- Y3 Register is currently at address hex [FF10000C] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes)	
		-- Colour Register is currently at address hex [FF10000E] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes - note the colour register only stores lower 8 bits but you still have to write it as a 16 bit value)	
		-- Background Colour Register is currently at address hex [FF100010] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes - note the background colour register only stores lower 8 bits but you still have to write it as a 16 bit value)	
		-- Mode Register is currently at address hex [FF100012] and is 16 bits wide (you have to write to it as a 16 bit value not 2 individual 8 bit writes)	
		
		-- to write to the command register do something like this in your program
		--
		-- move.w  d0,$FF10000
		--
		-- short int *CommandReg = (short int *)(0xFF100000) ;			// 16 bit pointer
		--	*CommandReg = 0x0001 ;												// write 1 to command reg as a 16 bit value
		--
		
		if(GraphicsCS_L = '0' and RW = '0' and AS_L = '0' and UDS_L = '0' and LDS_L = '0') then		
			if 	(AddressIn(7 downto 0) = X"00")	then		Command_Select_H <= '1';
			elsif	(AddressIn(7 downto 0) = X"02") 	then		X1_Select_H <= '1';
			elsif	(AddressIn(7 downto 0) = X"04")	then		Y1_Select_H <= '1';
			elsif	(AddressIn(7 downto 0) = X"06")	then		X2_Select_H <= '1';
			elsif	(AddressIn(7 downto 0) = X"08")	then		Y2_Select_H <= '1';
			elsif	(AddressIn(7 downto 0) = X"0A")	then		X3_Select_H <= '1';
			elsif	(AddressIn(7 downto 0) = X"0C")	then		Y3_Select_H <= '1';
			elsif	(AddressIn(7 downto 0) = X"0E")	then		Colour_Select_H <= '1';
			elsif (AddressIn(7 downto 0) = X"10") 	then		BackGroundColour_Select_H <= '1';
			elsif (AddressIn(7 downto 0) = X"12") 	then		Mode_Select_H <= '1';
			end if;
		end if;
	end process;

------------------------------------------------------------------------------------------------------------------------------
-- 16 bit Status Register: Process activated when CPU reads status reg of graphics chip at base address hex FF100000
-- The register must be "Polled" by the 68k to determin when it is safe to begin writing a new command to the graphcis controller
-- In essence, then the graphics controller is busy, te 68k must wait and not write to any of its register
-- When it is idle, it can begin progrmming the graphics controller with a new command (e.g. write to x1, y1, command registers etc)
-- Register must be read as a 16 bit value even though only bit is relevant
--
-- e.g. move.w  $FF10000,d0     in 68k assembly, or use a "short int pointer" in C i.e. a pointer t 16 bits
--
-- when bit 0 = 1, device is idle and ready to receive command
-- when bit 1 = 1, device is indicating that an HSync signal is active low to the VGA display
-- this means 68k can access video frame buffer memory DIRECTLY without flicker
------------------------------------------------------------------------------------------------------------------------------
	process(GraphicsCS_L, AddressIn, RW, AS_L, UDS_L, LDS_L, Idle_H, HSync_L, Colour_Latch)
	Begin
		DataOut68k <= "ZZZZZZZZZZZZZZZZ";												-- default is tri state data-out bus to 68k
		
		if(GraphicsCS_L = '0' and RW = '1' and AS_L = '0' and UDS_L = '0' and LDS_L = '0') then 
			if(AddressIn(7 downto 0) = X"00") then										-- read of status register
				DataOut68k <= B"00000000000000" & (not HSync_L) & Idle_H;		-- leading 14bits of 0 plus HSync Status plus idle status on bit 0
			elsif(AddressIn(7 downto 0) = X"0e") then									-- read of colour register
				DataOut68k <= Colour_Latch ;
			end if ;
		end if;
	end process;
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Process to store scroll value when written to by the 68k CPU
-- You can ignore this unless you want to scroll or maybe you want to get the 68k to write hex 0000 to this address to reset the register
-- as part of your code, either way, if left unitiailised, it will still work and the top left of your screen will always be coords [0,0]
--
-- Scroll Register is currently at address hex [FF100020] and is 16 bits wide 
-- (you have to write to it as a 16 bit value not 2 individual 8 bit writes)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(GraphicsCS_L = '0' and AddressIn(7 downto 0) = X"20" and RW = '0' and AS_L = '0' and UDS_L = '0' and LDS_L = '0') then
				ScrollValue_Data <= DataIn68k(9 downto 0);			-- save scroll value
			end if;
		end if;
	end process;
	
--------------------------------------------------------------------------------------------------------------------------------
-- CommandWritten Process - When the 68k writes to the Graphics Command register
-- this process will detect the write and set the CommandWritten_H signal to logic 1 to record the fact
-- that the graphics controller now has a new command to process.
-- CommandWritten_H will stay 1 until cleared with a ClearCommandWritten
--
-- The state machine in the graphics controller responsible for processing command from the 68k
-- will sit in an idle state until CommandWritten_H = '1' then it will
-- process the command and clear the signal by asserting ClearCommandWritten_H and then return to the idle state
--
-- This process effectively generates the "GO" signal to the state machine to tell it to go draw something
-- what needs to be drawn will be defined by the 68k value written to the command registers e.g. pixel, line, rectangle etc.
------------------------------------------------------------------------------------------------------------------------------
	process(Clk, Reset_L)
	Begin
		if(Reset_L = '0') then								-- clear command register and relevant signals on reset (asynchronous to clock)
			CommandWritten_H <= '0';
		elsif(rising_edge(Clk)) then						-- on next clock rising edge
			if(Command_Select_H = '1') then				-- if process detects that 68k is writing to then command register
				CommandWritten_H <= '1';					-- set a flag/signal to record fact that a command has been written
			elsif(ClearCommandWritten_H = '1') then	-- signal to clear the flag/signal when the command has been processed by the graphics controller
				CommandWritten_H <= '0';
			end if;
		end if;
	end process;

------------------------------------------------------------------------------------------------------------------------------
-- This process stores in a register the "mode" of operation of the graphics controller
-- It is reset to 1 by a hardware reset and that is the default mode which allows for the best compromise between
-- writing speed and interferance on the users screen
-- 
-- In effect the mode defines when the graphics controller is allowed to write/read to the Sram chip
-- To minimise flicker and unwanted/undesireable interferance on the screen, the Graphics controller
-- should not try to read/write to sram at the same time as the VGA controller is accessing Sram to fetch the next pixel to display.
-- If this should happen, the graphics controller will get priority and the VGA controller will lose access to the Sram
-- (There is a big mux in the schematic to switch between Graphics controller and VGA controller haveing access to the Sram)
-- Bottom line is, use this default mode - there is no real reason to change it
-- (However - see process below)
------------------------------------------------------------------------------------------------------------------------------
	process(Clk, Reset_L)
	Begin
		if(Reset_L ='0') then							-- default mode on reset
			Mode <= X"0001";
		elsif(rising_edge(Clk)) then
			if(Mode_Select_H = '1') then				-- when 68k issues a 16 bit write to the address of the mode register
				Mode <= DataIn68k(15 downto 0);		-- store the 16 bit data written by 68k to the Mode register (only bottom 2 bits are actually stored)
			end if;
		end if;
	end process;

------------------------------------------------------------------------------------------------------------------------------
-- This process is responsible for producing the OKtoDraw_L signal to the Graphics Controller which gives an instant
-- indication if it is safe to draw without producing flicker/interferance on the users screen
-- The process uses the programmed mode of the graphics controller, which can be written to the graphics controller 
-- "Mode" register by the 68k - see process above to determing when to it is OK to draw
-- 
--	10 - Graphics controller is allowed to access SRam whenever it want - this leads to flickering, but allows maximum drawing speed, 
-- 01 - Graphics Controller is allowed to access Sram only when VGA controller is issueing a HSync(good but 4 times slower), 
-- 00 - Graphics controller is allowed draw during an HSYnc and to interleave with vga controller - this is default on reset
------------------------------------------------------------------------------------------------------------------------------
	process(Mode, InterleaveDraw_L, HSync_L)
	begin
		if(Mode(1 downto 0) = X"00") then			-- if l.s. 2 bits of Mode register = 00
			OkToDraw_L <= InterleaveDraw_L;
		elsif(Mode(1 downto 0) = X"01") then		-- else if l.s. 2 bit of mode register = 01
			OkToDraw_L <= HSync_L;
		else
			OkToDraw_L <= '0' ;							-- for all others set OK to draw to permanently enabled (max speed/most interference)
		end if;
	end process;
	
------------------------------------------------------------------------------------------------------------------------------
-- This process generates the status of the Graphics Processor
-- This process can be determined by the 68k by polling the Status Register at address FF100000
-- 
-- The value of that status register is determined here by this process i.e. this process
-- is responsible for generating the status of the Graphics Chip as read by the 68k
------------------------------------------------------------------------------------------------------------------------------
	process(Clk, Reset_L)
	Begin
		if(Reset_L = '0') then								-- clear all registers and relevant signals on reset (asynchronous to clock)
			Idle_H <= '1';										-- make sure CPU can read graphics is idle
		elsif(rising_edge(Clk)) then						-- when graphics starts to process a command, mark it's status as BUST (not idle)
			if(SetBusy_H = '1') then								
				Idle_H <= '0';
			elsif(ClearBusy_H = '1') then					-- when graphics processor has finished processing command, marks status is IDLE
				Idle_H <= '1';
			end if;
		end if;
	end process;	

------------------------------------------------------------------------------------------------------------------------------
-- 2*err Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(err_Load_H = '1') then
				err <= err_IN;
			elsif(minus_plus_both_Load_H = '1') then
				err <= err - dy + dx ;
			elsif(minus_dy_Load_H = '1') then
				err <= err - dy  ;
			elsif(plus_dx_Load_H = '1') then
				err <= err + dx ;
			end if;
		end if;
	end process;
	
------------------------------------------------------------------------------------------------------------------------------
-- load other bresenham stuff Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(bresenham_Load_H = '1') then
				dx <= dx_IN ;
				dy <= dy_IN ;
				sx <= sx_IN ;
				sy <= sy_IN ;
			end if;
		end if;
	end process;	
	
	

------------------------------------------------------------------------------------------------------------------------------
-- X1 Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(X1_Select_H = '1') then						-- when 68k issues a 16 bit write to the address of the X1 register
				X1 <= DataIn68k(15 downto 0);				-- store the 16 bit data written by 68k to the X1 register	
			elsif(IncX1_H = '1') then						-- Can use this signal to increment x1 e.g. when drawing a horizonta line
				X1 <= std_Logic_Vector(signed(X1) + 1);
			elsif(DecrX1_H = '1') then						-- Can use this signal to increment x1 e.g. when drawing a horizonta line
				X1 <= std_Logic_Vector(signed(X1) - 1);
			end if;
		end if;
	end process;
	
------------------------------------------------------------------------------------------------------------------------------
-- Y1 Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(Y1_Select_H = '1') then						-- when 68k issues a 16 bit write to the address of the Y1 register			
				Y1 <= DataIn68k(15 downto 0);				-- store the 16 bit data written by 68k to the Y1 register
			elsif(IncY1_H = '1') then						-- Can use this signal to increment y1 e.g. when drawing a vertical line
				Y1 <= std_Logic_Vector(signed(Y1) + 1);
			elsif(DecrY1_H = '1') then						-- Can use this signal to increment y1 e.g. when drawing a vertical line
				Y1 <= std_Logic_Vector(signed(Y1) - 1);
			end if;
		end if;
	end process;

------------------------------------------------------------------------------------------------------------------------------
-- X2 Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(X2_Select_H = '1') then						-- when 68k issues a 16 bit write to the address of the X2 register		
				X2 <= DataIn68k(15 downto 0);				-- store the 16 bit data written by 68k to the X2 register	
			end if;
		end if;
	end process;		
	
------------------------------------------------------------------------------------------------------------------------------
-- Y2 Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(Y2_Select_H = '1') then								-- when 68k issues a 16 bit write to the address of the Y2 register
				Y2 <= DataIn68k(15 downto 0);						-- store the 16 bit data written by 68k to the Y2 register
			end if;
		end if;
	end process;	
	
------------------------------------------------------------------------------------------------------------------------------
-- X3 Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(X3_Select_H = '1') then								-- when 68k issues a 16 bit write to the address of the X3 register
				X3 <= DataIn68k(15 downto 0);						-- store the 16 bit data written by 68k to the X3 register
			end if;
		end if;
	end process;		
	
------------------------------------------------------------------------------------------------------------------------------
-- Y3 Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then									-- when 68k issues a 16 bit write to the address of the Y3 register
			if(Y3_Select_H = '1') then								-- store the 16 bit data written by 68k to the Y3 register				
				Y3 <= DataIn68k(15 downto 0);
			end if;
		end if;
	end process;		

------------------------------------------------------------------------------------------------------------------------------
-- Colour Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(Colour_Select_H = '1') then						-- when 68k issues a 16 bit write to the address of the Colour register
				Colour <= DataIn68k(15 downto 0);				-- store the 16 bit data written by 68k to the Colour register (lowest 8 bits)
			end if;
		end if;
	end process;	

------------------------------------------------------------------------------------------------------------------------------
-- Background Colour Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(BackGroundColour_Select_H = '1') then				-- when 68k issues a 16 bit write to the address of the Background colour register
				BackGroundColour <= DataIn68k(15 downto 0);		-- store the 16 bit data written by 68k to the background colour register	(lowest 8 bits)						
			end if;
		end if;
	end process;		
		
------------------------------------------------------------------------------------------------------------------------------
-- Command Process
------------------------------------------------------------------------------------------------------------------------------
	process(Clk, Reset_L)
	Begin
		if(Reset_L = '0') then											-- clear command register on reset (asynchronous to clock)
			Command <= X"0000";
		elsif(rising_edge(Clk)) then
			if(Command_Select_H = '1') then							-- when 68k issues a 16 bit write to the address of the X1 register		
				Command <= DataIn68k(15 downto 0);
			end if;
		end if; 
	end process;	

------------------------------------------------------------------------------------------------------------------------------
-- Colour Latch Process (used for reading pixel)
------------------------------------------------------------------------------------------------------------------------------
	process(Clk)
	Begin
		if(rising_edge(Clk)) then
			if(Colour_Latch_Load_H = '1') then						-- signal from state machine to tell latch to store data from SRam during a read pixel operation
				Colour_Latch <= Colour_Latch_Data;
			end if ;
		end if;
	end process;		
	
-----------------------------------------------------------------------------------------------------------------------------
-- concurrent process : counter to simulate time delay 	
-- This process is not used at the moment so is free for you to use or ignore
-- I used it originally when drawing Triangle where the gradient of the lines had to be determined
-- using a divide operation in hardware which took many clock cycles of propagation delay so I used
-- the timer below as part of the state machine. I started the timer when I started the divided
-- and waited long enough to ensure results of division were valid
-----------------------------------------------------------------------------------------------------------------------------

   Process(Clk, StartClk_H)
		variable timeClk : integer range 0 to 100;
	BEGIN
		if(StartClk_H = '1') then
			timeClk  := 15;				-- 15 clock delays
		elsif (rising_edge(Clk) and (timeClk /= 0)) then
			timeClk := timeClk - 1;
		end if;
			
		if(timeClk = 0) then
			EndCLK_H <= '1';				-- if time elapsed, signal it
		else
			EndCLK_H <= '0';
		end if;
	END Process;		
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Moore Model State Machine Registers
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	Process(Clk, Reset_L, Sig_CE_Temp_L)
	Begin
		if(Reset_L = '0') then
			CurrentState <= Idle; 
		elsif(Rising_edge(Clk)) then
			CurrentState <= NextState;

-- Make outputs to the Sram synchronous
-- IMPORTANT: The signals to the SRam are delayed by 1 clock cycle due to the fact that they propagate through this register
			
			Sram_AddressOut 		<= Sig_AddressOut; 
			Sram_DataOut 			<= Sig_DataOut;
			Sram_UDS_Out_L 		<= Sig_UDS_Out_L;
			Sram_LDS_Out_L 		<= Sig_LDS_Out_L;
			Sram_RW_Out				<= Sig_RW_Out;
			Sram_OE_L				<= Sig_OE_L;
			GraphicsBusy_H			<= Sig_Busy_H AND (NOT OKToDraw_L);		-- turn off Busy during display periods as we will not be drawing, let VGA controller have the Sram during display periods and Graphics during blanking periods
			ScrollValue 			<= ScrollValue_Data;
			Sig_CE_Temp_L			<= Sig_CE_L;	
		end if; 
		
		Sram_CE_L <= Sig_CE_Temp_L OR (NOT Clk);								-- make sure CE_L returns high in between clocks to avoid address overlap on successive read/writes to sram 
	end process;
	

---------------------------------------------------------------------------------------------------------------------
-- next state and output logic
----------------------------------------------------------------------------------------------------------------------	
	
		-- dx, dy, sy, sx, err

	process(CLK, CurrentState, Colour, CommandWritten_H, AS_L, Command, OKtoDraw_L, X1, Y1, X2, Y2, SRam_DataIn, dx, dy, sx, sy, err)
	
	begin
	
	-- 
	-- start with default values for everything and override as necessary, so we do not infer storage for signals inside this process
	--
		Sig_AddressOut 					<= B"00_0000_0000_0000_0000";								-- default SRam address out is 0
		Sig_DataOut 						<= Colour(7 downto 0) & Colour(7 downto 0);			-- default SRam Data out is to present the lowest 8 bits of the colour register to both halves of the SRam data bus
		Sig_UDS_Out_L 						<= '1';															-- default SRam UDS_L signal is INACTIVE
		Sig_LDS_Out_L 						<= '1';															-- default SRam LDS_L signal is INACTIVE
		Sig_RW_Out 							<= '1';															-- default SRam RW signal is READ (don't want false writes)
		Sig_CE_L								<= '0';															-- default SRam CE_L signal is ACTIVE (Needs UDS_L and/or LDS_L to fully activate it)
		Sig_OE_L								<= '0';															-- default SRam OE_L signal is ACTIVE (won't hurt even if writing, since the SRAM only looks at OE during a read)
		
		IncX1_H								<= '0';															-- default is DON'T increment X1 with each clock
		IncY1_H								<= '0';															-- default is DON'T increment Y1 with each clock
		DecrX1_H								<= '0';															-- default is DON'T decrement X1 with each clock
		DecrY1_H								<= '0';															-- default is DON'T decrement Y1 with each clock
		err_Load_H							<= '0';															-- default is don't update err
		bresenham_Load_H					<= '0';															-- default is don't update bresenham variables
		minus_dy_Load_H					<= '0';	
		plus_dx_Load_H						<= '0';
		minus_plus_both_Load_H			<= '0' ;
		dx_IN									<= "0000000000000000";
		dy_IN									<= "0000000000000000";
		err_IN								<= "0000000000000000";
		sx_IN									<= 0;
		sy_IN									<= 0;
		ClearBusy_H 						<= '0';
		SetBusy_H							<= '0';
		ClearCommandWritten_H			<= '0';
		Sig_Busy_H							<= '1';															-- default status is Graphics controller is busy
		
		CharGenAddr							<= B"0000000000";									
		Colour_Latch_Load_H				<= '0';															-- default is DON'T load colour latch (used whn reading a pixel)
		Colour_Latch_Data					<= X"0000";														-- default data for the colour latch is "0000"
			
		-- timer counter
		StartClk_H							<= '0';															-- default is don't state the timer cloks
		
		-- default next state is IDLE unless overridden
		NextState							<= Idle;
				
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------				
		if(CurrentState = Idle ) then
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
			ClearBusy_H <= '1';							-- mark status as of graphics controller as idle
			Sig_Busy_H <= '0';							-- show outside world (i.e. 68k polling the status register) that it is NOT busy
			
			if(CommandWritten_H = '1') then			-- if state machine detects that the 68k is writting to the command registers
				if(AS_L = '0') then						-- wait for CPU to finish writing the command
					NextState <= IDLE;					-- stay in this state until 68k write operation has finished i.e. AS_L returns high
				else
					NextState <= ProcessCommand;		-- now go process the command in the next state
				end if;
			end if;
			
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
		elsif(CurrentState = ProcessCommand) then		-- enter this state after the 68k has written a command to the command register
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
			SetBusy_H <= '1';								-- set the status of the graphics chip to BUSY so when 68k polls status register it knows to wait
			ClearCommandWritten_H <= '1';				-- clear the 68k command now that we are processing it
			
			if(Command = PutPixel) then				-- if the command was PutPixel
				NextState <= DrawPixel;					-- go to a new state to draw a pixel (coords should be in X1, Y1 and colour in colour reg) if the 68k has written to them before the command register
			elsif(Command = GetPixel) then			-- if the command was GetPixel
				NextState <= ReadPixel;					-- go to a new state to read the colour value of a pixel (i.e a pallette number) (Coords should be X1, Y1 if the 68k has written to them before command register)
			elsif(Command = Hline ) then
				NextState <= DrawHline ;
			elsif(Command = Vline ) then
				NextState <= DrawVline ;
			elsif(Command = ALine ) then
				NextState <= DrawAnyline ;		
			end if;							
				
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = DrawPixel) then			-- enter this state when 68k instructs graphics controller to draw a pixel at [X1,Y1] in chosen colour
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
			if(OKToDraw_L = '0') then														-- if VGA is not displaying at this time, then we can draw, otherwise wait for video blanking during Hsync
				Sig_RW_Out			<= '0';				
				Sig_AddressOut 	<= Y1(8 downto 0) & X1(9 downto 1);				-- issue 9 bit 'X' address to SRAM even though it goes up to 1024 pixels accross which would mean 10 bits, because each address = 2 pixels/bytes
																									-- also issue a 9 bit Y address for a row (480 rows means at least 9 bits)
																									-- the resulting address is an 18 bit address to the Sram
				
				if(X1(0) = '0')	then														-- if the address/pixel is an even numbered one
					Sig_UDS_Out_L 	<= '0';													-- enable write to upper half of Sram data bus
				else
					Sig_LDS_Out_L 	<= '0';													-- else write to lower half of Sram data bus
				end if;
				
				-- Note that during the above write, the CE_L, OE_L signals assume their default state of active
				-- and that the value of the colour register is presented to both halves of the SRam data bus during the write
				-- regardless of which half we write to
				
				NextState <= IDLE;															-- once written to the Sram, return to the IDLE state to await next command from 68k
			else																					-- stay in this state if VGA controller is accessing the SRam (we con't want flickering/interference on display)
				NextState <= DrawPixel;
			end if ;
			
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = ReadPixel) then											-- enter this state when 68k instructs graphics controller to read a pixel at [X1,Y1] colour will be read and stored in colour Latch which can be read by 68k
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
			if(OKToDraw_L = '0') then														-- if VGA is not displaying at this time, then we can draw, otehrwise wait for video blanking during Hsync
				Sig_AddressOut 	<= Y1(8 downto 0) & X1(9 downto 1);				-- issue 9 bit 'X' address to SRAM even though it goes up to 1024 pixels accross which would mean 10 bits, because each address = 2 pixels/bytes
																									-- also issue a 9 bit Y address for a row (480 rows means at least 9 bits)
																									-- the resulting address is an 18 bit address to the Sram
				Sig_RW_Out			<= '1';													-- set Read/Write to Read (the default by emphasied here)
			
				Sig_UDS_Out_L 	<= '0';														-- enable read from upper half of Sram data bus
				Sig_LDS_Out_L 	<= '0';														-- enable read from lower half of the sram

				NextState <= ReadPixel1;													-- now that we hav activated the SRam, go and read it and latche data in the next state
			else
				NextState <= ReadPixel;														-- otherwise stay here and wait until VGA controller has finished accessing the Sram so Graphics Controller can have access
			end if ;	
			
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = ReadPixel1) then											-- state to actually latch the data from the Sram when reading a pixel
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	In the state above (ReadPixel) we generated the signals for the SRam, but because those signals pass through an additional register
-- i.e. they are registered outputs to make them all synchronous, they do not appear at the pins of the SRam until we get to this state
-- so that is why we activate and latch the data we read from the Sram in THIS state and NOT the one above
-- This is only an issue when we are reading from the Sram and storing the data, NOT when we are writing.

			if(OKToDraw_L = '0') then
				Colour_Latch_Load_H 		<= '1';	
		
				if(X1(0) = '0')	then															-- if the address/pixel is an even numbered one
					Colour_Latch_Data(7 downto 0) <= SRam_DataIn(15 downto 8);
				else
					Colour_Latch_Data(7 downto 0) <= SRam_DataIn(7 downto 0);
				end if;	
		
				NextState <= IDLE ;
			else																						-- if we lose control of sram due to mux switching back to vga controller at end of Hsync period, then go start the whole read pixel thing again
				NextState <= ReadPixel ;
			end if ;
			
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = DrawHline) then
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TODO as part of your assignment

			if(OKToDraw_L = '0') then														-- if VGA is not displaying at this time, then we can draw, otherwise wait for video blanking during Hsync
				Sig_RW_Out			<= '0';				
				Sig_AddressOut 	<= Y1(8 downto 0) & X1(9 downto 1);				-- issue 9 bit 'X' address to SRAM even though it goes up to 1024 pixels accross which would mean 10 bits, because each address = 2 pixels/bytes
																									-- also issue a 9 bit Y address for a row (480 rows means at least 9 bits)
																									-- the resulting address is an 18 bit address to the Sram
				
				if(X1(0) = '0')	then														-- if the address/pixel is an even numbered one
					Sig_UDS_Out_L 	<= '0';													-- enable write to upper half of Sram data bus
				else
					Sig_LDS_Out_L 	<= '0';													-- else write to lower half of Sram data bus
				end if;
				
				-- Note that during the above write, the CE_L, OE_L signals assume their default state of active
				-- and that the value of the colour register is presented to both halves of the SRam data bus during the write
				-- regardless of which half we write to
				
				
				if ( X1 < X2 ) then
					IncX1_H <= '1' ;
					NextState <= DrawHline;					-- keep drawing h line until x1 = x2
				elsif ( X1 > X2 ) then
					DecrX1_H <= '1' ;
					NextState <= DrawHline;					-- keep drawing h line until x1 = x2
				else
					NextState <= IDLE;															-- once written to the Sram, return to the IDLE state to await next command from 68k
				end if ;
				
			else																					-- stay in this state if VGA controller is accessing the SRam (we con't want flickering/interference on display)
				NextState <= DrawHline;
			end if ;



---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = DrawVline) then
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		

-- TODO as part of your assignment

			if(OKToDraw_L = '0') then														-- if VGA is not displaying at this time, then we can draw, otherwise wait for video blanking during Hsync
				Sig_RW_Out			<= '0';				
				Sig_AddressOut 	<= Y1(8 downto 0) & X1(9 downto 1);				-- issue 9 bit 'X' address to SRAM even though it goes up to 1024 pixels accross which would mean 10 bits, because each address = 2 pixels/bytes
																									-- also issue a 9 bit Y address for a row (480 rows means at least 9 bits)
																									-- the resulting address is an 18 bit address to the Sram
				
				if(X1(0) = '0')	then														-- if the address/pixel is an even numbered one
					Sig_UDS_Out_L 	<= '0';													-- enable write to upper half of Sram data bus
				else
					Sig_LDS_Out_L 	<= '0';													-- else write to lower half of Sram data bus
				end if;
				
				-- Note that during the above write, the CE_L, OE_L signals assume their default state of active
				-- and that the value of the colour register is presented to both halves of the SRam data bus during the write
				-- regardless of which half we write to
				
				if ( Y1 < Y2 ) then
					IncY1_H <= '1' ;
					NextState <= DrawVline;					-- keep drawing h line until y1 = y2
				elsif ( Y1 > Y2 ) then
					DecrY1_H <= '1' ;
					NextState <= DrawVline;			
				else
					NextState <= IDLE;															-- once written to the Sram, return to the IDLE state to await next command from 68k
				end if ;
				
			else																					-- stay in this state if VGA controller is accessing the SRam (we con't want flickering/interference on display)
				NextState <= DrawVline;
			end if ;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = DrawAnyline ) then -- set up the values needed for the draw any line using bresanham algorithm
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
		
	-- dx, dy, sx, sy, err, err
			
			-- initiate dx and sx
			if ( X1 < X2 ) then
				dx_IN <= signed(X2) - signed(X1) ;
				sx_IN <= 1; -- sx is positive
			else
				dx_IN <= signed(X1) - signed(X2) ;
				sx_IN <= -1; -- sx is negative
			end if;

			-- initiate dy and sy
			if ( Y1 < Y2 ) then
				dy_IN <= signed(Y2) - signed(Y1) ;
				sy_IN <= 1; -- sy is positive
			else
				dy_IN <= signed(Y1) - signed(Y2) ;
				sy_IN <= -1; -- sy is negative
			end if;
			
			bresenham_Load_H <= '1' ;
	
			-- initiate err and err, since we wanted to initiate these in as few states as possible, 
			-- we decided to ready all signals at this state
			if ( X1 < X2 and Y1 < Y2) then
				err_IN <= (signed(X2) - signed(X1)) -(signed(Y2) - signed(Y1));
			elsif( X1 < X2  and Y1 >= Y2) then
				err_IN <= (signed(X2) - signed(X1)) - (signed(Y1) - signed(Y2));
			elsif(X1 >= X2 and Y1 < Y2) then
				err_IN <= (signed(X1) - signed(X2)) - (signed(Y2) - signed(Y1));
			else
				err_IN <= (signed(X1) - signed(X2)) - (signed(Y1) - signed(Y2));
			end if ;
			
			err_Load_H <= '1' ;

			NextState <= DrawAnyline2 ;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		elsif(CurrentState = DrawAnyline2 ) then -- the actual draw any line using bresenham algorithm
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
			if(OKToDraw_L = '0') then														-- if VGA is not displaying at this time, then we can draw, otherwise wait for video blanking during Hsync
				Sig_RW_Out			<= '0';				
				Sig_AddressOut 	<= Y1(8 downto 0) & X1(9 downto 1);
				
				if(X1(0) = '0')	then														-- if the address/pixel is an even numbered one
					Sig_UDS_Out_L 	<= '0';													-- enable write to upper half of Sram data bus
				else
					Sig_LDS_Out_L 	<= '0';													-- else write to lower half of Sram data bus
				end if;

				if ( err + err > -dy  ) then
					if (sx = 1 ) then -- sx is positive
						IncX1_H <= '1' ;
					else
						DecrX1_H <= '1' ;
					end if ;
				end if;				
				
				if ( err + err < dx ) then
					if (sy = 1 ) then -- sx is positive
						IncY1_H <= '1' ;
					else
						DecrY1_H <= '1' ;
					end if ;
				end if;
				
				if ( err + err > -dy and err+ err < dx) then
					minus_plus_both_Load_H <= '1';
				elsif( err+ err > -dy and err+ err >= dx) then
					minus_dy_Load_H <= '1';				
				elsif( err + err <= -dy and err+ err < dx) then
					plus_dx_Load_H <= '1';
				end if;

				if ( X1 /= X2 or Y1 /= Y2 ) then
					NextState <= DrawAnyline2;			
				else
					NextState <= IDLE;															-- once written to the Sram, return to the IDLE state to await next command from 68k
				end if ;
				
			else																					-- stay in this state if VGA controller is accessing the SRam (we con't want flickering/interference on display)
				NextState <= DrawAnyline2;
			end if ;	
			
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		end if;								-- end of current state
	end process;	
end;
