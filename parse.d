module parse;

import std.stdio : stderr;
import token, util;

public:

enum NodeType
{
    NUM, // Number literal
    ADD = '+',
    SUB = '-',
    RETURN, // Return statement
    COMP_STMT, // Compound statement
    EXPR_STMT // Expressions statement
}

struct Node
{
    NodeType type; // Node type
    Node* lhs = null;
    Node* rhs = null;
    int val; // Number literal
    Node* expr; // "return" or expression stmt
    Node[] stmts; // Compound statement
}

void expect(char c, Token[] tokens, ref size_t pos)
{
    if (tokens[pos].type != cast(TokenType) c)
        error("%s (%s) expected, but got %s (%s)", c, cast(TokenType) c,
                tokens[pos].input, tokens[pos].type);
    pos++;
}

Node* parse(Token[] tokens)
{
    size_t pos;
    return stmt(tokens, pos);
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
    if (tokens[pos].type != TokenType.NUM)
        error("Number expected, but got %s", tokens[pos].input);
    Node* res = new_node_num(tokens[pos].val);
    pos++;
    return res;
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

Node* stmt(Token[] tokens, ref size_t pos)
{
    Node* node = new Node;
    node.type = NodeType.COMP_STMT;
    node.stmts = [];

    while (true)
    {
        if (tokens[pos].type == TokenType.EOF)
            return node;

        Node e;

        if (tokens[pos].type == TokenType.RETURN)
        {
            pos++;
            e.type = NodeType.RETURN;
            e.expr = expr(tokens, pos);
        }
        else
        {
            e.type = NodeType.EXPR_STMT;
            e.expr = expr(tokens, pos);
        }
        node.stmts ~= e;
        expect(';', tokens, pos);
    }
    return node;
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
}
