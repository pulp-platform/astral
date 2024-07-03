
#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "car_util.h"
#include "printf.h"
#include "tasi.h"


int main(void) {


    
   	unsigned int i;
   	unsigned int nreg;
    unsigned int offset;
	unsigned int reg;
	//printf("TEST - Reg module \n\n");  


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


    //if return all ok!
    return 0;
}

