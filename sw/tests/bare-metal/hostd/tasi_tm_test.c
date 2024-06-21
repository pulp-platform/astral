
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
    
   
	//printf("TEST - TM module \n\n");  

	unsigned int packet_len = 36;
	unsigned char ccsds_fixed_char[36]={ 0x09,0x4c,0xc0,0x01,0x00,0x1d,0x0C,0x10, 0xFF,0xFF,0x0C,0x20,0xFF,0x20,0x0C,0x30,0xFF,0x20,0x0C,0x40,0xFF,0x30,0x0C,0x50,0xFF,0x40,0x0C,0x60,0xFF,0x50,0x0C,0x70,0xFF,0x60,0x0C,0x80};
	unsigned int ccsds_fixed[9]={ 0x094cc002,0x001daf01, 0x0000af02,0x0001af03,0x0002af04,0x0003af05,0x0004af06,0x0005af07,0x0006af08};
	
	//NOTE : THE CONTENT OF CCSDS CHANGE IN ssc AND data
	
	unsigned int i;
	
	//for(i=0;i<9;i++)
	//printf("0x%.8x ",ccsds_fixed[i]);


	W_REG(STREAMER_TME_ENACONF) =	0xFFFFF001; //0x00010000;
	W_REG(STREAMER_TME_TMFCONF) =	0x3FFE0023; //0xFFFA0020; 

	W_REG(STREAMER_TME_CP) =	0x00000000;

	W_REG(STREAMER_TME_BRD) =	0x00000000;

	W_REG(STREAMER_TME_INIT) =	0x0000AAAA;
	
	
	//check interface Ready
	
	//printf("0x%x - check bit 6 \n",MEM(STREAMER_PTME_CONFIG));
	
	//enable packet
	W_REG(STREAMER_PTME_CONFIG) = 8 ;//0xB; //bit 3 Valid to 1 and Size to 32bit
		
	//SET_BIT(W_REG(STREAMER_PTME_CONFIG),BIT3);

	for(i=0;i<packet_len;i++)
	{
		W_MEM8(STREAMER_PTME_DATA) = ccsds_fixed_char[i];
	}
	
	//disable packet
	W_REG(STREAMER_PTME_CONFIG ) = 0x0; //bit 3 Valid to 0 --> end of packet
	



	//enable packet
	W_REG(STREAMER_PTME_CONFIG) = 0xB; //bit 3 Valid to 1 and Size to 32bit
		
	//SET_BIT(W_REG(STREAMER_PTME_CONFIG),BIT3);

	for(i=0;i<packet_len/4;i++)
	{
		W_MEM(STREAMER_PTME_DATA) = ccsds_fixed[i];
	}
	
	//disable packet
	W_REG(STREAMER_PTME_CONFIG ) = 0x0; //bit 3 Valid to 0 --> end of packet
	





	//printf("\n end TEST TM module \n\n");  	
	
	
		
    while (1);
    
    return 0;
}

