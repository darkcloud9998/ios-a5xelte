/*
 * hero-twrp: syncs the disks and halts iOS; with the kernel's default herohalt=1 the phone then restarts into TWRP,
 * from where the PC boots it again (adb reboot). A restart straight into iOS would leave the touch screen without power
 * on this port, so there is no such option.
 */
#include <stdio.h>
#include <unistd.h>

extern int reboot(int);         /* the iPhoneOS SDK has no <sys/reboot.h> */
#define RB_HALT 0x08

int
main(void)
{
	sync();
	puts("halting: the phone restarts into TWRP in about 12 s");
	fflush(stdout);
	sleep(2);
	if (reboot(RB_HALT) != 0) {
		perror("reboot");
		return 1;
	}
	return 0;
}
