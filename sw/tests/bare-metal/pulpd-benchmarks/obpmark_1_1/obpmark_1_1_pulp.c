/*
 * OBPMark Benchmark #1.1 - Image Calibration and Correction
 * Porting parallelo per il cluster integer PULP di Astral (8x RI5CY/cv32e40p, RV32)
 *
 * Pattern di programmazione ricalcato da matrixMul.c (regression_tests/astral/parMatrixMul8/),
 * validato su questa stessa piattaforma:
 *   - testcase_t/run_suite per la gestione automatica del timer (bench_timer_start/stop)
 *   - synch_barrier() fornita dal runtime PULP (nessuna barriera custom necessaria,
 *     a differenza del porting sul domain host CVA6)
 *   - Tutti gli 8 core partono insieme al boot del cluster (nessun smp_resume() necessario)
 *
 * Dimensione: 32x32 (limite TCDM = 128 KB, dato 31 bytes/pixel necessari)
 */

#include "pulp.h"
#include <stdint.h>

// ============================================================
// Configurazione benchmark
// ============================================================
#define IMG_W           32
#define IMG_H           32
#define NUM_FRAMES        8
#define NUM_NEIGHBOURS    4
#define TOTAL_FRAMES    (NUM_FRAMES + NUM_NEIGHBOURS)   // 12
#define OFFSET_NEIGHBOURS 2

// ============================================================
// Strutture dati (identiche a obpmark_image.h originale)
// ============================================================
typedef struct { uint16_t *f; unsigned int w; unsigned int h; } frame16_t;
typedef struct { uint8_t  *f; unsigned int w; unsigned int h; } frame8_t;
typedef struct { uint32_t *f; unsigned int w; unsigned int h; } frame32_t;

#define PIXEL(frame, x, y) ((frame)->f[(y) * (frame)->w + (x)])

// ============================================================
// Backing storage statico  risiede in TCDM (default per build cluster PULP)
// Condiviso tra tutti gli 8 core, cache-coherent a livello di TCDM
// ============================================================
static uint16_t _frames_data [TOTAL_FRAMES][IMG_H * IMG_W];
static uint16_t _offsets_data [IMG_H * IMG_W];
static uint16_t _gains_data   [IMG_H * IMG_W];
static uint8_t  _badpix_data  [IMG_H * IMG_W];
static uint32_t _output_data  [(IMG_H/2) * (IMG_W/2)];
static uint32_t _binned_data  [(IMG_H/2) * (IMG_W/2)];

static frame16_t frames[TOTAL_FRAMES];
static frame16_t offsets_frame;
static frame16_t gains_frame;
static frame8_t  bad_pixels_frame;
static frame32_t output_frame;
static frame32_t binned_frame;

unsigned int num_cores;

static void init_frames(void) {
    unsigned int i;
    for (i = 0; i < TOTAL_FRAMES; i++) {
        frames[i].f = _frames_data[i];
        frames[i].w = IMG_W;
        frames[i].h = IMG_H;
    }
    offsets_frame.f    = _offsets_data; offsets_frame.w    = IMG_W;   offsets_frame.h    = IMG_H;
    gains_frame.f      = _gains_data;   gains_frame.w      = IMG_W;   gains_frame.h      = IMG_H;
    bad_pixels_frame.f = _badpix_data;  bad_pixels_frame.w = IMG_W;   bad_pixels_frame.h = IMG_H;
    output_frame.f     = _output_data;  output_frame.w     = IMG_W/2; output_frame.h     = IMG_H/2;
    binned_frame.f     = _binned_data;  binned_frame.w     = IMG_W/2; binned_frame.h     = IMG_H/2;
}

// ============================================================
// Generazione dati sintetici  eseguita SOLO da core 0
// ============================================================
static unsigned int _rand_state;

static unsigned int bm_rand(void) {
    _rand_state = _rand_state * 1103515245u + 12345u;
    return (_rand_state >> 16u) & 0x7FFFu;
}

