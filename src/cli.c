#include "cli.h"

static inline void display_usage(const char *progname)
{
    fprintf(stderr, "Usage: %s <flag> <input-file>\n", progname);
    fprintf(stderr, "Flags:\n");
    fprintf(stderr, "\t--lex: Perform lexical analysis\n");
    fprintf(stderr, "\t--parse: Perform lexical and syntactic analysis\n");
    fprintf(stderr, "\t--codegen: Perform lexical, syntactic and code generation analysis\n");
}

int32_t cli_parse_flags(int32_t argc, char **argv, cli_flags_state_t *state, char **filename)
{
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
    } else {
        fprintf(stderr, "[Error]: Invalid flag\n");
        display_usage(argv[0]);
        return ERR_INVALID_FLAG;
    }

    *filename = argv[2];
    return 0;
}
