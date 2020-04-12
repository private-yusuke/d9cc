module regalloc;

import std.stdio : stderr, writeln;
import ir, util;

public:

static immutable string[] regs = [
    "rdi", "rsi", "r10", "r11", "r12", "r13", "r14", "r15"
];

void alloc_regs(ref IR[] ins)
{
    used = new bool[](regs.length);

    foreach (ref ir; ins)
    {
        switch (ir.getInfo())
        {
        case IRInfo.REG:
        case IRInfo.REG_IMM:
        case IRInfo.REG_LABEL:
            ir.lhs = alloc(ir.lhs);
            break;
        case IRInfo.REG_REG:
            ir.lhs = alloc(ir.lhs);
            ir.rhs = alloc(ir.rhs);
            break;
        case IRInfo.CALL:
            ir.lhs = alloc(ir.lhs);
            foreach (i, v; ir.args)
                ir.args[i] = alloc(v);
            break;
        default:
            break;
        }
        if (ir.type == IRType.KILL)
        {
            kill(ir.lhs);
            ir.type = IRType.NOP;
        }
    }
}

private:
size_t[size_t] reg_map;
bool[] used;

size_t alloc(size_t ir_reg)
{
    if (ir_reg in reg_map)
    {
        size_t r = reg_map[ir_reg];
        assert(used[r]);
        return r;
    }

    foreach (i; 0 .. regs.length)
    {
        if (used[i])
            continue;
        used[i] = true;
        reg_map[ir_reg] = i;
        return i;
    }
    error("register exhausted");
    assert(0);
}

void kill(size_t r)
{
    assert(used[r]);
    used[r] = false;
}
