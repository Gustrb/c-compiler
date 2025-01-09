#include "codegen.h"

#ifdef DEBUG
static void debug_instruction_queue(codegen_instruction_queue_t *queue)
{
    for (size_t i = 0; i < queue->count; i++) {
        codegen_instruction_t instruction = queue->instructions[i];
        switch (instruction.tag) {
            case I_MOV: {
                codegen_mov_instruction_t *mov_instruction = (codegen_mov_instruction_t *)instruction.data;
                printf("MOV %d -> %d\n", mov_instruction->source.immediate, mov_instruction->destination.immediate);
            } break;
            case I_RET: {
                printf("RET\n");
            } break;
        }
    }
}
#endif

static int32_t codegen_push_instruction(arena_t *arena, codegen_instruction_queue_t *queue, codegen_instruction_t instruction)
{
    if (queue->count == queue->capacity) {
        queue->capacity = queue->capacity * 2 + 1;
        queue->instructions = arena_realloc(arena, queue->instructions, queue->capacity * sizeof(codegen_instruction_t));
        if (!queue->instructions) {
            fprintf(stderr, "[Error]: Unable to allocate memory\n");
            return ERR_MEMORY_ALLOCATION;
        }
    }

    queue->instructions[queue->count++] = instruction;
    return 0;
}

static int32_t codegen_emit_mov_instruction(arena_t *arena, codegen_instruction_queue_t *queue, codegen_operand_t source, codegen_operand_t destination)
{
    codegen_instruction_t instruction = {
        .tag = I_MOV,
        .data = arena_alloc(arena, sizeof(codegen_mov_instruction_t)),
    };

    if (!instruction.data) {
        fprintf(stderr, "[Error]: Unable to allocate memory\n");
        return ERR_MEMORY_ALLOCATION;
    }

    codegen_mov_instruction_t *mov_instruction = (codegen_mov_instruction_t *)instruction.data;
    mov_instruction->source = source;
    mov_instruction->destination = destination;

    return codegen_push_instruction(arena, queue, instruction);
}

static int32_t codegen_emit_return_instruction(arena_t *arena, codegen_instruction_queue_t *queue)
{
    codegen_instruction_t instruction = {
        .tag = I_RET,
    };

    return codegen_push_instruction(arena, queue, instruction);
}

static int32_t codegen_constant(arena_t *arena, constant_t *constant, codegen_instruction_queue_t *instructions)
{
    codegen_operand_t src = {
        .tag = O_IMMEDIATE,
        .immediate = constant->value,
    };

    codegen_operand_t dest = {
        .tag = O_REGISTER,
        .register_id = R_EAX,
    };

    return codegen_emit_mov_instruction(arena, instructions, src, dest);
}

static int32_t codegen_expression(arena_t *arena, expression_t *expression, codegen_instruction_queue_t *instructions)
{
    int32_t err = codegen_constant(arena, expression->constant, instructions);
    return err;
}

static int32_t codegen_statement(arena_t *arena, statement_t *statement, codegen_instruction_queue_t *instructions)
{
    int32_t err = codegen_expression(arena, statement->return_statement->expression, instructions);
    if (err) {
        return err;
    }

    return codegen_emit_return_instruction(arena, instructions);
}

static int32_t codegen_function_definition(arena_t *arena, function_definition_t *function, codegen_function_definition_t *codegen_function)
{
    codegen_instruction_queue_t instructions = {
        .count = 0,
        .capacity = 0,
        .instructions = NULL,
    };

    memcpy(codegen_function->identifier, function->identifier, strlen(function->identifier) + 1);

    codegen_function->instructions = instructions;

    return codegen_statement(arena, function->statement, &codegen_function->instructions);
}

int32_t codegen_whole_program(arena_t *arena, char *buffer, size_t size, codegen_program_t *program)
{
    program_t p = {0};
    int32_t err = parser_parse_whole_file(arena, buffer, size, &p);
    if (err) {
        return err;
    }

    err = codegen_function_definition(arena, p.function, &program->function);

    if (err) {
        return err;
    }

    return err;
}
