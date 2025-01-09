build:
	gcc src/main.c -o dist/main src/cli.c src/frontend/lex.c src/frontend/parser.c src/frontend/codegen.c -Wall -Wextra -Werror -std=c11 -pedantic -g

test-lex: build
	./writing-a-c-compiler-tests/test_compiler ./dist/main --chapter 1 --stage lex

test-parser: build
	./writing-a-c-compiler-tests/test_compiler ./dist/main --chapter 1 --stage parse

test-codegen: build
	./writing-a-c-compiler-tests/test_compiler ./dist/main --chapter 1 --stage codegen
