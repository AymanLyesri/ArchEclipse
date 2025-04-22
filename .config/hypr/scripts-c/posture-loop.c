#include <stdlib.h>
#include <unistd.h>
#include <time.h>

int main()
{
    do
    {
        system("notify-send -u low 'Fix your posture' ' Sit up straight!'");
        sleep(3600); // 30 minutes
    } while (1);

    return 0;
}