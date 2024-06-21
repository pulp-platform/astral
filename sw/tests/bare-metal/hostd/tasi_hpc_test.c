
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
	unsigned int hpc_idle;
	//printf("TEST - HPC module \n\n");  

	
	unsigned char arm[11] =  {0xc4,0x10,0x21,0xc0, 0x00,0x00,0x03,0xFF, 0xFF,0x20,0x72};
	unsigned char fire[11] = {0xc0,0x10,0x21,0xc0, 0x03,0x00,0x03,0x00, 0x01,0xC3,0x8E};
	//unsigned char arm[12] =  {0xc4,0x10,0x21,0xc0, 0x00,0x00,0x03,0xFF, 0xFF,0x20,0x72,0x00};
	//unsigned char fire[12] = {0xc0,0x10,0x21,0xc0, 0x03,0x00,0x03,0x00, 0x07,0xa3,0x48,0x00};
	//unsigned char fire[12] = {0xc0,0x10,0x21,0xc0, 0x03,0x00,0x03,0x00, 0x01,0xC3,0x8E,0x00};
	//unsigned char fire[12] = {0xc0,0x12,0x34,0xc0, 0x01,0x00,0x03,0x35, 0x57,0x86,0x24,0x00};
	
	hpc_idle = R_REG(STREAMER_HPC_SST);

	do
	{
		hpc_idle = BIT_IS_SET(R_REG(STREAMER_HPC_SST),STREAMER_HPC_SST_I_E);
	} while (hpc_idle==0);
	

	//send arm
	len=12; //should be 11, but source_tx_buffer uses WADDR as tc_length
	for(i=0;i<len;i++)
	{
			W_MEM8(STREAMER_HPC_LLC_DATA+i) = arm[i];
	}	
	//trigger arm
	W_REG(STREAMER_HPC_LLC_BUFFER_BUSY_SET) = 0xC4;
	
	do
	{
		hpc_idle = BIT_IS_SET(R_REG(STREAMER_HPC_LLC_BUFFER_STATUS),STREAMER_HPC_LLC_BUFF_BUSY);
	} while (hpc_idle==0x800);


	//send fire
	len = 12; //should be 11, but source_tx_buffer uses WADDR as tc_length
	for(i=0;i<len;i++)
	{
		W_MEM8(STREAMER_HPC_LLC_DATA+i) = fire[i];
	}
	//trigger fire
	W_REG(STREAMER_HPC_LLC_BUFFER_BUSY_SET) = 0xC0;
			

    while (1);
    
    return 0;
}

