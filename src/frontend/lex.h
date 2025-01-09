#pragma once
#ifndef __LEX_H__
#define __LEX_H__

#include "../common.h"

typedef enum {
    TOK_EOF,
    TOK_COMMENT,

    TOK_IDENTIFIER,
    TOK_CONSTANT,
    TOK_OPEN_PAREN,
    TOK_CLOSE_PAREN,
    TOK_OPEN_BRACE,
    TOK_CLOSE_BRACE,
    TOK_SEMICOLON,

    // Keywords
    TOK_INT_KEYWORD,
    TOK_VOID_KEYWORD,
    TOK_RETURN_KEYWORD,
} token_type_t;

typedef struct {
    uint8_t *start;
    uint8_t *end;

    token_type_t type;
    int32_t line;
    int32_t column;
} token_t;

typedef struct {
    uint8_t *buffer;
    size_t len;

    size_t pos;

    size_t line;
    size_t column;
} lexer_t;

int32_t lex_whole_file(char *buffer, size_t len);
int32_t lex_next_token(lexer_t *lexer, token_t *token);

#endif // __LEX_H__
