// #include "DebugMonitor.h"

// void Init_I2C_Controller(void) {
   // // Prescale register lower-byte.  Using 25 MHz clk to generate a 100 kHz SCL, so use 0x31
   // I2C_PRER_LO = 0x31 ;

   // // Prescale register higher-byte.  Not using it, so input 0
   // I2C_PRER_HI = 0x0 ;

   // // Control register.  Bit 7 = '1' to enable I2C core and Bit 6 = '0' to disable interrupts.
   // // Bits 5 downto 0 are reserved
   // I2C_CTR = 0x80 ;
// }

// int RW_Eeprom_Bytes( unsigned int AdressStart, unsigned int size, unsigned char data, unsigned int RW_Bit ) {
	// // clear interrupts and previous slave transmits
	
	// unsigned int i, wait_counter ;
	// unsigned char dataByte;

	// if ( ( AdressStart + size - 1 ) > 0x1FFFF ||  (size < 1 || size > 131072 ) ) {
		// return 1;
	// }
	
	// while ( I2C_SR & 0x02 ) {}
	
	// I2C_CR = 0x09 ;
	
   // I2C_TXR = ( AdressStart < 0x10000 ) ? 0xA0 : 0xA8;      // address to slave and read, must start with a write
   // I2C_CR = 0x91 ;	// start condition
   // while ( I2C_SR & 0x82 ) {}
   
   // I2C_TXR = 0xFF & (AdressStart >> 8 );
   // I2C_CR = 0x11 ;
   // while ( I2C_SR & 0x82 ) {}

   
   // I2C_TXR = 0xFF & AdressStart ;
   // I2C_CR = 0x11 ;
   // while ( I2C_SR & 0x82 ) {}
   
   // if ( RW_Bit == 1 ) { // read mode
		// I2C_TXR = ( AdressStart < 0x10000 ) ? 0xA1 : 0xA9;      // then set read bit
		// I2C_CR = 0x91 ;	// start condition
		// while ( I2C_SR & 0x82 ) {}	
		
		// for ( i = 0; i < size ; i++ ) {
			// if ( (AdressStart < 0x10000) && (AdressStart + i >= 0x10000) ) {
				// I2C_CR = 0x69 ;
				// RW_Eeprom_Bytes(0x10000, size - i, 0, 1);
				// break;
			// }
		
			// I2C_CR = 0x21 ;
			// while ( I2C_SR & 0x02 ) {}
			// dataByte = I2C_RXR;
			// printf( "%X  ", dataByte );
		// }
		
		// // if end address is 0x10000 or greater, then block 2, else block 1
		// I2C_CR = 0x69 ;
	// // printf("\nEnd pointer = %X\n", AdressStart + i -1);
   // } else if ( RW_Bit == 0 ) { // write mode
	
		// for ( i = 0 ; i < size; i++ ) {	
			// if (((( ( AdressStart + i)  & 0xFF )== 0x0)  || (  (( AdressStart + i)  & 0xFF) == 0x80)) && (AdressStart + i != AdressStart) ) {
				// I2C_CR = 0x41 ;	// stop condition
				// for ( wait_counter = 0 ; wait_counter < 100000; wait_counter++ ) {}
				// RW_Eeprom_Bytes(AdressStart + i, size - i, data, 0);
				// return 0;
			// }
			
			// I2C_TXR = data ;
			// I2C_CR = 0x11 ;
			// while ( I2C_SR & 0x82 ) {}	
		// }
		
		// I2C_CR = 0x41 ;	// stop condition
		// for ( wait_counter = 0 ; wait_counter < 100000; wait_counter++ ) {}
   // }
	
	
	// return 0;
// }



