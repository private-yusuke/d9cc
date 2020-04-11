module codegen;

import std.stdio : writeln, writefln;
import ir, parse, regalloc;

public:

void gen_x86(IR[] ins)
{
    foreach (ir; ins)
    {
        switch (ir.type)
        {
        case IRType.IMM:
            writefln("  mov %s, %d", regs[ir.lhs], ir.rhs);
            break;
        case IRType.MOV:
            writefln("  mov %s, %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.RETURN:
            writefln("  mov rax, %s", regs[ir.lhs]);
            writeln("  ret");
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
        case IRType.NOP:
            break;
        default:
            assert(0, "unknown operator");
        }
    }
}
