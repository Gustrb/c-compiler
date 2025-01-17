build:
	zig build-exe ./src/main.zig

test-lex: build
	./writing-a-c-compiler-tests/test_compiler ./main --chapter 1 --stage lex

test-parser: build
	./writing-a-c-compiler-tests/test_compiler ./main --chapter 1 --stage parse

test-codegen: build
	./writing-a-c-compiler-tests/test_compiler ./main --chapter 1 --stage codegen

test-chapter-1: build
	./writing-a-c-compiler-tests/test_compiler ./main --chapter 1