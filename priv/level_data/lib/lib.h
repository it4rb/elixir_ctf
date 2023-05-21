#ifndef _LIB_H_
#define _LIB_H_

void gets(char *buf, unsigned int length);

void unlock_door();

int check_password_hsm1(char *pwd);

int check_password_hsm2(char *pwd);

#endif
