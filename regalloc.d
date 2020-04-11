module regalloc;

import std.stdio : stderr, writeln;
import ir, util;

public:

static immutable string[] regs = [
    "rdi", "rsi", "r10", "r11", "r12", "r13", "r14", "r15"
];
void alloc_regs(ref IR[] ins)
{
    size_t[size_t] reg_map;
    bool[] used = new bool[](regs.length);

    foreach (ref ir; ins)
    {
        switch (ir.type)
        {
        case IRType.IMM:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            break;
        case IRType.MOV:
        case IRType.ADD:
        case IRType.SUB:
        case IRType.MUL:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            ir.rhs = alloc(reg_map, used, ir.rhs);
            break;
        case IRType.RETURN:
            kill(used, reg_map[ir.lhs]);
            break;
        case IRType.KILL:
            kill(used, reg_map[ir.lhs]);
            ir.type = IRType.NOP;
            break;
        default:
            assert(0, "unknown operator");
        }
    }
}

private:

size_t alloc(ref size_t[size_t] reg_map, ref bool[] used, size_t ir_reg)
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
    stderr.writeln("register exhausted");
    throw new QuitException(-1);
}

void kill(ref bool[] used, size_t r)
{
    assert(used[r]);
    used[r] = false;
}
