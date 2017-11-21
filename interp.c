#include "stdio.h"
#include "stdlib.h"
#include "stdint.h"
#include "string.h"

#define STMT_START do 
#define STMT_END while (0)

#define TRACING 0
#define DEBUGGING 0

#if TRACING
#    define TRACE(...) fprintf(stderr, __VA_ARGS__)
#else
#    define TRACE(...)
#endif

int
read_file(const char *filename, char **buffer, size_t *len)
{
    FILE *f;
    f = fopen(filename, "rb");
    if (f == NULL) {
        fprintf(stderr, "Can't open input file '%s'!\n", filename);
        exit(1);
    }

    fseek(f, 0, SEEK_END);
    ssize_t length = ftell(f);
    fseek(f, 0, SEEK_SET);
    *buffer = malloc(length);
    if (!*buffer)
        return 1;

    if (fread(*buffer, 1, length, f) == -1) {
        free(*buffer);
        return 1;
    }
    fclose(f);

    *len = (size_t)length;
    return 0;
}

typedef struct interpreter_state {
    const uint8_t *bytecode;
    size_t code_length;
    const char *error;
    int return_status;
    int32_t return_value;
} interpreter_state_t;

void
reset_interpreter(interpreter_state_t *interp)
{
    memset(interp, 0, sizeof(interpreter_state_t));
}

interpreter_state_t *
make_interpreter()
{
    interpreter_state_t *interp = (interpreter_state_t *)malloc(sizeof(interpreter_state_t));
    reset_interpreter(interp);
    return interp;
}

typedef enum interpreter_command {
    IC_PADDING = 0,
    IC_ADDCONST,
    IC_ADDREL,
    IC_SUBCONST,
    IC_SUBREL,
    IC_MOVCONST,
    IC_MOVREL,
    IC_JUMP,
    IC_JUMPZ,
    IC_PRINT,
    IC_EXIT
} interpreter_command_t;

static inline int32_t
read_32bit_int(const uint8_t *data)
{
    return ((int32_t)data[0]) | ((int32_t)data[1] << 8) | ((int32_t)data[2] << 16) | ((int32_t)data[3] << 24);
}
// Assumes little endian:
#define READ_INT(out, bytecode, pos) STMT_START {out = *(int32_t *)(bytecode+pos); pos += 4; } STMT_END
//#define READ_INT(out, bytecode, pos) STMT_START {out = read_32bit_int(bytecode+pos); pos += 4; } STMT_END

static inline uint32_t
read_32bit_uint(const uint8_t *data)
{
    return ((uint32_t)data[0]) | ((uint32_t)data[1] << 8) | ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
}
// Assumes little endian:
#define READ_UINT(out, bytecode, pos) STMT_START {out = *(uint32_t *)(bytecode+pos); pos += 4; } STMT_END
//#define READ_UINT(out, bytecode, pos) STMT_START {out = read_32bit_uint(bytecode+pos); pos += 4; } STMT_END

void
execute(interpreter_state_t *interp)
{
    const uint8_t *bytecode = interp->bytecode;

    uint32_t srcptr;
    uint32_t dstptr;
    int32_t data;

    /* First read memory size */
    size_t ipos = 0;
    const uint32_t memsize = read_32bit_uint(bytecode);
    ipos += 4;

    const uint32_t program_start_offset = ipos;

    uint32_t *memory = (uint32_t *)calloc(memsize, sizeof(uint32_t));
    if (memory == 0) {
        interp->error = "malloc failed";
        return;
    }

    // todo consider registers?
    static void* dispatch_table[20] = {
        &&ic_padding, &&ic_addconst, &&ic_addrel, &&ic_subconst, &&ic_subrel,
        &&ic_movconst, &&ic_movrel, &&ic_jump, &&ic_jumpz, &&ic_print, &&ic_exit
    };

    #define DISPATCH() goto *dispatch_table[bytecode[ipos++]]

    DISPATCH();
    while (1) {
        ic_padding:
            DISPATCH();
        ic_addconst:
            READ_UINT(dstptr, bytecode, ipos);
            READ_INT(data, bytecode, ipos);
            TRACE("addconst %u %i\n", dstptr, data);
            memory[dstptr] += data;
            DISPATCH();
        ic_addrel:
            READ_UINT(dstptr, bytecode, ipos);
            READ_UINT(srcptr, bytecode, ipos);
            TRACE("addrel %u %u\n", dstptr, srcptr);
            memory[dstptr] += memory[srcptr];
            DISPATCH();
        ic_subconst:
            READ_UINT(dstptr, bytecode, ipos);
            READ_INT(data, bytecode, ipos);
            TRACE("subconst %u %i\n", dstptr, data);
            memory[dstptr] -= data;
            DISPATCH();
        ic_subrel:
            READ_UINT(dstptr, bytecode, ipos);
            READ_UINT(srcptr, bytecode, ipos);
            TRACE("subrel %u %u\n", dstptr, srcptr);
            memory[dstptr] -= memory[srcptr];
            DISPATCH();
        ic_movconst:
            READ_UINT(dstptr, bytecode, ipos);
            READ_INT(data, bytecode, ipos);
            TRACE("movconst %u %i\n", dstptr, data);
            memory[dstptr] = data;
            DISPATCH();
        ic_movrel:
            READ_UINT(dstptr, bytecode, ipos);
            READ_UINT(srcptr, bytecode, ipos);
            TRACE("movrel %u %u\n", dstptr, srcptr);
            memory[dstptr] = memory[srcptr];
            DISPATCH();
        ic_jump:
            READ_UINT(dstptr, bytecode, ipos);
            TRACE("jump %u\n", dstptr);
            //ipos = program_start_offset + memory[dstptr];
            ipos = program_start_offset + dstptr;
            DISPATCH();
        ic_jumpz:
            READ_UINT(dstptr, bytecode, ipos);
            READ_UINT(srcptr, bytecode, ipos);
            TRACE("jumpz %u %u\n", dstptr, srcptr);
            TRACE("  memory content for test: %i\n", memory[srcptr]);
            if (memory[srcptr] == 0) {
                TRACE("Jumping to %u\n", dstptr);
                //ipos = program_start_offset + memory[dstptr];
                ipos = program_start_offset + dstptr;
            }
            else {
                TRACE("Skipping\n");
            }
            DISPATCH();
        ic_print:
            READ_UINT(srcptr, bytecode, ipos);
            TRACE("print %u\n", srcptr);
            printf("%i\n", (int)memory[srcptr]);
            DISPATCH();
        ic_exit:
            TRACE("exit\n");
            free(memory);
            return;
    }

    /* shouldn't actually be reached */
    free(memory);
    return;
}

int
main(int argc, const char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "Invalid number of arguments\n");
        exit(1);
    }

    const char *filename = argv[1];

    char *bytecode;
    size_t len;
    if (read_file(filename, &bytecode, &len)) {
        fprintf(stderr, "Error reading code from file '%s'.\n", filename);
        exit(1);
    }

    printf("Executing bytecode content of '%s'.\n", filename);

    interpreter_state_t *interp = make_interpreter();
    interp->bytecode = (uint8_t *)bytecode;
    interp->code_length = len;

    execute(interp);
    if (interp->error != 0) {
        fprintf(stderr, "Error executing bytecode: '%s';\n", interp->error);
        exit(1);
    }

    return 0;
}