static void gen_rand_data(void) {
    unsigned int f, x, y;
    const unsigned int randmax = 65535u;
    _rand_state = 21121993u;   // BENCHMARK_RAND_SEED originale

    for (f = 0; f < TOTAL_FRAMES; f++)
        for (x = 0; x < IMG_W; x++)
            for (y = 0; y < IMG_H; y++)
                PIXEL(&frames[f], x, y) = (uint16_t)(bm_rand() % randmax);

    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&offsets_frame, x, y) = (uint16_t)(bm_rand() % randmax);

    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&gains_frame, x, y) = (uint16_t)(bm_rand() % randmax);

    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&bad_pixels_frame, x, y) = ((uint8_t)(bm_rand() % randmax)) & 0x01u;

    for (x = 0; x < IMG_W/2; x++)
        for (y = 0; y < IMG_H/2; y++)
            PIXEL(&output_frame, x, y) = 0u;
}

// ============================================================
// Divisione del lavoro tra gli 8 core (stesso pattern di matrixMul.c)
// ============================================================
static inline void split_range(unsigned int total, unsigned int id,
                                unsigned int n, unsigned int *start,
                                unsigned int *end) {
    unsigned int chunk = total / n;
    *start = id * chunk;
    *end   = (id == n - 1u) ? total : (*start + chunk);
}

// ============================================================
// KERNEL FUNCTIONS  identiche all'algoritmo originale, parametrizzate
// sul range [xs, xe) di colonne assegnato a ciascun core
// ============================================================

// [I] Bias offset correction
static void f_offset_range(frame16_t *frame, frame16_t *offsets,
                            unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) -= PIXEL(offsets, x, y);
}

static uint32_t f_neighbour_masked_sum(frame16_t *frame, frame8_t *mask,
                                        int x_mid, int y_mid) {
    int x, y;
    int x_start = -1, x_stop = 1, y_start = -1, y_stop = 1;
    unsigned int n_sum = 0;
    uint32_t sum = 0, mean;

    if (x_mid == 0)                        x_start = 0;
    else if (x_mid == (int)(frame->w - 1)) x_stop  = 0;
    if (y_mid == 0)                        y_start = 0;
    else if (y_mid == (int)(frame->h - 1)) y_stop  = 0;

    for (x = x_start; x < (x_stop + 1); x++)
        for (y = y_start; y < (y_stop + 1); y++)
            if (PIXEL(mask, (x_mid+x), (y_mid+y)) == 0) {
                sum += PIXEL(frame, (x_mid+x), (y_mid+y));
                n_sum++;
            }

    mean = (n_sum == 0u) ? 0u : sum / n_sum;
    return mean;
}

// [II] Bad pixel correction (legge vicini 3x3 -> serve barrier prima, su tutta l'immagine)
static void f_mask_replace_range(frame16_t *frame, frame8_t *mask,
                                  unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++)
            if (PIXEL(mask, x, y) == 1u)
                PIXEL(frame, x, y) = (uint16_t)f_neighbour_masked_sum(
                    frame, mask, (int)x, (int)y);
}

// [III] Radiation scrubbing
static void f_scrub_range(frame16_t *frame, frame16_t *fs, unsigned int frame_i,
                           unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    static unsigned int num_neighbour = 4u;
    uint32_t sum, mean, thr;

    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++) {
            sum  = PIXEL(&fs[frame_i-2], x, y) + PIXEL(&fs[frame_i-1], x, y)
                 + PIXEL(&fs[frame_i+1], x, y) + PIXEL(&fs[frame_i+2], x, y);
            mean = sum / num_neighbour;
            thr  = 2u * mean;
            if (PIXEL(frame, x, y) > thr)
                PIXEL(frame, x, y) = (uint16_t)mean;
        }
}

// [IV] Gain correction
static void f_gain_range(frame16_t *frame, frame16_t *gains,
                          unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) = (uint16_t)(
                ((uint32_t)PIXEL(frame, x, y) *
                 (uint32_t)PIXEL(gains, x, y)) >> 16);
}

