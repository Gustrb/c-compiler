#pragma once
#ifndef __PARSER_H__
#define __PARSER_H__

#include "../common.h"
#include "lex.h"

typedef struct {
    int value;
} constant_t;

typedef struct {
    constant_t *constant;
} expression_t;

typedef struct {
    expression_t *expression;
} return_statement_t;

typedef struct {
    return_statement_t *return_statement;
} statement_t;

typedef struct {
    char identifier[256];
    statement_t *statement;
} function_definition_t;

typedef struct {
    function_definition_t *function;
} program_t;

int32_t parser_parse_whole_file(arena_t *, char *, size_t, program_t *);

#endif // __PARSER_H__
