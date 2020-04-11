module parse;

import std.stdio : stderr;
import token, util;

public:

enum NodeType
{
    NUM, // Number literal
    ADD = '+',
    SUB = '-'
}

struct Node
{
    NodeType type; // Node type
    Node* lhs = null;
    Node* rhs = null;
    int val; // Number literal
}

Node* parse(Token[] tokens)
{
    size_t pos;
    Node* node = expr(tokens, pos);

    TokenType t = tokens[pos].type;
    if (t != TokenType.EOF)
        stderr.writefln("stray token: %s", tokens[pos].input);
    return node;
}

private:
Node* new_node(NodeType op, Node* lhs, Node* rhs)
{
    Node* node = new Node;
    node.type = op;
    node.lhs = lhs;
    node.rhs = rhs;
    return node;
}

Node* new_node_num(int val)
{
    Node* node = new Node;
    node.type = NodeType.NUM;
    node.val = val;
    return node;
}

Node* number(Token[] tokens, ref size_t pos)
{
    if (tokens[pos].type == TokenType.NUM)
        return new_node_num(tokens[pos++].val);
    stderr.writefln("Number expected, but got %s", tokens[pos].input);
    throw new QuitException(-1);
}

Node* mul(Token[] tokens, ref size_t pos)
{
    Node* lhs = number(tokens, pos);
    while (true)
    {
        TokenType op = tokens[pos].type;
        if (op != '*' && op != '/')
            return lhs;
        pos++;
        lhs = new_node(cast(NodeType) op, lhs, number(tokens, pos));
    }
}

Node* expr(Token[] tokens, ref size_t pos)
{
    Node* lhs = mul(tokens, pos);
    while (true)
    {
        TokenType op = tokens[pos].type;
        if (op != '+' && op != '-')
            return lhs;
        pos++;
        lhs = new_node(cast(NodeType) op, lhs, mul(tokens, pos));
    }
    return lhs;
}
