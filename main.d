module main;

import std.stdio : writeln, stderr;
import token, ir, parse, codegen, regalloc, util;

int main(string[] args)
{
    if (args.length < 2)
    {
        stderr.writeln("Usage: d9cc <code>");

        return 1;
    }

    try
    {
        Token[] tokens = tokenize(args[1]);
        Node* node = parse.parse(tokens);

        IR[] ins = gen_ir(node);
        alloc_regs(ins);

        writeln(".intel_syntax noprefix");
        writeln(".global main");
        writeln("main:");

        gen_x86(ins);
    }
    catch (QuitException e)
        return e.return_code;
    return 0;
}
