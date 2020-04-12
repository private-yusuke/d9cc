module codegen;

import std.stdio : writeln, writefln;
import std.string : format;
import ir, parse, regalloc;

public:

void gen_x86(IR[] ins)
{
    string ret = ".Lend";

    writeln("  push rbp");
    writeln("  mov rbp, rsp");

    foreach (ir; ins)
    {
        switch (ir.type)
        {
        case IRType.IMM:
            writefln("  mov %s, %d", regs[ir.lhs], ir.rhs);
            break;
        case IRType.ADD_IMM:
            writefln("  add %s, %d", regs[ir.lhs], ir.rhs);
            break;
        case IRType.MOV:
            writefln("  mov %s, %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.RETURN:
            writefln("  mov rax, %s", regs[ir.lhs]);
            writefln("  jmp %s", ret);
            break;
        case IRType.LABEL:
            writefln(".L%d:", ir.lhs);
            break;
        case IRType.UNLESS:
            writefln("  cmp %s, 0", regs[ir.lhs]);
            writefln("  je .L%d", ir.rhs);
            break;
        case IRType.ALLOCA:
            if (ir.rhs != -1)
                writefln("  sub rsp, %d", ir.rhs);
            writefln("  mov %s, rsp", regs[ir.lhs]);
            break;
        case IRType.LOAD:
            writefln("  mov %s, [%s]", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.STORE:
            writefln("  mov [%s], %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.ADD:
            writefln("  add %s, %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.SUB:
            writefln("  sub %s, %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.MUL:
            writefln("  mov rax, %s", regs[ir.rhs]);
            writefln("  mul %s", regs[ir.lhs]);
            writefln("  mov %s, rax", regs[ir.lhs]);
            break;
        case IRType.DIV:
            writefln("  mov rax, %s", regs[ir.lhs]);
            writeln("  cqo");
            writefln("  div %s", regs[ir.rhs]);
            writefln("  mov %s, rax", regs[ir.lhs]);
            break;
        case IRType.NOP:
            break;
        default:
            assert(0, "unknown operator: %s".format(ir.type));
        }
    }

    writefln("%s:", ret);
    writeln("  mov rsp, rbp");
    writeln("  pop rbp");
    writeln("  ret");
}

private:

import std.string : format;

size_t n;

string gen_label()
{
    return format(".L%d", n++);
}
