
// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Robert Balas <balasr@iis.ee.ethz.ch>
//

/* Description: Memory mapped register I/O access
 */

#ifndef __TASI_H
#define __TASI_H


#define BIT0 0
#define BIT1 1
#define BIT2 2
#define BIT3 3
#define BIT4 4

#define BIT11 11

#define BIT16 16

#define BIT24 24

#define STREAMER_REG_BUS 0x20009000
#define	STREAMER_APB 0x20011000
#define SPW_REG_BUS 0x20019000
#define	SPW_APB 0x20019100

//Streamer

#define STREAMER_PTME_CONFIG  (STREAMER_APB | 0x000)
#define STREAMER_PTME_DATA    (STREAMER_APB | 0x400)
#define STREAMER_PTD_DATA     (STREAMER_APB | 0x800)
#define STREAMER_HPC_LLC_DATA (STREAMER_APB | 0xC00)
	

#define STREAMER_OBT_ATSS        (STREAMER_REG_BUS | 0x120)
#define STREAMER_OBT_ATSSS  	 (STREAMER_REG_BUS | 0x124)

#define STREAMER_TC_BUFFER_STATUS    	 (STREAMER_REG_BUS | 0x280)
#define STREAMER_TC_BUFFER_RELEASE   	 (STREAMER_REG_BUS | 0x284)
#define STREAMER_HPC_LLC_BUFFER_BUSY_SET (STREAMER_REG_BUS | 0x288)
#define STREAMER_HPC_LLC_BUFFER_STATUS 	 (STREAMER_REG_BUS | 0x28C)
#define STREAMER_HPTM_PACKET_HEADER  	 (STREAMER_REG_BUS | 0x290)
	
#define STREAMER_INTERRUPT_MASK    (STREAMER_REG_BUS | 0x294)
#define STREAMER_INTERRUPT_CLEAR   (STREAMER_REG_BUS | 0x298)
#define STREAMER_INTERRUPT_FORCE   (STREAMER_REG_BUS | 0x29C)
#define STREAMER_INTERRUPT_PENDING (STREAMER_REG_BUS | 0x2A0)
	
//#define STREAMER_INTERUPT_TC  0x1
//#define STREAMER_INTERUPT_PPS 0x2
//#define STREAMER_INTERUPT_TS  0x4
//#define STREAMER_INTERUPT_RTC 0x8

#define STREAMER_INTERRUPT_TC  BIT0
#define STREAMER_INTERRUPT_PPS BIT1
#define STREAMER_INTERRUPT_TS  BIT2
#define STREAMER_INTERRUPT_RTC BIT3


#define STREAMER_INTERRUPT_TC_ABS_VALUE  (1<<STREAMER_INTERRUPT_TC)
#define STREAMER_INTERRUPT_PPS_ABS_VALUE (1<<STREAMER_INTERRUPT_PPS)
#define STREAMER_INTERRUPT_TS_ABS_VALUE  (1<<STREAMER_INTERRUPT_TS)
#define STREAMER_INTERRUPT_RTC_ABS_VALUE (1<<STREAMER_INTERRUPT_RTC)

#define STREAMER_HPC_SST     (STREAMER_REG_BUS | 0x94)

#define STREAMER_HPC_SST_I_E BIT24
#define STREAMER_HPC_LLC_BUFF_BUSY BIT11

#define STREAMER_LLC_EST     (STREAMER_REG_BUS | 0x318)

#define STREAMER_LLC_EST_I_E BIT16

#define STREAMER_TME_INIT     (STREAMER_REG_BUS | 0x180)
#define STREAMER_TME_ENACONF  (STREAMER_REG_BUS | 0x184)
#define STREAMER_TME_TMFCONF  (STREAMER_REG_BUS | 0x1C8)
#define STREAMER_TME_CP       (STREAMER_REG_BUS | 0x1E8)
#define STREAMER_TME_BRD      (STREAMER_REG_BUS | 0x1EC)

//SPW

#define SPW_APB_TX  (SPW_APB + 0x000)
#define SPW_APB_RX  (SPW_APB + 0x400)

#define SPW_CTRL      (SPW_REG_BUS | 0x000)
#define SPW_STATUS    (SPW_REG_BUS | 0x004)
#define SPW_TX_RATE   (SPW_REG_BUS | 0x008)
#define SPW_RX_CTRL   (SPW_REG_BUS | 0x00C)
#define SPW_RX_STATUS (SPW_REG_BUS | 0x010)
#define SPW_TX_CTRL   (SPW_REG_BUS | 0x014)
#define SPW_TX_STATUS (SPW_REG_BUS | 0x018)
#define SPW_IRQ_PEND  (SPW_REG_BUS | 0x01C)
#define SPW_IRQ_FORCE (SPW_REG_BUS | 0x020)
#define SPW_IRQ_CLEAR (SPW_REG_BUS | 0x024)
#define SPW_IRQ_MASK  (SPW_REG_BUS | 0x028)

#define SPW_CTRL_START   BIT2
#define SPW_RX_CTRL_CODE   0xAAAA
#define SPW_STATUS_LINK_RUN BIT4

#define SPW_TC_CTRL_SEND_EOP   BIT16

#define SPW_RX_STATUS_EOP_RECEIVED   BIT16
#define SPW_TX_STATUS_TX_BUFFER_SENT BIT16

#define SPW_CTRL_START   BIT2

#define SPW_STATUS_LINK_RUN BIT4

#define TX_BUFFER_CTRL_PKT_COMPLETE   BIT16


#define SET_BIT(val, bitIndex)    (val |= (1 << bitIndex))
#define CLEAR_BIT(val, bitIndex)  (val &= ~(1 << bitIndex))
#define TOGGLE_BIT(val, bitIndex) (val ^= (1 << bitIndex))
#define BIT_IS_SET(val, bitIndex) (val & (1 << bitIndex)) 

#define ADD_BIT(bitIndex) (1 << bitIndex)

#define MEM8(x) (*(volatile unsigned char*)(x)) 
#define MEM16(x) (*(volatile unsigned short*)(x)) 
#define MEM32(x)  (*(volatile unsigned int*)(x))

#define MEM(x)  (*(volatile unsigned int*)(x))

#define R_REG(x) (MEM(x))
#define W_REG(x)  (MEM(x))
#define R_MEM(x) (MEM(x))
#define W_MEM(x) (MEM(x))
#define R_MEM8(x) (MEM8(x))
#define W_MEM8(x) (MEM8(x))

#define WAIT_BIT_SET(val, bitIndex)   { unsigned int wait_bit_set_tmp_var ;                      \
                                        do                                                       \
                                        {                                                        \
                                            wait_bit_set_tmp_var = BIT_IS_SET (val,bitIndex);    \
                                        }while(wait_bit_set_tmp_var == 0);                       \
                                      }

#define WAIT_BIT_RESET(val, bitIndex) { unsigned int wait_bit_reset_tmp_var ;                      \
                                        do                                                         \
                                        {                                                          \
                                            wait_bit_reset_tmp_var =   BIT_IS_SET (val, bitIndex); \
                                        }while(wait_bit_reset_tmp_var == ADD_BIT(bitIndex));       \
                                      }


#endif
