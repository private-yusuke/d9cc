module ir;

import parse;

// Intermediate representation

public:

enum IRType
{
    IMM,
    MOV,
    RETURN,
    KILL,
    NOP,
    ADD = '+',
    SUB = '-'
}

struct IR
{
    IRType type;
    size_t lhs;
    size_t rhs;
}

IR[] gen_ir(Node* node)
{
    IR[] res;
    size_t regno;

    size_t r = gen_ir_sub(res, regno, node);
    res ~= new_ir(IRType.RETURN, r, 0);
    return res;
}

private:

IR new_ir(IRType type, size_t lhs, size_t rhs)
{
    IR ir;
    ir.type = type;
    ir.lhs = lhs;
    ir.rhs = rhs;
    return ir;
}

size_t gen_ir_sub(ref IR[] ins, ref size_t regno, Node* node)
{
    if (node.type == NodeType.NUM)
    {
        size_t r = regno++;
        ins ~= new_ir(IRType.IMM, r, node.val);
        return r;
    }

    assert(node.type == '+' || node.type == '-');

    size_t lhs = gen_ir_sub(ins, regno, node.lhs);
    size_t rhs = gen_ir_sub(ins, regno, node.rhs);

    ins ~= new_ir(cast(IRType) node.type, lhs, rhs);
    ins ~= new_ir(IRType.KILL, rhs, 0);
    return lhs;
}
