#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#ifdef _OPENMP
#include <omp.h>
#endif

int tryHit(unsigned int *seed);

int main(int argc, char *argv[]) {
    long tries = 65536, hits = 0;
    if (argc > 1) 
        tries = atol(argv[1]);
#pragma omp parallel default(none) shared(tries, hits)
    {
        unsigned int seed = 0;
        int i;
#ifdef _OPENMP
        seed = omp_get_thread_num();
#endif
#pragma omp for reduction(+:hits)
        for (i = 0; i < tries; i++)
            hits += tryHit(&seed);
    }
    printf("pi (exact)  = %lf\n", acos(-1.0));
    printf("pi (approx) = %lf (%ld)\n", (4.0*hits)/tries, hits);
    return EXIT_SUCCESS;
}

int tryHit(unsigned int *seed) {
    double x = ((double) rand_r(seed))/RAND_MAX;
    double y = ((double) rand_r(seed))/RAND_MAX;
    return x*x + y*y <= 1.0;
}

