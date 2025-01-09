#pragma once
#ifndef __CODEGEN_H__
#define __CODEGEN_H__

#include "../common.h"
#include "parser.h"

#define R_EAX 0

typedef struct {
    enum {
        O_REGISTER,
        O_IMMEDIATE,
    } tag;
    union {
        int32_t register_id;
        int32_t immediate;
    };
} codegen_operand_t;

typedef struct {
    codegen_operand_t source;
    codegen_operand_t destination;
} codegen_mov_instruction_t;

typedef struct {
    void *data;
    enum {
        I_MOV,
        I_RET,
    } tag;
} codegen_instruction_t;

typedef struct {
    codegen_instruction_t *instructions;
    size_t count;
    size_t capacity;
} codegen_instruction_queue_t;

typedef struct {
    char identifier[256];
    codegen_instruction_queue_t instructions;
} codegen_function_definition_t;

typedef struct {
    codegen_function_definition_t function;
} codegen_program_t;

int32_t codegen_whole_program(arena_t *, char *, size_t, codegen_program_t *);

#endif // __CODEGEN_H__
