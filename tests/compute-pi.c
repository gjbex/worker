#include <err.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    int i, n, hits = 0;
    if (argc != 2)
        errx(EXIT_FAILURE, "expected number of trials");
    n = atoi(argv[1]);
    for (i = 0; i < n; i++) {
        double x = ((double) rand())/RAND_MAX;
        double y = ((double) rand())/RAND_MAX;
        hits += x*x + y*y <= 1.0 ? 1 : 0;
    }
    printf("%f\n", 4*((double) hits)/n);
    return EXIT_SUCCESS;
}

