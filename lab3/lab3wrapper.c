extern int lab3(void);

void serial_init(void)
{
	  	/* 8-bit word length, 1 stop bit, no parity,  */
	  	/* Disable break control                      */
	  	/* Enable divisor latch access                */
   			*(volatile unsigned *)(0xE000C00C) = 131; 
	  	/* Set lower divisor latch for 9,600 baud */
			*(volatile unsigned *)(0xE000C000) = 120; 
	  	/* Set upper divisor latch for 9,600 baud */
			*(volatile unsigned *)(0xE000C004) = 9; 
	  	/* 8-bit word length, 1 stop bit, no parity,  */
	  	/* Disable break control                      */
	  	/* Disable divisor latch access               */
	  		*(volatile unsigned *)(0xE000C00C) = 3;
}

int main()
{	
   serial_init();
   lab3();
}
