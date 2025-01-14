#pragma once

#ifndef __ERROR_H__
#define __ERROR_H__

// Use use this error code to indicate that a feature is not implemented
#define ERR_NOT_IMPLEMENTED     0x01

// Use this error code to indicate that the program was used incorrectly
#define ERR_INVALID_USAGE       0x02

// Use this error code to indicate that an invalid flag was passed
#define ERR_INVALID_FLAG        0x03

// Use this error code to indicate that memory allocation failed
#define ERR_MEMORY_ALLOCATION   0x04

// Use this error code to indicate that a file was not found
#define ERR_FILE_NOT_FOUND      0x05

// Use this error code to indicate that a file could not be read
#define ERR_FAILED_TO_READ_FILE 0x06

// Use this error code to indicate that an unknown token was found
#define ERR_UNKNOWN_TOKEN_FOUND 0x07

// Use this error code to indicate that an invalid syntax was found
#define ERR_INVALID_SYNTAX      0x08

// Use this error code to indicate that an identifier is too long
#define ERR_IDENTIFIER_TOO_LONG 0x09

// Use this error code to indicate that an unsupported mov instruction was found
#define ERR_UNSUPPORTED_MOV_INSTRUCTION 0x0A

// Use this error code to indicate that an output file could not be created
#define ERR_COULD_NOT_CREATE_OUTPUT_FILE 0x0B

// Use this error code to indicate that gcc could not be executed
#define ERR_FAILED_TO_EXECUTE_GCC 0x0C

#endif // __ERROR_H__
