#include "tasi.h"

int main(void) {

 	init_chip();
    
   	unsigned int i;
   	unsigned int len;
	unsigned int llc_idle;
	//printf("TEST - LLC module \n\n");  

	
	unsigned char arm[LLC_ARM_LEN] =  {0xCA,0x10,0x31,0xc0, 0x00,0x00,0x03,0xFF, 0xFF,0x17,0x09};
	unsigned char fire[LLC_FIRE_LEN] = {0xC7,0x10,0x31,0xC0, 0x01,0x00,0x05,0xF8, 0x00,0x00,0x00,0xE0, 0x67};
	
	wait_us(2000);

	llc_idle = R_REG(STREAMER_LLC_EST);

	/*
	do
	{
		llc_idle = BIT_IS_SET(R_REG(STREAMER_LLC_EST),STREAMER_LLC_EST_I_E);
	} while (llc_idle==0);
	*/	

	//wait bit Idle is set
	WAIT_BIT_SET(R_REG(STREAMER_LLC_EST),STREAMER_LLC_EST_I_E);


	//send arm
	len=LLC_ARM_LEN; 
	for(i=0;i<len;i++)
	{
		W_MEM8(STREAMER_HPC_LLC_DATA+i) = arm[i];
	}	
	//trigger arm
	W_REG(STREAMER_HPC_LLC_BUFFER_BUSY_SET) = arm[0];
	
	/*
	do
	{
		llc_idle = BIT_IS_SET(R_REG(STREAMER_HPC_LLC_BUFFER_STATUS),STREAMER_HPC_LLC_BUFF_BUSY);
	} while (llc_idle==0x800);
	*/

	//wait busy
	WAIT_BIT_RESET(R_REG(STREAMER_HPC_LLC_BUFFER_STATUS),STREAMER_HPC_LLC_BUFF_BUSY);


	//send fire
	len = LLC_FIRE_LEN; //should be 13, but source_tx_buffer uses WADDR as tc_length
	for(i=0;i<len;i++)
	{
		W_MEM8(STREAMER_HPC_LLC_DATA+i) = fire[i];
	}
	//trigger fire
	W_REG(STREAMER_HPC_LLC_BUFFER_BUSY_SET) = fire[0];

	//wait busy
	WAIT_BIT_RESET(R_REG(STREAMER_HPC_LLC_BUFFER_STATUS),STREAMER_HPC_LLC_BUFF_BUSY);

	while(1);

    return 0;
}

