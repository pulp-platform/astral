
#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "car_util.h"
#include "printf.h"
#include "tasi.h"


int main(void) {

  // We read the number of available harts.
  uint32_t NumHarts = readw(CHESHIRE_NUM_INT_HARTS);
  uint32_t OtherHart = NumHarts - 1 - hart_id(); // If hart_id() == 0 -> return 1;
                                                 // If hart_id() == 1 -> return 0;

  // Hart 0 enters first
  if (hart_id() != 0) wfi();
    
   	unsigned int i;
   	unsigned int len;
	unsigned int llc_idle;
	//printf("TEST - HPC module \n\n");  

	
	unsigned char arm[11] =  {0xCA,0x10,0x31,0xc0, 0x00,0x00,0x03,0xFF, 0xFF,0x17,0x09};
	unsigned char fire[13] = {0xC7,0x10,0x31,0xC0, 0x01,0x00,0x05,0xF8, 0x00,0x00,0x00,0xE0, 0x67};
	
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
	len=12; //should be 11, but source_tx_buffer uses WADDR as tc_length
	for(i=0;i<len;i++)
	{
			W_MEM8(STREAMER_HPC_LLC_DATA+i) = arm[i];
	}	
	//trigger arm
	W_REG(STREAMER_HPC_LLC_BUFFER_BUSY_SET) = 0xCA;
	
	/*
	do
	{
		llc_idle = BIT_IS_SET(R_REG(STREAMER_HPC_LLC_BUFFER_STATUS),STREAMER_HPC_LLC_BUFF_BUSY);
	} while (llc_idle==0x800);
	*/

	//wait busy
	WAIT_BIT_RESET(R_REG(STREAMER_HPC_LLC_BUFFER_STATUS),STREAMER_HPC_LLC_BUFF_BUSY);


	//send fire
	len = 14; //should be 13, but source_tx_buffer uses WADDR as tc_length
	for(i=0;i<len;i++)
	{
		W_MEM8(STREAMER_HPC_LLC_DATA+i) = fire[i];
	}
	//trigger fire
	W_REG(STREAMER_HPC_LLC_BUFFER_BUSY_SET) = 0xC7;
			

    while (1);
    
    return 0;
}

