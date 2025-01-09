#pragma once

#ifndef __X86_64_H__
#define __X86_64_H__

#include "../common.h"
#include "../frontend/codegen.h"

int32_t x86_64_codegen(arena_t *arena, char *buf, size_t size, const char *output_path);

#endif
