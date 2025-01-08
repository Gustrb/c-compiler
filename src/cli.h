#pragma once
#ifndef __CLI_H__
#define __CLI_H__

#include "common.h"

/*
 * We support the following flags:
 * - --lex: that only performs the lexical analysis(no output)
 * - --parse: that performs the lexical and syntactic analysis(no output)
 * - --codegen: that performs the lexical, syntactic and code generation analysis(no output)
 * - -S: that performs the lexical, syntactic and code generation and assembly emission
*/
typedef enum {
    S_UNPARSED,
    S_UP_TO_LEX,
    S_UP_TO_PARSE,
    S_UP_TO_CODEGEN,
    // TODO: implement -S flag
} cli_flags_state_t;

int32_t cli_parse_flags(int32_t argc, char **argv, cli_flags_state_t *state, char **filename);

#endif // __CLI_H__
