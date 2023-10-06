const std = @import("std");

pub const ValueType = enum {
    Bool,
    Nil,
    Number,
};

pub const Value = union(ValueType) {
    Bool: bool,
    Number: f64,
    Nil: f64,
};

pub fn boolVal(value: bool) Value {
    return Value{ .Bool = value };
}

pub fn nilVal() Value {
    return Value{ .Nil = 0 };
}

pub fn numberVal(value: f64) Value {
    return Value{ .Number = value };
}

pub fn isBool(value: Value) bool {
    return @as(ValueType, value) == .Bool;
}

pub fn isNil(value: Value) bool {
    return @as(ValueType, value) == .Nil;
}

pub fn isNumber(value: Value) bool {
    return @as(ValueType, value) == .Number;
}

pub fn valuesEqual(a: Value, b: Value) bool {
    if (@as(ValueType, a) != @as(ValueType, b)) return false;

    switch (@as(ValueType, a)) {
        .Bool => {
            return a.Bool == b.Bool;
        },
        .Nil => {
            return true;
        },
        .Number => {
            return a.Number == b.Number;
        },
    }
}

pub fn printValue(value: Value) void {
    switch (@as(ValueType, value)) {
        .Bool => {
            std.debug.print("{}\n", .{value.Bool});
        },
        .Nil => {
            std.debug.print("nil\n", .{});
        },
        .Number => {
            std.debug.print("{d}\n", .{value.Number});
        },
    }
}
