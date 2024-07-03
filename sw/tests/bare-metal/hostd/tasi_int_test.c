#include "tasi.h"

int main(void) {

 	init_chip();
    
   	unsigned int int_pend_flag,int_pend_reg,busy;
	unsigned int atss_start,atsss_start,atss_end,atsss_end;

	//printf("TEST - Interrupt module \n\n");  



    // Reset system timer
    writed(1, CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_RESET_LO_OFFSET);



    





	//unmask all interrupt
	W_REG(STREAMER_INTERRUPT_MASK) = 0xFFFF;
	//clear interrupt
	W_REG(STREAMER_INTERRUPT_CLEAR) = INTERRUPT_MASK;
	




	//wait RTC
	/*
	do
	{
		int_pend_flag = BIT_IS_SET (R_REG(STREAMER_INTERRUPT_PENDING), STREAMER_INTERRUPT_RTC);
	}while (int_pend_flag == 0);
	*/
	WAIT_BIT_SET(R_REG(STREAMER_INTERRUPT_PENDING),STREAMER_INTERRUPT_RTC);

	//clear interrupt
	//W_REG(STREAMER_INTERRUPT_CLEAR) = STREAMER_INTERUPT_RTC;
	SET_BIT(W_REG(STREAMER_INTERRUPT_CLEAR),STREAMER_INTERRUPT_RTC);
	//verify is 0
	int_pend_reg = R_REG(STREAMER_INTERRUPT_PENDING);
	

	// Read ACTUAL TIME

	atss_start = R_REG(STREAMER_OBT_ATSS);
	atsss_start = R_REG(STREAMER_OBT_ATSSS);


	// Start system timer
    writed(1, CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_START_LO_OFFSET);
	
	//wait RTC
	/*
	do
	{
		int_pend_flag = BIT_IS_SET (R_REG(STREAMER_INTERRUPT_PENDING), STREAMER_INTERRUPT_RTC);
	}while (int_pend_flag == 0);
	*/
	WAIT_BIT_SET(R_REG(STREAMER_INTERRUPT_PENDING),STREAMER_INTERRUPT_RTC);

    // Stop system timer
    writed(0, CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_CFG_LO_OFFSET);

	// Get system timer count
    volatile int time = readd(CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_CNT_LO_OFFSET);	


	atss_end = R_REG(STREAMER_OBT_ATSS);
	atsss_end = R_REG(STREAMER_OBT_ATSSS);

	//printf("time between 2 RTC = %d \n",time);

	printf("atss_start = 0x%x \n",atss_start);
	printf("atsss_start = 0x%x \n",atsss_start);
	printf("atss_end = 0x%x \n",atss_end);
	printf("atsss_end = 0x%x \n",atsss_end);



	//clear interrupt
	W_REG(STREAMER_INTERRUPT_CLEAR) = INTERRUPT_MASK;




	//wait TS
	/*
	do
	{
		int_pend_flag = BIT_IS_SET (R_REG(STREAMER_INTERRUPT_PENDING), STREAMER_INTERRUPT_TS);
	}while (int_pend_flag == 0);
	*/
	WAIT_BIT_SET(R_REG(STREAMER_INTERRUPT_PENDING),STREAMER_INTERRUPT_TS);


	//clear interrupt
	SET_BIT(W_REG(STREAMER_INTERRUPT_CLEAR),STREAMER_INTERRUPT_TS);
	//verify is 0
	int_pend_reg = R_REG(STREAMER_INTERRUPT_PENDING);
	

	// Read ACTUAL TIME

	atss_start = R_REG(STREAMER_OBT_ATSS);
	atsss_start = R_REG(STREAMER_OBT_ATSSS);


	// Start system timer
    writed(1, CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_START_LO_OFFSET);
	
	//wait TS
	/*
	do
	{
		int_pend_flag = BIT_IS_SET (R_REG(STREAMER_INTERRUPT_PENDING), STREAMER_INTERRUPT_TS);
	}while (int_pend_flag == 0);
	*/
	WAIT_BIT_SET(R_REG(STREAMER_INTERRUPT_PENDING),STREAMER_INTERRUPT_TS);

    // Stop system timer
    writed(0, CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_CFG_LO_OFFSET);

	// Get system timer count
    time = readd(CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_CNT_LO_OFFSET);	


	atss_end = R_REG(STREAMER_OBT_ATSS);
	atsss_end = R_REG(STREAMER_OBT_ATSSS);

	//printf("time between 2 TS = %d \n",time);

	printf("atss_start = 0x%x \n",atss_start);
	printf("atsss_start = 0x%x \n",atsss_start);
	printf("atss_end = 0x%x \n",atss_end);
	printf("atsss_end = 0x%x \n",atsss_end);





    
    return 0;
}

