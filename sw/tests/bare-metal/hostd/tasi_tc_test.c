

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

  //printf("%d!\n", hart_id());
    
    
	unsigned int tc_len;
	unsigned int busy;
	unsigned int i;
	
	//printf("TEST - TC module \n\n");  
	//printf("TEST - Send TC ... \n\n");  
	
	//printf("STREAMER_TC_BUFFER_STATUS = 0x%x \n", MEM(STREAMER_TC_BUFFER_STATUS ) ); 
	


	do
	{
		//busy = * ((unsigned int*)(STREAMER_INTERRUPT_PENDING))  & STREAMER_INTERUPT_TC;
		busy = BIT_IS_SET (R_REG(STREAMER_INTERRUPT_PENDING), STREAMER_INTERRUPT_TC);
	}while (busy == 0);
	
	//* ((unsigned int*)(STREAMER_INTERRUPT_CLEAR))  = STREAMER_INTERUPT_TC;
	W_REG(STREAMER_INTERRUPT_CLEAR) = STREAMER_INTERRUPT_TC;
	
	tc_len = R_REG(STREAMER_TC_BUFFER_STATUS) & 0x3FF;
	//printf("tc_len = %d \n",tc_len); 

	for(i=0;i<tc_len;i++)
	{
		//printf(" 0x%.8x \n",* ((unsigned int*)(STREAMER_PTD_DATA +4*i)) ); 
		printf(" 0x%.8x \n",R_MEM8(STREAMER_PTD_DATA +i) ); 
	}

	//* ((unsigned int*)(STREAMER_TC_BUFFER_RELEASE)) = 0xAAAA;
	W_REG(STREAMER_TC_BUFFER_RELEASE) = 0xAAAA;
	

		
    while (1);
    
    return 0;
}


