
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
   	unsigned int nreg;
    unsigned int offset;
	unsigned int reg;
	//printf("TEST - HPC module \n\n");  

	
	//MPR
	nreg=32;
	offset = STREAMER_REG_BUS | 0x00;

	for(i=0;i<nreg;i++)
	{
	reg = R_REG(offset + 4*i);
	}



	//HPC
	nreg=30;
	offset = STREAMER_REG_BUS | 0x80;

	for(i=0;i<nreg;i++)
	{
	reg = R_REG(offset + 4*i);
	}


	//OBT
	nreg=21;
	offset = STREAMER_REG_BUS | 0x100;

	for(i=0;i<nreg;i++)
	{
	reg = R_REG(offset + 4*i);
	}


	//TME
	nreg=30;
	offset = STREAMER_REG_BUS | 0x180;

	for(i=0;i<nreg;i++)
	{
	reg = R_REG(offset + 4*i);
	}



	//PTD
	nreg=10;
	offset = STREAMER_REG_BUS | 0x200;

	for(i=0;i<nreg;i++)
	{
	reg = R_REG(offset + 4*i);
	}

	//MISC
	nreg=8;
	offset = STREAMER_REG_BUS | 0x280;

	for(i=0;i<nreg;i++)
	{
	reg = R_REG(offset + 4*i);
	}



	//LLC
	nreg=43;
	offset = STREAMER_REG_BUS | 0x300;

	for(i=0;i<nreg;i++)
	{
	reg = R_REG(offset + 4*i);
	}




    while (1);
    
    return 0;
}

