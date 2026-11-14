// Private ABI, isolated from application logic. No event suppression.
#include "Trackpad.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>
typedef struct {float x,y;} P;
typedef struct {P position,velocity;} V;
typedef struct {int frame; double time; int identifier,state,finger,hand; V normalized; float size; int unused; float angle,major,minor; V absolute; int u2,u3; float density;} Touch;
typedef int (*Callback)(void*,Touch*,int,double,int);
static void *lib; static CFArrayRef devices; static LVTouchHandler client;
static uint64_t epoch; static pthread_mutex_t clientLock=PTHREAD_MUTEX_INITIALIZER;
static void (*reg)(void*,Callback),(*unreg)(void*,Callback),(*start)(void*,int),(*stop)(void*);
static int frame(void *dev,Touch *t,int count,double time,int number){
 if(count<0 || count>64)return 0;
 int n=0,id=0; double x=0,y=0;
 for(int i=0;i<count;i++) if(t[i].state==3 || t[i].state==4){n++;id=t[i].identifier;x=t[i].normalized.position.x;y=t[i].normalized.position.y;}
 pthread_mutex_lock(&clientLock); LVTouchHandler callback=client; uint64_t generation=epoch; pthread_mutex_unlock(&clientLock);
 if(callback)callback((uint64_t)(uintptr_t)dev,n,id,x,y,time,generation); return 0;
}
bool LVStart(LVTouchHandler handler,uint64_t generation){
 if(devices)return true;
 lib=dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",RTLD_NOW|RTLD_LOCAL); if(!lib)return false;
 CFArrayRef (*list)(void)=dlsym(lib,"MTDeviceCreateList");
 reg=dlsym(lib,"MTRegisterContactFrameCallback");unreg=dlsym(lib,"MTUnregisterContactFrameCallback");start=dlsym(lib,"MTDeviceStart");stop=dlsym(lib,"MTDeviceStop");
 if(!list||!reg||!unreg||!start||!stop)return false;
 devices=list();if(!devices||CFArrayGetCount(devices)==0){if(devices)CFRelease(devices);devices=0;return false;}
 pthread_mutex_lock(&clientLock);client=handler;epoch=generation;pthread_mutex_unlock(&clientLock);
 for(CFIndex i=0;i<CFArrayGetCount(devices);i++){void *d=(void*)CFArrayGetValueAtIndex(devices,i);reg(d,frame);start(d,0);}return true;
}
void LVStop(void){pthread_mutex_lock(&clientLock);client=0;epoch++;pthread_mutex_unlock(&clientLock);if(devices){for(CFIndex i=0;i<CFArrayGetCount(devices);i++){void *d=(void*)CFArrayGetValueAtIndex(devices,i);unreg(d,frame);stop(d);}CFRelease(devices);devices=0;}}

// Kernel-owned lock: released automatically on process exit, including crashes.
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
bool LVAcquireInstance(const char *path){
 static int instanceFD=-1;
 instanceFD=open(path,O_CREAT|O_RDWR,0600);
 if(instanceFD<0)return false;
 if(flock(instanceFD,LOCK_EX|LOCK_NB)!=0){close(instanceFD);instanceFD=-1;return false;}
 return true;
}
