

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
    
   	unsigned int i;
   	unsigned int len=16;
	unsigned int link_running;
	unsigned int pkt_received,pkt_sent;
	unsigned char spw_pkt_tx[16]={0x20,0x00,0x00,0x00,0x12,0x34,0x56,0x78,0xAA,0xBB,0xCC,0xDD,0x00,0x00,0xED,0xED};
	unsigned char spw_pkt_rx[16]={0};

	//printf("TEST - SPW module \n\n");  

	//start spw
	SET_BIT(W_REG(SPW_CTRL), SPW_CTRL_START);


	//wait link running
	do{
		link_running =   BIT_IS_SET (R_REG(SPW_STATUS), SPW_STATUS_LINK_RUN);
	}while(link_running == 0);

	//arm RX
	W_MEM(SPW_RX_CTRL) = SPW_RX_CTRL_CODE;

	//set len
	len=16;
	
	//copy data in buffer
	for(i=0;i<len;i++)
	{
		W_MEM8(SPW_APB_TX+i) = spw_pkt_tx[i];
	}

	//start transaction
	W_REG(SPW_TX_CTRL) = ADD_BIT(SPW_TC_CTRL_SEND_EOP) | len;
    
	//wait end TX	
	do{
		pkt_sent =   BIT_IS_SET (R_REG(SPW_TX_STATUS), SPW_TX_STATUS_TX_BUFFER_SENT);
	}while(pkt_sent == 0);

	//wait RX	
	do{
		pkt_received =   BIT_IS_SET (R_REG(SPW_RX_STATUS), SPW_RX_STATUS_EOP_RECEIVED);
	}while(pkt_received == 0);

	//get len
	len = R_REG(SPW_RX_STATUS) & 0x7FF;

	//get data
	for(i=0;i<len;i++)
	{
		spw_pkt_rx[i] = W_MEM8(SPW_APB_RX+i);
	}
	
	//print len
	printf("len = %d ",len);

	//print data
	for(i=0;i<len;i++)
	{
		printf("0x%x ",spw_pkt_rx[i]);
	}

    while (1);
    
    return 0;
}