// // Read adc 0
// void Get_ADC0_Voltage(void) {
	
   // unsigned char adc_voltage_step;

	// while ( I2C_SR & 0x02 ) {}
   
	// // clear interrupts and previous slave transmits
   // I2C_CR = 0x09 ;

	// // write the address of our adc chip first bits 7 downto to 1 has the address of the chip and bit 0 is R/W where '1' is a read
   // I2C_TXR = 0x93 ;    

   // // command register tells the chip to do the read, set STA(bit 5) and IACK (bit 0) to 1 during a write
   // I2C_CR = 0x91 ;
   
	// // // write the address of our adc chip first bits 7 downto to 1 has the address of the chip and bit 0 is R/W where '1' is a read
   // // I2C_TXR = 0x93 ; 
  
   // // // wait for slave ack and tip
	// while ( I2C_SR & 0x82 ) {}
	
	// // clear previous value from slave data register
	// I2C_CR = 0x21 ;
	// while ( I2C_SR & 0x02 ) {}

	// while( getchar() != 0x1B ) {
			// I2C_CR = 0x21 ;
		// // Check if i2c got the read, wait uuntil interrupt bit goes high
			// while ( I2C_SR & 0x02 ) {}
			// adc_voltage_step = I2C_RXR  ;
			// printf("ADC0 Voltage Step: %d\n", adc_voltage_step);
	// }
	
	// I2C_CR = 0x49 ;
	// // I2C_CR = 0x69 ;
// }



// // Output an analog voltage
// void Output_DAC_Voltage( void ) {
	
	// int num_array[3];
	// unsigned char input_volts;
	
	// printf( "\nEnter voltage step (out of 256 steps) or 'ESC' to cancel:\n" );

   // // Check if i2c is still transmitting data
   // while ( I2C_SR & 0x02 ) {}
   
   // // // Start condition
   // // I2C_CR = 0x91 ;
   
   // // write the address of our adc chip first bits 7 downto to 1 has the address of the chip and bit 0 is R/W where '0' is a write
   // I2C_TXR = 0x92 ;
   
   // // Start condition
   // I2C_CR = 0x91 ;
   
	// // wait for transimit done
	// // wait for ack from slave, when bit 7 of SR is zero, then acknowledged
	// while ( I2C_SR & 0x82 ) {}

   // // second byte enable analog output on bit 6
	// I2C_TXR = 0x40 ;
      
	// // wait for transimit done
	// // wait for ack from slave, when bit 7 of SR is zero, then acknowledged
	// while ( I2C_SR & 0x82 ) {}
	
	// // command register tells the chip to continue the write, set  WR (bit 4) and IACK (bit 0) to 1 during a write
	// I2C_CR = 0x11 ;
	
	// // wait for transimit done
	// // wait for ack from slave, when bit 7 of SR is zero, then acknowledged
	// while ( I2C_SR & 0x82 ) {}

   
   // while ( (num_array[2] = getchar()) != 0x1b  ) {  
		// // 2nd number
		// num_array[1] = getchar();
		// // 3rd number
		// num_array[0] = getchar(); 
		
		// input_volts = ((num_array[2] - 48)*100) + ((num_array[1] - 48)*10) + (num_array[0]-48) ;
		// I2C_TXR = input_volts ;
		
		// printf( "\nWrote step %d to DAC\n", input_volts );
		
		// // wait for transimit done
		// // wait for ack from slave, when bit 7 of SR is zero, then acknowledged
		// while ( I2C_SR & 0x82 ) {}
		
		// // command register tells the chip to continue the write, set  WR (bit 4) and IACK (bit 0) to 1 during a write
		// I2C_CR = 0x11 ;
		// // wait for transimit done
		// // wait for ack from slave, when bit 7 of SR is zero, then acknowledged
		// while ( I2C_SR & 0x82 ) {}
   // }
   
	// printf("\nExiting DAC write . . .\n" );
   
	// // command register tells the chip to stop the write, set  STO (bit 6) to 1
	// I2C_CR = 0x40 ;
	// I2C_TXR = 0x0 ;
	
	// // wait for transimit done
	// // wait for ack from slave, when bit 7 of SR is zero, then acknowledged
	// while ( I2C_SR & 0x82 ) {}
// }
