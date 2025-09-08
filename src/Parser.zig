const std = @import("std");
const tokens = @import("tokens.zig");
const lexer = @import("lexer.zig");
const err = @import("errors.zig");
const main = @import("main.zig");

const Allocator = std.mem.Allocator;

const Tok = @import("tokens.zig").Tok;
const Err = err.Err;
const ErrVal = err.ErrVal;
const ErrTable = err.ErrTable;
const List = std.ArrayList;

const Parser = @This();

pub const NodeType = enum(u8) {
    Err = 0,
    Block,

    Mod,
    Let,
    Var,
    Type,
    Proc,
    ProcType,
    Fn,
    FnType,

    Name,
    Array,
    Tuple,
    StrLit,
    ChrLit,
    IntLit,
    FloatLit,
    Null,
    True,
    False,

    Not,
    Neg,

    Struct,
    Enum,
    //Class,

    If,
    IfExpr,
    Then,
    While,
    Break,
    Continue,
    Return,

    Generics,
    Construct,
    Call,
    Index,

    And,
    Or,

    Eq,
    EqEq,
    Neq,
    Lt,
    Lte,
    Gt,
    Gte,

    Dot,
    Colon,
    LessThan,
    GreaterThan,
    Plus,
    Sub,
    Mult,
    Div,
    Modulo,

    Arrow,
};

alc: Allocator,
err_table: *ErrTable,
source: []const u8,
ctx: Ctx,

tidx: u32,
// FIELDS WITH LIKE INDICES
tl: *List(Tok),
sidxs: *List(u32), // Index into source
lens: *List(u16),
cols: *List(u16),
//

expected_indent: u16,

pidx: u32,
// FIELDS WITH LIKE INDICES
nl: List(NodeType),
gl: List(Genus),
tidxs: List(Tok.Idx), // Index into tl
//
extra: List(Idx),

pub const Idx = packed union {
    to_node: u32,
    to_extra: u32,
    to_tok: u32,
    to_err: ErrTable.Idx,
    number: u32,

    pub const zero = Idx{ .number = 0 };
};

const Ctx = enum {
    None,
    Conditional, // treat '}' as a delimiter
    BareFnArgs, // treat '=' as a delimiter
    Generics, // treat '>' as a delimiter
};

const Genus = packed union {
    lr: packed struct { left: Idx, right: Idx },
    slice: packed struct { idx: Idx, len: u32 },
    conditional: packed struct {
        extra_idx: Idx,
        kind: enum(u8) { IfThen, IfElif, IfElse, IfExpr, IfStat },
    },

    pub const none = Genus{ .lr = .{ .left = Idx.zero, .right = Idx.zero } };

    pub fn to_pairs_u32(self: Genus) [2]u32 {
        return @bitCast(self);
    }
};

pub fn init(
    alc: Allocator,
    source: []const u8,
    err_table: *ErrTable,
    tl: *List(Tok),
    sidxs: *List(u32),
    lens: *List(u16),
    cols: *List(u16),
) !Parser {
    var p = Parser{
        .alc = alc,
        .err_table = err_table,
        .source = source,
        .ctx = Ctx.None,

        .tidx = 0,
        .tl = tl,
        .sidxs = sidxs,
        .lens = lens,
        .cols = cols,

        .expected_indent = 0,

        .pidx = 1,
        .nl = try List(NodeType).initCapacity(alc, main.GLOBAL.filesize / 4),
        .gl = try List(Genus).initCapacity(alc, main.GLOBAL.filesize / 4),
        .tidxs = try List(Tok.Idx).initCapacity(alc, main.GLOBAL.filesize / 4),

        .extra = try List(Idx).initCapacity(alc, main.GLOBAL.filesize / 4),
    };

    try p.nl.append(alc, NodeType.Err);
    try p.gl.append(alc, Genus.none);
    try p.tidxs.append(alc, @enumFromInt(0));
    try p.extra.append(alc, Idx.zero);

    return p;
}

pub fn deinit(self: *Parser) void {
    self.nl.deinit(self.alc);
    self.gl.deinit(self.alc);
    self.tidxs.deinit(self.alc);
    self.extra.deinit(self.alc);
}

pub fn parse(self: *Parser) !Idx {
    self.pidx = 0;
    self.tidx = 0;
    return try self.parseBlock();
}

