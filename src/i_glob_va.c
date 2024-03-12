#include "i_glob.h"
#include <stdarg.h>
#include <stddef.h>
#include <stdlib.h>

glob_t *I_StartMultiGlob(const char *directory, int flags,
                         const char *glob, ...)
{
    va_list args;
    size_t count;
    size_t i;
    const char** glob_array;

    va_start(args, glob);
    count = 1;
    while (va_arg(args, const char *) != NULL)
    {
        count++;
    }
    va_end(args);

    glob_array = malloc(count * sizeof(const char *));
    if (glob_array == NULL)
    {
        return NULL;
    }

    va_start(args, glob);
    glob_array[0] = glob;
    for (i = 1; i < count; i++)
    {
        glob_array[i] = va_arg(args, const char *);
    }
    va_end(args);

    glob_t *result = I_StartMultiGlobArray(directory, flags, glob_array, count);
    free(glob_array);
    return result;
}
