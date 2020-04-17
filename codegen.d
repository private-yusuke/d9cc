module codegen;

import std.stdio : writeln, writefln;
import std.string : format;
import std.algorithm : each;
import std.range : retro;
import ir, parse, regalloc;

public:

void gen_x86(Function[] fns)
{
    writeln(".intel_syntax noprefix");

    foreach (fn; fns)
        gen(fn);
}

private:

import std.string : format;

size_t n;
long label;

static immutable argreg = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"];

void gen(Function fn)
{
    string ret = ".Lend%d".format(label++);
    writefln(".global %s", fn.name);
    writefln("%s:", fn.name);
    writeln("  push rbp");
    writeln("  mov rbp, rsp");
    writefln("  sub rsp, %d", fn.stacksize);
    writeln("  push r12");
    writeln("  push r13");
    writeln("  push r14");
    writeln("  push r15");

    foreach (ir; fn.ir)
    {
        switch (ir.type)
        {
        case IRType.IMM:
            writefln("  mov %s, %d", regs[ir.lhs], ir.rhs);
            break;
        case IRType.SUB_IMM:
            writefln("  sub %s, %d", regs[ir.lhs], ir.rhs);
            break;
        case IRType.MOV:
            writefln("  mov %s, %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.RETURN:
            writefln("  mov rax, %s", regs[ir.lhs]);
            writefln("  jmp %s", ret);
            break;
        case IRType.CALL:
            static immutable save_regs = [
                "rbx", "rbp", "rsp", "r12", "r13", "r14", "r15"
            ];
            save_regs.each!(v => writefln("  push %s", v));

            foreach (i, v; ir.args)
            {
                writefln("  mov %s, %s", argreg[i], regs[v]);
            }

            writeln("  push r10");
            writeln("  push r11");
            writeln("  mov rax, 0");
            writefln("  call %s", ir.name);
            writeln("  pop r11");
            writeln("  pop r10");

            writefln("  mov %s, rax", regs[ir.lhs]);
            break;
        case IRType.LABEL:
            writefln(".L%d:", ir.lhs);
            break;
        case IRType.JMP:
            writefln("  jmp .L%d", ir.lhs);
            break;
        case IRType.UNLESS:
            writefln("  cmp %s, 0", regs[ir.lhs]);
            writefln("  je .L%d", ir.rhs);
            break;
        case IRType.LOAD:
            writefln("  mov %s, [%s]", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.STORE:
            writefln("  mov [%s], %s", regs[ir.lhs], regs[ir.rhs]);
            break;
        case IRType.SAVE_ARGS:
            foreach (i; 0 .. ir.lhs)
                writefln("  mov [rbp-%d], %s", (i + 1) * 8, argreg[i]);
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
    writeln("  pop r15");
    writeln("  pop r14");
    writeln("  pop r13");
    writeln("  pop r12");
    writeln("  mov rsp, rbp");
    writeln("  pop rbp");
    writeln("  ret");
}

string gen_label()
{
    return format(".L%d", n++);
}