fn curTok(self: *Parser) Tok {
    return self.tl.items[self.tidx];
}
fn expect(self: *Parser, op1: Tok, op2: ?Tok) Err!void {
    const tidx = self.tidx;
    const found = self.curTok();
    if (found == op1) return;
    if (op2) |t| if (found == t) return;
    _ = try self.err_table.submit(tidx, Err.TokenMismatch, ErrVal{ .TokenMismatch = .{ .op1 = op1, .op2 = op2, .found = found } });
    return Err.TokenMismatch;
}
fn pushNode(self: *Parser, nt: NodeType, genus: Genus, tidx: u32) !Idx {
    try self.nl.append(self.alc, nt);
    try self.gl.append(self.alc, genus);
    try self.tidxs.append(self.alc, @enumFromInt(tidx));
    self.pidx += 1;
    return Idx{ .to_node = self.pidx };
}

fn skip(self: *Parser, t: Tok) enum { null, eof } {
    if (self.tidx >= self.tl.items.len) return .eof;
    while (self.curTok() == t) {
        self.tidx += 1;
        if (self.tidx >= self.tl.items.len) return .eof;
    }
    return .null;
}

fn parseBlock(self: *Parser) !Idx {
    const t = self.tidx;
    var stat_list = try List(Idx).initCapacity(self.alc, 8);
    defer stat_list.deinit(self.alc);
    const prev_indent = self.expected_indent;
    self.expected_indent = self.cols.items[self.tidx];
    defer self.expected_indent = prev_indent;

    while (self.skip(Tok.Eol) != .eof) {
        if (self.curTok() == Tok.LexErr) {
            self.tidx += 1;
        }
        if (self.skip(Tok.Eol) == .eof) break;

        if (self.curTok() == Tok.BraceR) {
            self.tidx += 1;
            break;
        }

        const stat = self.parseStatement() catch {
            const n = try self.pushNode(NodeType.Err, Genus.none, t);
            try stat_list.append(self.alc, n);

            while (self.skip(Tok.Eol) != .eof and self.cols.items[self.tidx] > self.expected_indent) {
                self.tidx += 1;
            }

            continue;
        };
        try stat_list.append(self.alc, stat);
    }

    const i: u32 = @intCast(self.extra.items.len);
    for (stat_list.items) |stat| {
        try self.extra.append(self.alc, stat);
    }

    return try self.pushNode(NodeType.Block, Genus{ .slice = .{ .idx = Idx{ .to_extra = i }, .len = @intCast(stat_list.items.len) } }, t);
}

