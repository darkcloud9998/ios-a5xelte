/* hero-sysctl NAME [VALUE]: reads or writes an integer sysctl (iOS has no sysctl command here). */
#include <stdio.h>
#include <stdlib.h>
#include <sys/sysctl.h>

int
main(int argc, char **argv)
{
	if (argc != 2 && argc != 3) {
		fprintf(stderr, "usage: hero-sysctl NAME [VALUE]\n");
		return 2;
	}
	int old = 0, new = argc == 3 ? atoi(argv[2]) : 0;
	size_t len = sizeof(old);
	if (sysctlbyname(argv[1], &old, &len, argc == 3 ? &new : NULL, argc == 3 ? sizeof(new) : 0) != 0) {
		perror(argv[1]);
		return 1;
	}
	if (argc == 3) {
		printf("%s: %d -> %d\n", argv[1], old, new);
	} else {
		printf("%d\n", old);
	}
	return 0;
}
