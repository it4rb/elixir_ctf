
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
