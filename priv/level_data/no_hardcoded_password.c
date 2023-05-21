#include <stdio.h>
#include "lib/lib.h"

int __attribute__((optimize("O1"))) check_password(const unsigned char *pwd)
{
  // pass length=4 and first char=a and checksum=f5
  return (pwd[5] == 0 && pwd[0] == 'a' && (pwd[0] ^ pwd[1] ^ pwd[2] ^ pwd[3]) == 0xf5);
}

int main()
{
  puts("Enter the password to continue");

  char pwd[20];
  gets(pwd, 20);

  if (check_password((unsigned char *)pwd))
  {
    unlock_door();
    puts("Access Granted!");
  }
  else
  {
    puts("Invalid password; try again");
  }

  return 0;
}
