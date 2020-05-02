module sema;

import parse : Node, NodeType;
import util;

public:
void sema(ref Node[] nodes)
{
    foreach (node; nodes)
    {
        assert(node.type == NodeType.FUNC);

        vars.clear();
        stacksize = 0;
        walk(&node);
        node.stacksize = stacksize;
    }
}

private:

long[string] vars;
long stacksize;

void walk(Node* node)
{
    with (NodeType) switch (node.type)
    {
    case NUM:
        return;
    case IDENT:
        if (node.name !in vars)
            error("undefined variable: %s", node.name);
        node.type = NodeType.LVAR;
        node.offset = vars[node.name];
        return;
    case VARDEF:
        stacksize += 8;
        vars[node.name] = stacksize;
        node.offset = stacksize;
        if (node.initialize)
            walk(node.initialize);
        return;
    case IF:
        walk(node.cond);
        walk(node.then);
        if (node.els)
            walk(node.els);
        return;
    case FOR:
        walk(node.initialize);
        walk(node.cond);
        walk(node.inc);
        walk(node.fbody);
        return;
    case ADD:
    case SUB:
    case MUL:
    case DIV:
    case ASSIGN:
    case LESS_THAN:
    case LOGAND:
    case LOGOR:
        walk(node.lhs);
        walk(node.rhs);
        return;
    case RETURN:
        walk(node.expr);
        return;
    case CALL:
        foreach (ref v; node.args)
            walk(&v);
        return;
    case FUNC:
        foreach (ref v; node.args)
            walk(&v);
        walk(node.fbody);
        return;
    case COMP_STMT:
        foreach (ref v; node.stmts)
            walk(v);
        return;
    case EXPR_STMT:
        walk(node.expr);
        return;
    default:
        assert(0, "unknown node type");
    }
}