fn parseStatement(self: *Parser) Err!Idx {
    const t = self.tidx;
    if (self.skip(Tok.Eol) == .eof) return Idx.zero;
    switch (self.curTok()) {
        Tok.@"fn" => {
            self.tidx += 1;
            try self.expect(Tok.Name, null);
            const name = self.tidx;
            self.tidx += 1;
            if (self.curTok() == Tok.Colon) {
                const domain, _ = try self.parseListExpr(Tok.Colon, Tok.Comma, Tok.Arrow);
                const codomain = try self.parseExpr();

                return try self.pushNode(NodeType.FnType, Genus{ .lr = .{ .left = domain, .right = codomain } }, t);
            } else self.tidx -= 1;
            const old_ctx = self.ctx;
            self.ctx = Ctx.BareFnArgs;
            const fn_args, _ = try self.parseListExpr(Tok.Name, Tok.Comma, Tok.Eq);
            self.ctx = old_ctx;
            const fn_body = try self.parseExpr();

            const i: u32 = @intCast(self.extra.items.len);
            try self.extra.append(self.alc, Idx{ .to_tok = name });
            try self.extra.append(self.alc, fn_args);
            try self.extra.append(self.alc, fn_body);

            return try self.pushNode(NodeType.Fn, Genus{ .slice = .{ .idx = Idx{ .to_extra = i }, .len = 0 } }, t);
        },
        Tok.proc => {
            self.tidx += 1;
            try self.expect(Tok.Name, null);
            const name = self.tidx;
            self.tidx += 1;
            if (self.curTok() == Tok.Colon) {
                const domain, _ = try self.parseListExpr(Tok.Colon, Tok.Comma, Tok.Arrow);
                const codomain = try self.parseExpr();

                return try self.pushNode(NodeType.ProcType, Genus{ .lr = .{ .left = domain, .right = codomain } }, t);
            }
            const proc_args, _ = try self.parseListExpr(Tok.ParenL, Tok.Comma, Tok.ParenR);
            try self.expect(Tok.BraceL, null);
            self.tidx += 1;
            const proc_body = try self.parseBlock();

            const i: u32 = @intCast(self.extra.items.len);
            try self.extra.append(self.alc, Idx{ .to_tok = name });
            try self.extra.append(self.alc, proc_args);
            try self.extra.append(self.alc, proc_body);

            return try self.pushNode(NodeType.Proc, Genus{ .slice = .{ .idx = Idx{ .to_extra = i }, .len = 0 } }, t);
        },
        Tok.@"if" => {
            self.tidx += 1;
            const old_ctx = self.ctx;
            self.ctx = Ctx.Conditional;
            const cond = try self.parseExpr();
            self.ctx = old_ctx;

            if (self.curTok() == Tok.then) {
                self.tidx += 1;
                const i: u32 = @intCast(self.extra.items.len);
                try self.extra.append(self.alc, cond);
                try self.extra.append(self.alc, try self.parseStatement());
                return try self.pushNode(NodeType.If, Genus{ .conditional = .{ .kind = .IfStat, .extra_idx = Idx{ .to_extra = i } } }, t);
            }
            try self.expect(Tok.BraceL, Tok.then);
            self.tidx += 1;
            const then_block = try self.parseBlock();
            if (self.curTok() != Tok.@"else") {
                const i: u32 = @intCast(self.extra.items.len);
                try self.extra.append(self.alc, cond);
                try self.extra.append(self.alc, then_block);
                return try self.pushNode(NodeType.If, Genus{ .conditional = .{ .kind = .IfThen, .extra_idx = Idx{ .to_extra = i } } }, t);
            }
            self.tidx += 1;
            if (self.curTok() == Tok.@"if") {
                const elif = try self.parseStatement();
                const i: u32 = @intCast(self.extra.items.len);
                try self.extra.append(self.alc, cond);
                try self.extra.append(self.alc, then_block);
                try self.extra.append(self.alc, elif);
                return try self.pushNode(NodeType.If, Genus{ .conditional = .{ .kind = .IfElif, .extra_idx = Idx{ .to_extra = i } } }, t);
            }
            try self.expect(Tok.BraceL, null);
            self.tidx += 1;
            const else_block = try self.parseBlock();
            const i: u32 = @intCast(self.extra.items.len);
            try self.extra.append(self.alc, cond);
            try self.extra.append(self.alc, then_block);
            try self.extra.append(self.alc, else_block);
            return try self.pushNode(NodeType.If, Genus{ .conditional = .{ .kind = .IfElse, .extra_idx = Idx{ .to_extra = i } } }, t);
        },
        Tok.@"while" => {
            self.tidx += 1;
            const old_ctx = self.ctx;
            self.ctx = Ctx.Conditional;
            const cond = try self.parseExpr();
            self.ctx = old_ctx;
            try self.expect(Tok.BraceL, null);
            self.tidx += 1;
            const block = try self.parseBlock();
            return try self.pushNode(NodeType.While, Genus{ .lr = .{ .left = cond, .right = block } }, t);
        },

        else => {
            const p = try self.parseExpr();
            _ = self.skip(Tok.Semicolon);
            while (self.tidx < self.tl.items.len and self.curTok() == Tok.Semicolon) {
                self.tidx += 1;
            }
            return p;
        },
    }
}

fn parseExpr(self: *Parser) Err!Idx {
    return try self.parseExprBp(0);
}

