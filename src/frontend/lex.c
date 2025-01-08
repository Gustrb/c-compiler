#include "lex.h"

#define IS_SPACE(c) ((c) == ' ' || (c) == '\t' || (c) == '\n' || (c) == '\r')
#define IS_NUMERIC(c) ((c) >= '0' && (c) <= '9')
#define IS_ALPHA(c) (((c) >= 'a' && (c) <= 'z') || ((c) >= 'A' && (c) <= 'Z'))

static void lexer_advance(lexer_t *lexer)
{
    if (lexer->pos >= lexer->len) {
        return;
    }

    if (lexer->buffer[lexer->pos] == '\n') {
        lexer->line++;
        lexer->column = 0;
    } else {
        lexer->column++;
    }

    lexer->pos++;
}

// TODO: This is VERY naive and inefficient, in the future add a trie to match keywords
//       it could be metaprogrammed to ganarate a nesting of if-else statements(since there aren't that many keywords)
//       look at keyword matching from crafting interpreters book for inspiration: https://craftinginterpreters.com/scanning-on-demand.html#tries-and-state-machines
static token_type_t lex_findout_if_it_is_keyword(uint8_t *start, uint8_t *end)
{
    size_t len = end - start;
    if (len == 3 && memcmp(start, "int", 3) == 0) {
        return TOK_INT_KEYWORD;
    }

    if (len == 4 && memcmp(start, "void", 4) == 0) {
        return TOK_VOID_KEYWORD;
    }

    if (len == 6 && memcmp(start, "return", 6) == 0) {
        return TOK_RETURN_KEYWORD;
    }

    return TOK_IDENTIFIER;
}

int32_t lex_next_token(lexer_t *lexer, token_t *token)
{
    while (lexer->pos < lexer->len && IS_SPACE(lexer->buffer[lexer->pos])) {
        lexer_advance(lexer);
    }

    // There are two types of comments in C:
    // 1. Single line comments: //
    // 2. Multi line comments: /* */
    if (lexer->pos + 1 < lexer->len && lexer->buffer[lexer->pos] == '/' && lexer->buffer[lexer->pos + 1] == '/') {
        token->type = TOK_COMMENT;
        token->line = lexer->line;
        token->column = lexer->column;
        token->start = &lexer->buffer[lexer->pos];

        while (lexer->pos < lexer->len && lexer->buffer[lexer->pos] != '\n') {
            lexer_advance(lexer);
        }

        token->end = &lexer->buffer[lexer->pos];
        return 0;
    }

    if (lexer->pos + 1 < lexer->len && lexer->buffer[lexer->pos] == '/' && lexer->buffer[lexer->pos + 1] == '*') {
        token->type = TOK_COMMENT;
        token->line = lexer->line;
        token->column = lexer->column;
        token->start = &lexer->buffer[lexer->pos];

        while (lexer->pos < lexer->len && (lexer->buffer[lexer->pos] != '*' || lexer->buffer[lexer->pos + 1] != '/')) {
            lexer_advance(lexer);
        }

        if (lexer->pos >= lexer->len) {
            fprintf(stderr, "[Error]: Unterminated multi-line comment at line %zu, column %zu\n", lexer->line, lexer->column);
            return ERR_UNKNOWN_TOKEN_FOUND;
        }
        lexer_advance(lexer);
        lexer_advance(lexer);
        token->end = &lexer->buffer[lexer->pos];
        return 0;
    }

    if (lexer->pos >= lexer->len) {
        token->type = TOK_EOF;
        return 0;
    }

    switch (lexer->buffer[lexer->pos]) {
        case '(': {
            token->type = TOK_OPEN_PAREN;
            lexer_advance(lexer);
            return 0;
        };
        case ')': {
            token->type = TOK_CLOSE_PAREN;
            lexer_advance(lexer);
            return 0;
        };
        case '{': {
            token->type = TOK_OPEN_BRACE;
            lexer_advance(lexer);
            return 0;
        };
        case '}': {
            token->type = TOK_CLOSE_BRACE;
            lexer_advance(lexer);
            return 0;
        };
        case ';': {
            token->type = TOK_SEMICOLON;
            lexer_advance(lexer);
            return 0;
        };
    }

    if (IS_NUMERIC(lexer->buffer[lexer->pos])) {
        token->type = TOK_CONSTANT;
        token->start = &lexer->buffer[lexer->pos];
        token->line = lexer->line;
        token->column = lexer->column;

        while (lexer->pos < lexer->len && IS_NUMERIC(lexer->buffer[lexer->pos])) {
            lexer_advance(lexer);
        }

        if (lexer->pos < lexer->len && IS_ALPHA(lexer->buffer[lexer->pos])) {
            fprintf(stderr, "[Error]: Invalid constant at line %zu, column %zu: '%.*s'\n", lexer->line, lexer->column, (int)(lexer->pos - (size_t)token->start), token->start);
            return ERR_UNKNOWN_TOKEN_FOUND;
        }

        token->end = &lexer->buffer[lexer->pos];
        return 0;
    }

    if (IS_ALPHA(lexer->buffer[lexer->pos])) {
        token->start = &lexer->buffer[lexer->pos];
        token->line = lexer->line;
        token->column = lexer->column;

        while (lexer->pos < lexer->len && (IS_ALPHA(lexer->buffer[lexer->pos]) || IS_NUMERIC(lexer->buffer[lexer->pos]) || lexer->buffer[lexer->pos] == '_')) {
            lexer_advance(lexer);
        }
        token->end = &lexer->buffer[lexer->pos];

        token->type = lex_findout_if_it_is_keyword(token->start, token->end);
        return 0;
    }

    // If we reach here, we have an unknown token
    fprintf(stderr, "[Error]: Unknown token at line %zu, column %zu: '%c'\n", lexer->line, lexer->column, lexer->buffer[lexer->pos]);
    lexer_advance(lexer);
    return ERR_UNKNOWN_TOKEN_FOUND;
}

int32_t lex_whole_file(char *buffer, size_t len)
{
    lexer_t l = {
        .buffer = (uint8_t *)buffer,
        .len = len,
        .pos = 0,
        .line = 1,
        .column = 1,
    };

    token_t token;
    int32_t err;
    while (1) {
        err = lex_next_token(&l, &token);
        if (err || token.type == TOK_EOF) {
            break;
        }
    }

    return err;
}
