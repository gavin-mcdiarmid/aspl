const Parser = @import("Parser.zig");

pub const Tok = enum(u8) {
    LexErr,
    Eof,
    Eol,

    // All Keywords are lower case
    mod,
    let,
    @"var",
    @"fn",
    proc,
    type,
    @"struct",
    @"enum",

    not,
    Bang,

    true,
    false,
    null,

    Name,
    StrLit,
    ChrLit,
    IntLit,
    FloatLit,

    @"if",
    then,
    @"else",
    // for,
    // in,
    @"while",
    @"return",
    // break,
    // continue,
    // Assert,

    @"and",
    @"or",
    Eq,
    EqEq,
    Neq,
    Lt,
    Lte,
    Gt,
    Gte,

    Dot,
    Comma,
    Plus,
    Sub,
    Mult,
    Div,
    Modu,
    Colon,
    Semicolon,
    Arrow,
    // Qstnmark,
    // Bang,
    BraceL,
    BraceR,
    ParenL,
    ParenR,
    BrackL,
    BrackR,

    pub const Idx = enum(u32) { _ };

    pub fn prefixBp(t: Tok) u8 {
        return switch (t) {
            Tok.@"return" => 1,
            Tok.type => 7,
            Tok.mod => 9,
            Tok.let => 9,
            Tok.@"var" => 9,
            Tok.not => 15,
            Tok.Sub => 21,
            Tok.Dot => 27,
            else => unreachable,
        };
    }
    pub fn postfixBp(t: Tok) u8 {
        return switch (t) {
            Tok.ParenL => 23,
            Tok.BraceL => 23,
            Tok.BrackL => 23,
            Tok.Lt => 23,
            else => unreachable,
        };
    }
    pub fn infixBp(t: Tok) struct { u8, u8 } {
        return switch (t) {
            Tok.Eq => .{ 1, 2 },
            Tok.@"or" => .{ 3, 4 },
            Tok.@"and" => .{ 5, 6 },
            Tok.Colon => .{ 11, 12 },

            Tok.EqEq => .{ 13, 14 },
            Tok.Neq => .{ 13, 14 },

            Tok.Lt => .{ 15, 16 },
            Tok.Lte => .{ 15, 16 },
            Tok.Gt => .{ 15, 16 },
            Tok.Gte => .{ 15, 16 },

            Tok.Plus => .{ 17, 18 },
            Tok.Sub => .{ 17, 18 },
            Tok.Mult => .{ 19, 20 },
            Tok.Div => .{ 19, 20 },
            Tok.Modu => .{ 19, 20 },
            Tok.Dot => .{ 25, 26 },
            else => unreachable,
        };
    }

    pub fn asNtLiteral(self: Tok) ?Parser.NodeType {
        return switch (self) {
            Tok.null => Parser.NodeType.Null,
            Tok.Name => Parser.NodeType.Name,
            Tok.StrLit => Parser.NodeType.StrLit,
            Tok.ChrLit => Parser.NodeType.ChrLit,
            Tok.IntLit => Parser.NodeType.IntLit,
            Tok.FloatLit => Parser.NodeType.FloatLit,
            Tok.true => Parser.NodeType.True,
            Tok.false => Parser.NodeType.False,

            else => null,
        };
    }

    pub fn asNtPrefix(self: Tok) ?Parser.NodeType {
        return switch (self) {
            Tok.mod => Parser.NodeType.Mod,
            Tok.let => Parser.NodeType.Let,
            Tok.@"var" => Parser.NodeType.Var,
            Tok.type => Parser.NodeType.Type,
            Tok.not => Parser.NodeType.Not,
            Tok.Dot => Parser.NodeType.Dot,
            Tok.Sub => Parser.NodeType.Neg,
            Tok.@"return" => Parser.NodeType.Return,

            else => null,
        };
    }

    pub fn as_NT_postfix(self: Tok) ?Parser.NodeType {
        return switch (self) {
            Tok.ParenL => Parser.NodeType.Call,
            Tok.BraceL => Parser.NodeType.Construct,
            Tok.BrackL => Parser.NodeType.Index,
            Tok.Lt => Parser.NodeType.Generics,
            else => null,
        };
    }

    pub fn compliment(t: Tok) Tok {
        return switch (t) {
            Tok.ParenL => Tok.ParenR,
            Tok.ParenR => Tok.ParenL,
            Tok.BraceL => Tok.BraceR,
            Tok.BraceR => Tok.BraceL,
            Tok.BrackL => Tok.BrackR,
            Tok.BrackR => Tok.BrackL,
            Tok.Lt => Tok.Gt,
            Tok.Gt => Tok.Lt,
            else => unreachable,
        };
    }

    pub fn asNtInfix(self: Tok) ?Parser.NodeType {
        return switch (self) {
            Tok.@"and" => Parser.NodeType.And,
            Tok.@"or" => Parser.NodeType.Or,

            Tok.Eq => Parser.NodeType.Eq,
            Tok.EqEq => Parser.NodeType.EqEq,
            Tok.Neq => Parser.NodeType.Neq,
            Tok.Lt => Parser.NodeType.Lt,
            Tok.Lte => Parser.NodeType.Lte,
            Tok.Gt => Parser.NodeType.Gt,
            Tok.Gte => Parser.NodeType.Gte,

            Tok.Dot => Parser.NodeType.Dot,
            Tok.Colon => Parser.NodeType.Colon,
            Tok.Plus => Parser.NodeType.Plus,
            Tok.Sub => Parser.NodeType.Sub,
            Tok.Mult => Parser.NodeType.Mult,
            Tok.Div => Parser.NodeType.Div,
            Tok.Modu => Parser.NodeType.Modulo,
            else => null,
        };
    }
};
