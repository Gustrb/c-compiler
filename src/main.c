#define TOOLBOX_IMPLEMENTATION
#include "common.h"
#include "cli.h"
#include "frontend/lex.h"
#include "frontend/parser.h"
#include "frontend/codegen.h"
#include "backend/x86_64.h"

int32_t io_load_file_into_memory(const char *filename, char **buffer, size_t *size)
{
    assert(filename != NULL);
    assert(buffer != NULL);
    assert(size != NULL);

    FILE *file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "[Error]: Unable to open file %s\n", filename);
        return ERR_FILE_NOT_FOUND;
    }

    // Technically those can fail, but im not going to check it
    // TODO: Check if those fail and return appropriate error
    fseek(file, 0, SEEK_END);
    *size = ftell(file);
    rewind(file);

    *buffer = (char *)malloc(*size + 1);
    if (!*buffer) {
        fprintf(stderr, "[Error]: Unable to allocate memory\n");
        fclose(file);
        return ERR_MEMORY_ALLOCATION;
    }

    size_t read = fread(*buffer, 1, *size, file);
    if (read != *size) {
        fprintf(stderr, "[Error]: Unable to read file %s\n", filename);
        fclose(file);
        free(*buffer);
        return ERR_FAILED_TO_READ_FILE;
    }

    (*buffer)[*size] = '\0';
    fclose(file);
    return 0;
}

int32_t assemble_and_link(arena_t *arena, char *path)
{
    char *output_path = cli_find_executable_path(arena, path);
    if (!output_path) {
        return ERR_MEMORY_ALLOCATION;
    }

    char *args[] = {
        "gcc",
        "-o",
        output_path,
        path,
        NULL,
    };

    int32_t err = execvp("gcc", args);
    if (err) {
        fprintf(stderr, "[Error]: Unable to execute gcc\n");
        return ERR_FAILED_TO_EXECUTE_GCC;
    }

    return 0;
}

int32_t main(int32_t argc, char **argv)
{
    cli_flags_state_t state;
    char *filename;
    int32_t err = cli_parse_flags(argc, argv, &state, &filename);
    if (err) return err;

    char *buffer = NULL;
    size_t size = 0;
    err = io_load_file_into_memory(filename, &buffer, &size);
    if (err) return err;


    if (state == S_UP_TO_LEX) {
        err = lex_whole_file(buffer, size);

        if (err) {
            fprintf(stderr, "[Error]: Lexical analysis failed\n");
            goto cleanup;
        }
    } else if (state == S_UP_TO_PARSE) {
        arena_t arena = arena_new();
        if (arena_new_failed(&arena)) {
            fprintf(stderr, "[Error]: Unable to allocate memory\n");
            err = ERR_MEMORY_ALLOCATION;
            goto cleanup;        
        }

        program_t p = {0};
        err = parser_parse_whole_file(&arena, buffer, size, &p);
        arena_delete(&arena);
        if (err) {
            fprintf(stderr, "[Error]: Syntactic analysis failed\n");
            goto cleanup;
        }
    } else if (state == S_UP_TO_CODEGEN) {
        arena_t arena = arena_new();
        if (arena_new_failed(&arena)) {
            fprintf(stderr, "[Error]: Unable to allocate memory\n");
            err = ERR_MEMORY_ALLOCATION;
            goto cleanup;        
        }

        codegen_program_t p = {0};
        err = codegen_whole_program(&arena, buffer, size, &p);
        arena_delete(&arena);
        if (err) {
            fprintf(stderr, "[Error]: Code generation failed\n");
            goto cleanup;
        } else {
            fprintf(stderr, "[Info]: Code generation successful\n");
        }
    } else if (state == S_UP_TO_ASSEMBLY) {
        arena_t arena = arena_new();
        if (arena_new_failed(&arena)) {
            fprintf(stderr, "[Error]: Unable to allocate memory\n");
            err = ERR_MEMORY_ALLOCATION;
            goto cleanup;        
        }

        char *path = cli_find_output_path(&arena, filename);
        if (!path) {
            fprintf(stderr, "[Error]: Unable to allocate memory\n");
            err = ERR_MEMORY_ALLOCATION;
            goto cleanup;
        }

        err = x86_64_codegen(&arena, buffer, size, path);
        arena_delete(&arena);
        if (err) {
            fprintf(stderr, "[Error]: Code generation failed\n");
            goto cleanup;
        } else {
            fprintf(stderr, "[Info]: Code generation successful\n");
        }
    } else if (state == S_GEN_EXECUTABLE) {
        arena_t arena = arena_new();
        if (arena_new_failed(&arena)) {
            fprintf(stderr, "[Error]: Unable to allocate memory\n");
            err = ERR_MEMORY_ALLOCATION;
            goto cleanup;        
        }

        char *path = cli_find_output_path(&arena, filename);
        if (!path) {
            fprintf(stderr, "[Error]: Unable to allocate memory\n");
            err = ERR_MEMORY_ALLOCATION;
            goto cleanup;
        }

        err = x86_64_codegen(&arena, buffer, size, path);
        if (err) {
            goto cleanup;
        }

        err = assemble_and_link(&arena, path);
        arena_delete(&arena);

        if (err) {
            goto cleanup;
        }

        fprintf(stderr, "[Info]: Executable generated successfully\n");
    }

cleanup:
    free(buffer);

    return err;
}
