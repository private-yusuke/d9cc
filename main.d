module main;

import std.stdio : writeln, stderr;
import std.algorithm : each;
import std.range : enumerate;
import token, ir, parse, codegen, regalloc, util;

int main(string[] args)
{
    string input;
    bool dump_ir1 = false;
    bool dump_ir2 = false;

    if (args.length == 3 && args[1] == "-dump-ir1")
    {
        dump_ir1 = true;
        input = args[2];
    }
    else if (args.length == 3 && args[1] == "-dump-ir2")
    {
        dump_ir2 = true;
        input = args[2];
    }
    else if (args.length != 2)
    {
        stderr.writeln("Usage: d9cc [-dump-ir] <code>");
        return 1;
    }
    else
        input = args[1];
    try
    {
        Token[] tokens = tokenize(input);
        Node* node = parse.parse(tokens);

        IR[] ins = gen_ir(node);

        if (dump_ir1)
            ins.enumerate.each!(p => stderr.writefln("%3d:  %s", p[0], p[1]));

        alloc_regs(ins);

        if (dump_ir2)
            ins.each!(ir => stderr.writeln(ir));

        writeln(".intel_syntax noprefix");
        writeln(".global main");
        writeln("main:");

        gen_x86(ins);
    }
    catch (QuitException e)
        return e.return_code;
    return 0;
}
