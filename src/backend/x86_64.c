#include "x86_64.h"

static const char *x86_64_register_names[] = {
    [R_EAX] = "eax",
};

static int32_t x86_64_emit_ret(FILE *out)
{
    fprintf(out, "\tret\n");
    return 0;
}

static int32_t x86_64_emit_mov(codegen_mov_instruction_t *mov, FILE *out)
{
    if (mov->source.tag == O_IMMEDIATE && mov->destination.tag == O_REGISTER) {
        fprintf(out, "\tmovl $%d, %%%s\n", mov->source.immediate, x86_64_register_names[mov->destination.register_id]);
    } else {
        fprintf(stderr, "[Error]: Unsupported mov instruction\n");
        return ERR_UNSUPPORTED_MOV_INSTRUCTION;
    }

    return 0;
}

static int32_t x86_64_emit_instruction_queue(codegen_instruction_queue_t queue, FILE *out)
{ 
    for (size_t i = 0; i < queue.count; i++) {
        codegen_instruction_t instruction = queue.instructions[i];
        int32_t err = 0;
        switch (instruction.tag) {
            case I_RET: {
                err = x86_64_emit_ret(out);
                break;
            };
            case I_MOV: {
                codegen_mov_instruction_t *mov = (codegen_mov_instruction_t *) instruction.data;
                err = x86_64_emit_mov(mov, out);
                break;
            };
        }

        if (err) {
            return err;
        }
    }

    return 0;
}

static int32_t x86_64_emit_function(codegen_function_definition_t function, FILE *out)
{
    // Emit label, in macOS, the label should start with an underscore
#ifdef __APPLE__
    fprintf(out, ".globl _%s\n", function.identifier);
    fprintf(out, "_%s:\n", function.identifier);
#else
    fprintf(out, ".globl %s\n", function.identifier);
    fprintf(out, "%s:\n", function.identifier);
#endif

    int32_t err = x86_64_emit_instruction_queue(function.instructions, out);
    if (err) {
        return err;
    }

// on linux we must add .section .note.GNU-stack,"",@progbits to avoid stack execution
#ifdef __linux__
    fprintf(out, ".section .note.GNU-stack,\"\",@progbits\n");
#endif

    return 0;
}

int32_t x86_64_codegen(arena_t *arena, char *buf, size_t size, const char *output_path)
{
    codegen_program_t program = {0};
    int32_t err = codegen_whole_program(arena, buf, size, &program);

    if (err) {
        return err;
    }

    FILE *out = fopen(output_path, "w");
    if (!out) {
        fprintf(stderr, "[Error]: Could not create output file\n");
        return ERR_COULD_NOT_CREATE_OUTPUT_FILE;
    }

    err = x86_64_emit_function(program.function, out);
    fclose(out);

    return 0;
}