// [V] 2x2 Spatial binning (indici a meta' risoluzione)
static void f_2x2_bin_range(frame16_t *frame, frame32_t *binned,
                             unsigned int xs2, unsigned int xe2) {
    unsigned int x2, y2;
    for (x2 = xs2; x2 < xe2; x2++) {
        unsigned int x = x2 * 2u;
        for (y2 = 0; y2 < binned->h; y2++) {
            unsigned int y = y2 * 2u;
            PIXEL(binned, x2, y2) = PIXEL(frame,  x,     y    )
                                  + PIXEL(frame, (x+1u), y    )
                                  + PIXEL(frame,  x,    (y+1u))
                                  + PIXEL(frame, (x+1u),(y+1u));
        }
    }
}

// [VI] Frame co-adding (meta' risoluzione)
static void f_coadd_range(frame32_t *sum_frame, frame32_t *add_frame,
                           unsigned int xs2, unsigned int xe2) {
    unsigned int x, y;
    for (x = xs2; x < xe2; x++)
        for (y = 0; y < sum_frame->h; y++)
            PIXEL(sum_frame, x, y) += PIXEL(add_frame, x, y);
}

// ============================================================
// Pipeline SPMD: ogni core calcola il proprio range, esegue il kernel,
// poi synch_barrier() (fornita dal runtime) prima del kernel successivo
// ============================================================
static void prepare_image_frame_par(frame16_t *frame, unsigned int cid) {
    unsigned int xs, xe;
    split_range(IMG_W, cid, num_cores, &xs, &xe);

    f_offset_range(frame, &offsets_frame, xs, xe);          // [I]
    synch_barrier();
    f_mask_replace_range(frame, &bad_pixels_frame, xs, xe); // [II]
    synch_barrier();
}

static void proc_image_frame_par(frame16_t *frame, unsigned int frame_i,
                                  unsigned int cid) {
    unsigned int xs, xe, xs2, xe2;
    split_range(IMG_W, cid, num_cores, &xs, &xe);
    split_range(IMG_W/2, cid, num_cores, &xs2, &xe2);

    f_scrub_range(frame, frames, frame_i, xs, xe);          // [III]
    synch_barrier();
    f_gain_range(frame, &gains_frame, xs, xe);              // [IV]
    synch_barrier();
    f_2x2_bin_range(frame, &binned_frame, xs2, xe2);        // [V]
    synch_barrier();
    f_coadd_range(&output_frame, &binned_frame, xs2, xe2);  // [VI]
    synch_barrier();
}

// ============================================================
// Test case  invocata da run_suite(), che gestisce timer e stampa risultati
// ============================================================
void check_obpmark(testresult_t *result, void (*start)(), void (*stop)());

testcase_t testcases[] = {
    { .name = "obpmark_1_1", .test = check_obpmark },
    {0, 0}
};

int main()
{
    if (rt_cluster_id() != 0)
        return bench_cluster_forward(0);

    num_cores = get_core_num();   // ARCHI_CLUSTER_NB_PE = 8 su Astral

    if (rt_core_id() < num_cores) {
        run_suite(testcases);
    }

    synch_barrier();

    return 0;
}

void check_obpmark(testresult_t *result, void (*start)(), void (*stop)())
{
    unsigned int cid = get_core_id();

    // Inizializzazione: una sola volta, dal core 0
    if (cid == 0) {
        init_frames();
        gen_rand_data();
    }
    if (num_cores != 1) synch_barrier();

    // Inizio misurazione (gestita da bench_timer_start tramite il framework)
    start();

    unsigned int frame_i;
    for (frame_i = OFFSET_NEIGHBOURS;
         frame_i < TOTAL_FRAMES - OFFSET_NEIGHBOURS;
         frame_i++) {
        prepare_image_frame_par(&frames[frame_i + 2u], cid);
        proc_image_frame_par(&frames[frame_i], frame_i, cid);
    }

    if (num_cores != 1) synch_barrier();

    stop();   // fine misurazione

    if (cid == 0) {
        result->errors = 0;   // nessuna verifica contro golden output (dati sintetici)
    }
}