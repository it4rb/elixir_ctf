#include <stdio.h>
#include "lib/lib.h"

const char *password = "sUperS3cr3t";
int check_password(char *pwd)
{
  for (int i = 0; i < 12; i++)
  {
    if (pwd[i] != password[i])
      return 0;
  }
  return 1;
}

int main()
{
  puts("Enter the password to continue");

  char pwd[20];
  gets(pwd, 20);

  if (check_password(pwd))
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
