#include "cli.h"

static inline void display_usage(const char *progname)
{
    fprintf(stderr, "Usage: %s <flag> <input-file>\n", progname);
    fprintf(stderr, "Flags:\n");
    fprintf(stderr, "\t--lex: Perform lexical analysis\n");
    fprintf(stderr, "\t--parse: Perform lexical and syntactic analysis\n");
    fprintf(stderr, "\t--codegen: Perform lexical, syntactic and code generation analysis\n");
    fprintf(stderr, "\t-S: Perform lexical, syntactic, code generation and assembly emission\n");
}

char *generate_path_with_suffix(arena_t *arena, const char *path, const char *suffix) {
    size_t len = strlen(path);
    size_t i = len - 1;

    // Find the last occurrence of the '.' character
    while (i > 0 && path[i] != '.') {
        i--;
    }

    // Handle case where '.' is not found
    if (i == 0 && path[i] != '.') {
        return NULL;
    }

    // Allocate memory for the new path
    size_t suffix_len = strlen(suffix);
    char *output_path = arena_alloc(arena, i + 1 + suffix_len + 1);
    if (!output_path) {
        return NULL;
    }

    // Copy the base path and append the suffix
    strncpy(output_path, path, i);
    strcat(output_path, suffix);
    output_path[i + strlen(suffix) + 1] = '\0'; // Null-terminate the base path

    return output_path;
}

char *cli_find_output_path(arena_t *arena, const char *path) {
    return generate_path_with_suffix(arena, path, ".s");
}

char *cli_find_executable_path(arena_t *arena, const char *path) {
    return generate_path_with_suffix(arena, path, "");
}

int32_t cli_parse_flags(int32_t argc, char **argv, cli_flags_state_t *state, char **filename)
{
    if (argc == 2) {
        *state = S_GEN_EXECUTABLE;
        *filename = argv[1];
        return 0;
    }

    if (argc < 3) {
        fprintf(stderr, "[Error]: Invalid number of arguments\n");
        display_usage(argv[0]);
        return ERR_INVALID_USAGE;
    }

    size_t len = strlen(argv[1]);
    if (strncmp(argv[1], "--lex", len) == 0) {
        *state = S_UP_TO_LEX;
    } else if (strncmp(argv[1], "--parse", len) == 0) {
        *state = S_UP_TO_PARSE;
    } else if (strncmp(argv[1], "--codegen", len) == 0) {
        *state = S_UP_TO_CODEGEN;
    } else if (strncmp(argv[1], "-S", len) == 0) {
        *state = S_UP_TO_ASSEMBLY;
    } else {
        fprintf(stderr, "[Error]: Invalid flag\n");
        display_usage(argv[0]);
        return ERR_INVALID_FLAG;
    }

    *filename = argv[2];
    return 0;
}
