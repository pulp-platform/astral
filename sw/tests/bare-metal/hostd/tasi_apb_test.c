
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
   	unsigned int len;
    unsigned int offset;
	unsigned char tmp;
	//printf("TEST - Apb module \n\n");  

	//STREAMER_PTME_DATA
	len=1024;
	offset = STREAMER_PTME_DATA ;
	for(i=0;i<len;i++)
	{
		W_MEM8(offset + 4*i) = tmp + (i & 0xFF);
	}

	//STREAMER_HPC_LLC_DATA
	len=1024;
	offset = STREAMER_HPC_LLC_DATA ;
	for(i=0;i<len;i++)
	{
		W_MEM8(offset + 4*i) = tmp + (i & 0xFF);
	}


	//read

	
	//STREAMER_HPC_LLC_DATA
	len=1024;
	offset = STREAMER_HPC_LLC_DATA ;
	for(i=0;i<len;i++)
	{
		tmp = R_MEM8(offset + 4*i);
	}




    //if return all ok!
    return 0;
}

