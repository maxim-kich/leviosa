#include <stdbool.h>
#include <stdint.h>
typedef void (*LVTouchHandler)(uint64_t, int, int, double, double, double, uint64_t);
bool LVStart(LVTouchHandler handler, uint64_t generation);
void LVStop(void);

bool LVAcquireInstance(const char *path);
