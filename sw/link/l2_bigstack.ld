/* Script linker custom: include lo script L2 originale, poi sovrascrive
 * __stack_size$ con un valore maggiore (16 KiB invece di 4 KiB di default),
 * necessario per evitare la sovrapposizione di stack tra i 2 hart nel
 * porting SMP di OBPMark (pipeline a 6 funzioni innestate). */
INCLUDE l2.ld
__stack_size$ = 0x4000;
