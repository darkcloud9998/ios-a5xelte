/*
 * hero-images PID: the Mach-O images a running process has loaded (load address and path), read from its dyld's image
 * list. With a crash's addresses from the kernel log it says which library each one is in. Reads only.
 */
#include <mach/mach.h>
#include <mach-o/dyld_images.h>
#include <stdio.h>
#include <stdlib.h>

extern kern_return_t mach_vm_read_overwrite(vm_map_t, uint64_t, uint64_t, uint64_t, uint64_t *);

static int
peek(task_t task, uint64_t from, void *to, uint64_t len)
{
	uint64_t got = 0;
	return mach_vm_read_overwrite(task, from, len, (uint64_t)(uintptr_t)to, &got) == KERN_SUCCESS && got == len;
}

int
main(int argc, char **argv)
{
	if (argc != 2) {
		fprintf(stderr, "usage: hero-images PID\n");
		return 2;
	}
	task_t task = MACH_PORT_NULL;
	kern_return_t kr = task_for_pid(mach_task_self(), atoi(argv[1]), &task);
	if (kr != KERN_SUCCESS) {
		fprintf(stderr, "task_for_pid: %s\n", mach_error_string(kr));
		return 1;
	}
	struct task_dyld_info info;
	mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
	kr = task_info(task, TASK_DYLD_INFO, (task_info_t)&info, &count);
	if (kr != KERN_SUCCESS) {
		fprintf(stderr, "task_info: %s\n", mach_error_string(kr));
		return 1;
	}
	struct dyld_all_image_infos all;
	if (!peek(task, info.all_image_info_addr, &all, sizeof(all))) {
		fprintf(stderr, "cannot read dyld's image list\n");
		return 1;
	}
	printf("shared cache slide 0x%lx, %u images\n", (unsigned long)all.sharedCacheSlide, all.infoArrayCount);
	for (uint32_t i = 0; i < all.infoArrayCount && i < 4096; i++) {
		struct dyld_image_info one;
		char path[512] = "";
		if (!peek(task, (uint64_t)(uintptr_t)all.infoArray + i * sizeof(one), &one, sizeof(one))) {
			break;
		}
		/* a path near the end of a mapping cannot be read whole: shorter reads until one fits */
		for (uint64_t len = sizeof(path) - 1; len >= 16; len /= 2) {
			if (peek(task, (uint64_t)(uintptr_t)one.imageFilePath, path, len)) {
				path[len] = 0;
				break;
			}
		}
		printf("0x%llx %s\n", (unsigned long long)(uintptr_t)one.imageLoadAddress, path);
	}
	return 0;
}
