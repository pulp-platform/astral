#include "tasi.h"



int main(void) {

 	init_chip();

	//printf("TEST - TM module \n\n");  

    unsigned int error = 0;
	unsigned int packet_len = 36;
	unsigned char ccsds_char[37]={ 0x09,0x4c,0xc0,0x01,0x00,0x1d,0x0C,0x10, 0xFF,0xFF,0x0C,0x20,0xFF,0x20,0x0C,0x30,0xFF,0x20,0x0C,0x40,0xFF,0x30,0x0C,0x50,0xFF,0x40,0x0C,0x60,0xFF,0x50,0x0C,0x70,0xFF,0x60,0x0C,0x80};
	unsigned int ccsds[9]={ 0x094cc002,0x001daf01, 0x0000af02,0x0001af03,0x0002af04,0x0003af05,0x0004af06,0x0005af07,0x0006af08};
	unsigned int i;
	
	//config PTME
	W_REG(STREAMER_TME_TMFCONF) =	0x3FFE0023; //0xFFFA0020; 

	W_REG(STREAMER_TME_CP) =	0x00000000;

	W_REG(STREAMER_TME_BRD) =	0x00000000;

	//W_REG(STREAMER_TME_INIT) =	0x0000AAAA;

	W_REG(STREAMER_TME_ENACONF) =	0x00010000; //CBA=b1000 --> enable TME
	//W_REG(STREAMER_TME_ENACONF) =	0xFFFFF001; //0x00010000; --> CBA=b1111

	
	
	//check interface Ready
	//wait bit Idle is set
	WAIT_BIT_SET(R_REG(STREAMER_PTME_CONFIG),STREAMER_PTME_CONFIG_READY);

	
	//enable packet
	//W_REG(STREAMER_PTME_CONFIG) = 8 ;//0xB; //bit 3 Valid to 1 and Size to 32bit	
	SET_BIT(W_REG(STREAMER_PTME_CONFIG),BIT3);

	//write packet with 8bit access	
	for(i=0;i<packet_len;i++)
	{
		W_MEM8(STREAMER_PTME_DATA) = ccsds_char[i];
	}
	
	//mark end of packet
	W_REG(STREAMER_PTME_CONFIG ) = 0x0; //bit 3 Valid to 0 --> end of packet
	
	//wait bit Idle is set
	WAIT_BIT_SET(R_REG(STREAMER_PTME_CONFIG),STREAMER_PTME_CONFIG_READY);

	//enable new packet with 32bit mode
	W_REG(STREAMER_PTME_CONFIG) = 0xB; //bit 3 Valid to 1 and Size to 32bit
		
	//write packet with 32bit access	
	for(i=0;i<packet_len/4;i++)
	{
		W_MEM(STREAMER_PTME_DATA) = ccsds[i];
	}
	
	//mark end of packet
	W_REG(STREAMER_PTME_CONFIG ) = 0x0; //bit 3 Valid to 0 --> end of packet
	
	//printf("\n end TEST TM module \n\n");  	
    if (error == 0) 
  	  printf("Success!\n");
    else 
  	  printf("Failed!\n");

	while(1);
    return error;
}

