module regalloc;

import std.stdio : stderr, writeln;
import gen_ir, util;

public:

static immutable string[] regs = [
    "rbp", "r10", "r11", "rbx", "r12", "r13", "r14", "r15"
];
static immutable string[] regs8 = [
    "bpl", "r10b", "r11b", "bl", "r12b", "r13b", "r14b", "r15b"
];

void alloc_regs(Function[] fns)
{
    foreach (fn; fns)
    {
        reg_map.clear();
        used = new bool[](regs.length);

        visit(fn.ir);
    }
}

private:
long[long] reg_map;
bool[] used;

void visit(ref IR[] ins)
{
    // r0 is a reserved register taht is always mapped to rbp.
    reg_map[0] = 0;
    used[0] = true;

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
            assert(used[ir.lhs]);
            used[ir.lhs] = false;
            ir.type = IRType.NOP;
        }
    }
}

size_t alloc(size_t ir_reg)
{
    if (ir_reg in reg_map)
    {
        long r = reg_map[ir_reg];
        assert(used[r]);
        return r;
    }

    foreach (i; 0 .. regs.length)
    {
        if (used[i])
            continue;
        reg_map[ir_reg] = i;
        used[i] = true;
        return i;
    }
    error("register exhausted");
    assert(0);
}
