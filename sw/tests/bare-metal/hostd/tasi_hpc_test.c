#include "tasi.h"

int main(void) {

 	init_chip();
    
   	unsigned int i;
   	unsigned int len;
	unsigned int hpc_idle;
	//printf("TEST - HPC module \n\n");  

	unsigned char arm[HPC_ARM_LEN] =  {0xc4,0x10,0x21,0xc0, 0x00,0x00,0x03,0xFF, 0xFF,0x20,0x72};
	unsigned char fire[HPC_FIRE_LEN] = {0xc0,0x10,0x21,0xc0, 0x03,0x00,0x03,0x00, 0x01,0xC3,0x8E};

	wait_us(2000);
		
	hpc_idle = R_REG(STREAMER_HPC_SST);
	//wait Idle
	/*
	do
	{
		hpc_idle = BIT_IS_SET(R_REG(STREAMER_HPC_SST),STREAMER_HPC_SST_I_E);
	} while (hpc_idle==0);
	*/
	WAIT_BIT_SET(R_REG(STREAMER_HPC_SST),STREAMER_HPC_SST_I_E);

	//send arm
	len=HPC_ARM_LEN; //should be 11, but source_tx_buffer uses WADDR as tc_length
	for(i=0;i<len;i++)
	{
			W_MEM8(STREAMER_HPC_LLC_DATA+i) = arm[i];
	}	
	//trigger arm
	W_REG(STREAMER_HPC_LLC_BUFFER_BUSY_SET) = arm[0];
	
	//wait not busy
	/*
	do
	{
		hpc_idle = BIT_IS_SET(R_REG(STREAMER_HPC_LLC_BUFFER_STATUS),STREAMER_HPC_LLC_BUFF_BUSY);
	} while (hpc_idle==0x800);
	*/
	WAIT_BIT_RESET(R_REG(STREAMER_HPC_LLC_BUFFER_STATUS),STREAMER_HPC_LLC_BUFF_BUSY);

	//send fire
	len = HPC_FIRE_LEN; //should be 11, but source_tx_buffer uses WADDR as tc_length
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

