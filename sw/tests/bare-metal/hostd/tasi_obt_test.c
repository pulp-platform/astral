#include "tasi.h"



int main(void) {

 	init_chip();

	//printf("TEST - OBT module \n\n");  
	unsigned int tmp;
	unsigned long time_us_start,duration;
	unsigned long time_us_start_streamer,duration_streamer;

	printf(".\n");
 	start_time (&time_us_start);
		wait_us(200);
  	end_time (time_us_start,&duration);
	printf("dur wait 200 = %d \n",duration);

	printf(".\n");
 	start_time (&time_us_start);
		wait_us(300);
  	end_time (time_us_start,&duration);
	printf("dur wait 300 = %d \n",duration);

 	start_time (&time_us_start);
		tmp = R_REG(STREAMER_OBT_ATSS);
  	end_time (time_us_start,&duration);
	printf("dur read reg = %d \n",duration);

	printf(".\n");
	start_time_streamer(&time_us_start_streamer);
		wait_us(200);
	end_time_streamer (time_us_start_streamer,&duration_streamer); 
	printf("dur wait 200 streamer = %d \n",duration_streamer);

	printf(".\n");
	start_time_streamer(&time_us_start_streamer);
		wait_us(300);
	end_time_streamer (time_us_start_streamer,&duration_streamer); 
	printf("dur wait 300 streamer = %d \n",duration_streamer);
	

	printf("Hello world!\n");
	printf("I'm MuSA!\n");
	printf("I will print a dot each second\n");
	do{
		wait_us(1000000);
		printf(".");
	}
	while(1);

    return 0;
}

