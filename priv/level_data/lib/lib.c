
#include "lib.h"

void __attribute__((section("int_section"), optimize("O1"))) INT(int arg, ...)
{
  asm("");
}

void __attribute__((optimize("O1"))) gets(char *buf, unsigned int length)
{
  INT(2, buf, length);
}

int __attribute__((optimize("O1"))) putchar(int c)
{
  INT(0, c);
  return c;
}

void __attribute__((optimize("O1"))) unlock_door()
{
  INT(0x7f);
}

int __attribute__((optimize("O1"))) check_password_hsm1(char *pwd)
{
  int flag = 0;
  INT(0x7d, pwd, &flag);
  return flag;
}

int __attribute__((optimize("O1"))) check_password_hsm2(char *pwd)
{
  int flag = 0;
  INT(0x7e, pwd, &flag);
  return flag;
}
