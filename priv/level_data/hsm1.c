#include <stdio.h>
#include "lib/lib.h"

void login()
{
  puts("Enter the password to continue");

  char pwd[10];
  gets(pwd, 20);

  if (check_password_hsm1(pwd))
  {
    unlock_door();
    puts("Access Granted!");
  }
  else
  {
    puts("Invalid password; try again");
  }
}

int main()
{
  login();
  return 0;
}
