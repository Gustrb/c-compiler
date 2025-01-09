#include "parser.h"

static int32_t parser_expect(lexer_t *lexer, token_type_t type, token_t *token)
{
    int32_t ret;
    // while it is a comment, we skip it
    while (1) {
        ret = lex_next_token(lexer, token);
        if (ret != 0) {
            return ret;
        }

        if (token->type != TOK_COMMENT) {
            break;
        }
    }

    if (ret != 0) {
        return ret;
    }

    if (token->type != type) {
        printf("[Error]: Expected token type %d, got %d at line %zu, column %zu\n", type, token->type, lexer->line, lexer->column);
        return ERR_UNKNOWN_TOKEN_FOUND;
    }

    return 0;
}

static int32_t parser_parse_integer(lexer_t *lexer, arena_t *arena, expression_t *expression)
{
    token_t token;
    int32_t err;

    constant_t *constant = arena_alloc(arena, sizeof(constant_t));
    if (constant == NULL) {
        fprintf(stderr, "[Error]: Unable to allocate memory\n");
        return ERR_MEMORY_ALLOCATION;
    }

    err = parser_expect(lexer, TOK_CONSTANT, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected constant at line %zu, column %zu\n", lexer->line, lexer->column);
        return err;
    }

    constant->value = 0;
    for (uint8_t *c = token.start; c < token.end; c++) {
        constant->value = constant->value * 10 + (*c - '0');
    }

    expression->constant = constant;
    return 0;
}

static int32_t parser_parse_expression(lexer_t *lexer, arena_t *arena, return_statement_t *return_statement)
{
    int32_t err;

    expression_t *expression = arena_alloc(arena, sizeof(expression_t));
    if (expression == NULL) {
        fprintf(stderr, "[Error]: Unable to allocate memory\n");
        return ERR_MEMORY_ALLOCATION;
    }

    err = parser_parse_integer(lexer, arena, expression);
    if (err != 0) {
        fprintf(stderr, "[Error]: Failed to parse integer at line %zu, column %zu\n", lexer->line, lexer->column);
        return err;
    }

    return_statement->expression = expression;
    return 0;
}

static int32_t parser_parse_return_statement(lexer_t *lexer, arena_t *arena, statement_t *statement)
{
    token_t token;
    int32_t err;

    return_statement_t *return_statement = arena_alloc(arena, sizeof(return_statement_t));
    if (return_statement == NULL) {
        fprintf(stderr, "[Error]: Unable to allocate memory\n");
        return ERR_MEMORY_ALLOCATION;
    }

    err = parser_expect(lexer, TOK_RETURN_KEYWORD, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected 'return' keyword at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    err = parser_parse_expression(lexer, arena, return_statement);
    if (err != 0) {
        return err;
    }

    err = parser_expect(lexer, TOK_SEMICOLON, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected ';' at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    statement->return_statement = return_statement;
    return 0;
}

static int32_t parser_parse_statement(lexer_t *lexer, arena_t *arena, function_definition_t *function)
{
    int32_t err;

    statement_t *statement = arena_alloc(arena, sizeof(statement_t));
    if (statement == NULL) {
        fprintf(stderr, "[Error]: Unable to allocate memory\n");
        return ERR_MEMORY_ALLOCATION;
    }

    err = parser_parse_return_statement(lexer, arena, statement);
    if (err != 0) {
        return err;
    }

    function->statement = statement;
    return 0;
}

static int32_t parser_parse_function(lexer_t *lexer, arena_t *arena, program_t *program)
{
    token_t token;
    int32_t err;

    function_definition_t *function = arena_alloc(arena, sizeof(function_definition_t));
    if (function == NULL) {
        fprintf(stderr, "[Error]: Unable to allocate memory\n");
        return ERR_MEMORY_ALLOCATION;
    }

    err = parser_expect(lexer, TOK_INT_KEYWORD, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected 'int' keyword at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    err = parser_expect(lexer, TOK_IDENTIFIER, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected identifier at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    function->start = (char *)token.start;
    function->end = (char *)token.end;

    err = parser_expect(lexer, TOK_OPEN_PAREN, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected '(' at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    err = parser_expect(lexer, TOK_VOID_KEYWORD, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected 'void' keyword at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    err = parser_expect(lexer, TOK_CLOSE_PAREN, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected ')' at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    err = parser_expect(lexer, TOK_OPEN_BRACE, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected '{' at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    err = parser_parse_statement(lexer, arena, function);
    if (err != 0) {
        return err;
    }

    err = parser_expect(lexer, TOK_CLOSE_BRACE, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected '}' at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    program->function = function;

    err = parser_expect(lexer, TOK_EOF, &token);
    if (err != 0) {
        fprintf(stderr, "[Error]: Expected EOF at line %zu, column %zu\n", lexer->line, lexer->column);
        return ERR_INVALID_SYNTAX;
    }

    return 0;
}

int32_t parser_parse_whole_file(arena_t *arena, char *buffer, size_t len, program_t *program)
{
    lexer_t l = {
        .buffer = (uint8_t *)buffer,
        .len = len,
        .pos = 0,
        .line = 1,
        .column = 1,
    };

    program = arena_alloc(arena, sizeof(program_t));
    if (program == NULL) {
        fprintf(stderr, "[Error]: Unable to allocate memory\n");
        return ERR_MEMORY_ALLOCATION;
    }

    int32_t err;
    err = parser_parse_function(&l, arena, program);
    if (err != 0) {
        return err;
    }

    return err;
}
