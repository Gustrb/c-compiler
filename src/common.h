#pragma once

#ifndef __COMMON_H__
#define __COMMON_H__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include "error.h"

#define UNUSED(x) (void)(x)
#define TODO(s) do { fprintf(stderr, "TODO: %s\n", s); exit(ERR_NOT_IMPLEMENTED); } while (0);

#endif // __COMMON_H__
