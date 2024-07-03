#include "tasi.h"

int main(void) {

 	init_chip();

  //printf("%d!\n", hart_id());
    
    unsigned int error = 0;
	unsigned int tc_len;
	unsigned int busy;
	unsigned int i;
	unsigned char expected_tc[16]={0xc1, 0x10 , 0x31 , 0xC0 , 0x01 , 0x00 , 0x05 , 0xFA , 0x00 , 0x00 , 0x07 , 0x7D , 0xE8} ; //from testbench
	unsigned char read_tc[16]={0} ; 

	//printf("TEST - TC module \n\n");  

	//wait TC reading interrupt pending reg
	WAIT_BIT_SET(R_REG(STREAMER_INTERRUPT_PENDING), STREAMER_INTERRUPT_TC);

	//clear pending reg
	W_REG(STREAMER_INTERRUPT_CLEAR) = STREAMER_INTERRUPT_TC;
	
	//get received tc len
	tc_len = R_REG(STREAMER_TC_BUFFER_STATUS) & 0x3FF;

	//read data
	for(i=0;i<tc_len;i++)
	{
		read_tc[i] = R_MEM8(STREAMER_PTD_DATA +i);
		printf(" 0x%x \n",read_tc[i] ); 
		if(read_tc[i]!=expected_tc[i])
		{
			error++;
		}	
	}

	//release buffer
	W_REG(STREAMER_TC_BUFFER_RELEASE) = 0xAAAA;
	
    //printf("\n end TEST TC module \n\n");  	
    if (error == 0) 
  	  printf("Success!\n");
    else 
  	  printf("Failed!\n");

    return error;

}


