#include "tasi.h"



int main(void) {

 	init_chip();
    
	unsigned int error = 0;
   	unsigned int i;
   	unsigned int len=16;
	unsigned int link_running;
	unsigned int pkt_received,pkt_sent;
	unsigned char spw_pkt_tx_char[16]={0x20,0x00,0x00,0x00,0x12,0x34,0x56,0x78,0xAA,0xBB,0xCC,0xDD,0x01,0x02,0xED,0xED}; //first byte 0x20 last byte 0x00, first byte 0x12 last byte 0x78 ....

	unsigned int spw_pkt_tx_int[4]={0x00000020,0x78563412,0xDDCCBBAA,0xEDED0201}; //first byte 0x20 last byte 0x00, first byte 0x12 last byte 0x78 ....
	unsigned int spw_pkt_rx_int[4]={0};
	unsigned char compare =0;

	//printf("TEST - SPW module \n\n");  

	//configure tx rate
	//W_REG(SPW_TX_RATE) = (4<<16) | 0x31; // if clk is 500MHz
	W_REG(SPW_TX_RATE) = (0<<16) | 0x9;    // if clk is 100MHz

	//unmask interrupt
	W_REG(SPW_IRQ_MASK) = 0xFF;

	//start spw
	SET_BIT(W_REG(SPW_CTRL), SPW_CTRL_START);


	//wait link running
	/*
	do{
		link_running =   BIT_IS_SET (R_REG(SPW_STATUS), SPW_STATUS_LINK_RUN);
	}while(link_running == 0);
	*/
	WAIT_BIT_SET(R_REG(SPW_STATUS),SPW_STATUS_LINK_RUN);

	//arm RX
	W_MEM(SPW_RX_CTRL) = SPW_RX_CTRL_CODE;

	//set len
	len=16;
	/*
	for(i=0;i<len/4;i++)
	{
		W_MEM(SPW_APB_TX+4*i) = spw_pkt_tx_int[i];
	}
*/
	for(i=0;i<len/4;i++)
	{
		W_MEM(SPW_APB_TX+4*i) = ((unsigned int *)spw_pkt_tx_char)[i];
	}


	//start transaction
	W_REG(SPW_TX_CTRL) = ADD_BIT(SPW_TC_CTRL_SEND_EOP) | len;
    
	//wait end TX	
	/*
	do{
		pkt_sent =   BIT_IS_SET (R_REG(SPW_TX_STATUS), SPW_TX_STATUS_TX_BUFFER_SENT);
	}while(pkt_sent == 0);
	*/
	WAIT_BIT_SET(R_REG(SPW_TX_STATUS),SPW_TX_STATUS_TX_BUFFER_SENT);

	//wait RX	
	/*
	do{
		pkt_received =   BIT_IS_SET (R_REG(SPW_RX_STATUS), SPW_RX_STATUS_EOP_RECEIVED);
	}while(pkt_received == 0);
	*/
	WAIT_BIT_SET(R_REG(SPW_RX_STATUS),SPW_RX_STATUS_EOP_RECEIVED);

	//get len
	len = R_REG(SPW_RX_STATUS) & 0x7FF;

	//get data
	/*
	for(i=0;i<len;i++)
	{
		spw_pkt_rx_char[i] = R_MEM8(SPW_APB_RX+i);
	}
	*/
	for(i=0;i<len/4;i++)
	{
		spw_pkt_rx_int[i] = R_MEM(SPW_APB_RX+4*i);
	}

	//print len
	printf("len = %d \n",len);

	//print len
	printf("IRQ pending = 0x%x \n",R_REG(SPW_IRQ_PEND));

	for(i=0;i<len;i++)
	{
		printf("0x%x \n",((unsigned char*)spw_pkt_rx_int)[i]);
		compare = (((unsigned char*)spw_pkt_tx_int)[i]<<1) & 0xFF;

		//if(spw_pkt_rx_int[i]!=(spw_pkt_tx_int[i]<<1)) //if loopback 
		if(((unsigned char*)spw_pkt_rx_int)[i]!=compare)
		{
			error++;
			printf("error, rx = 0x%x, c = 0x%x \n",((unsigned char*)spw_pkt_rx_int)[i],compare);
		}	
	}


	//End test
    if (error == 0) 
  	  printf("Success!\n");
    else 
  	  printf("Failed!\n");

    return error;



  //return 0; //test passed
  //return !0; //test not passed
}