fn parseExprBp(self: *Parser, min_bp: u8) Err!Idx {
    var lhs: Idx = undefined;
    if (self.tidx >= self.tl.items.len) return Idx.zero;
    while (self.curTok() == Tok.Eol) {
        self.tidx += 1;
        if (self.tidx >= self.tl.items.len) return Idx.zero;
        if (self.cols.items[self.tidx] < self.expected_indent) break;
    }

    const t = self.tidx;
    lhs: while (true) switch (self.curTok()) {
        Tok.ParenL => {
            const i, const len = try self.parseListExpr(Tok.ParenL, Tok.Comma, Tok.ParenR);
            lhs = try self.pushNode(NodeType.Tuple, Genus{ .slice = .{ .idx = i, .len = len } }, t);
            break :lhs;
        },
        Tok.BrackL => {
            const i, const len = try self.parseListExpr(Tok.BrackL, Tok.Comma, Tok.BrackR);
            lhs = try self.pushNode(NodeType.Array, Genus{ .slice = .{ .idx = i, .len = len } }, t);
            break :lhs;
        },
        Tok.@"struct", Tok.@"enum" => {
            const nt = if (self.curTok() == Tok.@"struct") NodeType.Struct else NodeType.Enum;
            self.tidx += 1;
            const fields, const len = try self.parseListExpr(Tok.BraceL, Tok.Comma, Tok.BraceR);
            lhs = try self.pushNode(nt, Genus{ .slice = .{ .idx = fields, .len = len } }, self.tidx);
            break :lhs;
        },
        Tok.@"if" => {
            self.tidx += 1;
            const cond = try self.parseExpr();
            try self.expect(Tok.then, null);
            self.tidx += 1;
            const e1 = try self.parseExpr();
            try self.expect(Tok.@"else", null);
            self.tidx += 1;
            const e2 = try self.parseExpr();
            const i: u32 = @intCast(self.extra.items.len);
            try self.extra.append(self.alc, cond);
            try self.extra.append(self.alc, e1);
            try self.extra.append(self.alc, e2);
            lhs = try self.pushNode(NodeType.IfExpr, Genus{ .conditional = .{ .kind = .IfExpr, .extra_idx = Idx{ .to_extra = i } } }, t);
            break :lhs;
        },
        else => {
            if (self.curTok().asNtLiteral()) |nt| {
                self.tidx += 1;
                lhs = try self.pushNode(nt, Genus.none, t);
                break :lhs;
            }
            if (self.curTok().asNtPrefix()) |nt| {
                const bp = self.curTok().prefixBp();
                self.tidx += 1;
                lhs = try self.pushNode(nt, Genus{ .slice = .{ .idx = try self.parseExprBp(bp), .len = 0 } }, t);
                break :lhs;
            }

            const err_val = ErrVal{ .UnexpectedToken = .{ .found = self.curTok() } };
            const e = try self.err_table.submit(t, Err.UnexpectedToken, err_val);
            const n = try self.pushNode(NodeType.Err, Genus{ .slice = .{ .idx = Idx{ .to_err = e }, .len = 0 } }, t);
            self.tidx += 1;
            while (self.tidx < self.tl.items.len and self.cols.items[self.tidx] > self.expected_indent)
                self.tidx += 1;

            return n;
        },
    };

    loop: while (self.skip(Tok.Eol) != .eof) {
        const as_infix = self.curTok().asNtInfix();
        const as_postfix = self.curTok().as_NT_postfix();

        const tok_touching_prev = self.sidxs.items[self.tidx - 1] + self.lens.items[self.tidx - 1] == self.sidxs.items[self.tidx];

        // in the case where there's a postfix op that's also an infix op, defer to whitespace
        // whitespace => infix op, no whitespace => postfix op
        if (as_postfix) |nt| if (as_infix == null or tok_touching_prev) {
            // This disallows instantiations in conditionals so that parentheses are not required
            if (self.ctx == Ctx.Conditional and self.curTok() == Tok.BraceL) {
                break :loop;
            }
            const bp = self.curTok().postfixBp();
            if (bp < min_bp) break :loop;
            const old_ctx = self.ctx;
            if (self.curTok() == Tok.Lt) {
                self.ctx = Ctx.Generics;
            }
            const idx, const len = try self.parseListExpr(self.curTok(), Tok.Comma, self.curTok().compliment());
            self.ctx = old_ctx;
            lhs = try self.pushNode(nt, Genus{ .slice = .{ .idx = idx, .len = len } }, t);
            continue;
        };

        if (as_infix) |nt| {
            if (nt == NodeType.Eq and self.ctx == Ctx.BareFnArgs) {
                break :loop;
            }
            const l_bp, const r_bp = self.curTok().infixBp();
            if (l_bp < min_bp) break :loop;
            if (self.ctx == Ctx.Generics and self.curTok() == Tok.Gt) break;
            self.tidx += 1;
            lhs = try self.pushNode(nt, Genus{ .lr = .{ .left = lhs, .right = try self.parseExprBp(r_bp) } }, t);
            continue;
        }

        _ = self.skip(Tok.Eol);
        break :loop;
    }

    return lhs;
}

fn parseListExpr(self: *Parser, l_delim: Tok, sep: Tok, r_delim: Tok) Err!struct { Idx, u32 } { // u32 is index into self.extra, terminated with 0
    try self.expect(l_delim, null);
    self.tidx += 1;
    var list = try List(Idx).initCapacity(self.alc, 4);
    defer list.deinit(self.alc);
    while (self.skip(Tok.Eol) != .eof) {
        if (self.curTok() == r_delim) {
            self.tidx += 1;
            break;
        }
        try list.append(self.alc, try self.parseExprBp(0));
        if (self.skip(Tok.Eol) == .eof) {
            const e = try self.err_table.submit(self.tidx, Err.EarlyEof, ErrVal{ .EarlyEof = {} });
            _ = try self.pushNode(.Err, Genus{ .slice = .{ .idx = Idx{ .to_err = e }, .len = 0 } }, self.tidx);
            return Err.EarlyEof;
        }
        if (self.curTok() == r_delim) {
            self.tidx += 1;
            break;
        }
        try self.expect(sep, r_delim);
        self.tidx += 1;
    }
    const i: u32 = @intCast(self.extra.items.len);
    for (list.items) |entry| {
        try self.extra.append(self.alc, entry);
    }
    try self.extra.append(self.alc, Idx.zero);
    return .{ Idx{ .to_extra = i }, @intCast(list.items.len) };
}
