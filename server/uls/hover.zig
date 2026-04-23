const std = @import("std");
const usrl = @import("usrl");
const lsp = @import("lsp");
const ULS = @import("../ULS.zig");

pub fn @"textDocument/hover"(
    uls: ULS,
    allocator: std.mem.Allocator,
    params: lsp.types.HoverParams,
) ULS.Error!?lsp.types.Hover {
    const document = uls.docs.get(params.textDocument.uri) orelse return error.InvalidParams;
    const index = lsp.offsets.positionToIndex(document, params.position, uls.encoding);
    var tokenizer = usrl.Tokenizer.init(document);
    var diag = usrl.TokenizeDiagnostics.init(allocator);
    defer diag.deinit();

    while (tokenizer.token(allocator, &diag)) |result| {
        const tkn = result orelse break;
        defer usrl.Token.cleanup(allocator, &.{tkn});

        if (tkn.value != .variable) continue;
        if (index < tkn.loc.index or index > tkn.loc.index + tkn.loc.len) continue;
        return .{
            .contents = .{
                .MarkupContent = .{
                    .kind = .markdown,
                    .value = descriptions.get(tkn.value.variable) orelse continue,
                },
            },
            .range = ULS.locToRange(document, tkn.loc, uls.encoding),
        };
    } else |_| {}

    return null;
}

pub const descriptions = std.StaticStringMap([]const u8).initComptime(.{
    .{
        "min",
        \\```usrl
        \\$min(x, y)
        \\```
        \\
        \\Accepts two numeric arguments and returns the smaller one. Equivalent to `$x < $y ? $x : $y`.
    },
    .{
        "max",
        \\```usrl
        \\$max(x, y)
        \\```
        \\
        \\Accepts two numeric arguments and returns the larger one. Equivalent to `$x > $y ? $x : $y`.
    },
    .{
        "floor",
        \\```usrl
        \\$floor(x)
        \\```
        \\
        \\Removes the fractional part of the numeric argument by rounding down.
    },
    .{
        "ceil",
        \\```usrl
        \\$ceil(x)
        \\```
        \\
        \\Removes the fractional part of `x` by rounding up.
    },
    .{
        "trunc",
        \\```usrl
        \\$trunc(x)
        \\```
        \\
        \\Removes the fractional part of the numeric argument by rounding toward zero.
    },

    .{
        "round",
        \\```usrl
        \\$round(x)
        \\```
        \\
        \\Removes the fractional part of the numeric argument by rounding to the nearest integer.
    },
    .{
        "sqrt",
        \\```usrl
        \\$sqrt(x)
        \\```
        \\
        \\Returns the square root of the numeric argument.
    },
    .{
        "abs",
        \\```usrl
        \\$abs(x)
        \\```
        \\
        \\Returns the absolute value of the numeric argument.
    },
    .{
        "sin",
        \\```usrl
        \\$sin(x)
        \\```
        \\
        \\Accepts a numeric argument in radians and returns its sine.
    },
    .{
        "cos",
        \\```usrl
        \\$cos(x)
        \\```
        \\
        \\Accepts a numeric argument in radians and returns its cosine.
    },
    .{
        "prop",
        \\```usrl
        \\$prop(str)
        \\```
        \\
        \\Accesses a context property through a string.
        \\
        \\```usrl
        \\$prop('velocidade') == velocidade,
        \\$prop('vida') == vida
        \\```
    },
    .{
        "len",
        \\```usrl
        \\$len(lista_str_obj)
        \\```
        \\
        \\Accepts a text, list, or object argument and returns its length.
        \\
        \\```usrl
        \\$len('abc'), # returns the number of characters in the text
        \\$len(lista), # returns the number of elements in the list
        \\$len(objeto) # returns the number of key/value pairs in the object
        \\```
    },
    .{
        "idx",
        \\```usrl
        \\$idx(elem, lista_str)
        \\```
        \\
        \\Returns the first index of the first argument within the second argument. `NIL`
        \\if not found.
        \\
        \\```usrl
        \\$idx('a', 'abcabc') == 0,
        \\$idx('b', 'abcabc') == 1,
        \\$idx('c', 'abcabc') == 2,
        \\$idx('d', 'abcabc') == NIL
        \\```
    },

    .{
        "lastIdx",
        \\```usrl
        \\$lastIdx(elem, lista_str)
        \\```
        \\
        \\Returns the last index of the first argument within the second argument. `NIL`
        \\if not found.
        \\
        \\```usrl
        \\$lastIdx('a', 'abcabc') == 3,
        \\$lastIdx('b', 'abcabc') == 4,
        \\$lastIdx('c', 'abcabc') == 5,
        \\$lastIdx('d', 'abcabc') == NIL
        \\```
    },
    .{
        "addList",
        \\```usrl
        \\$addList()
        \\```
        \\
        \\Adds an empty list to the context and returns its value.
        \\
        \\```usrl
        \\$lista := $addList();
        \\$len($lista) == 0;
        \\```
    },
    .{
        "addObj",
        \\```usrl
        \\$addObj()
        \\```
        \\
        \\Adds an empty object to the context and returns its value.
        \\
        \\```usrl
        \\$objeto := $addObj();
        \\$len($objeto) == 0;
        \\```
    },
    .{
        "push",
        \\```usrl
        \\$push(elem, lista)
        \\```
        \\
        \\Adds the first argument to the end of the second argument. Always returns `NIL`.
        \\
        \\```usrl
        \\$lista := $addList();
        \\$push('a', $lista);
        \\$push('b', $lista);
        \\$push('c', $lista);
        \\$len($lista) == 3
        \\```
    },
    .{
        "pop",
        \\```usrl
        \\$pop(lista)
        \\```
        \\
        \\Removes and returns the last element of the argument.
        \\
        \\```usrl
        \\$lista; # [ 'a', 'b', 'c' ]
        \\$pop($lista) == 'c';
        \\$pop($lista) == 'b';
        \\$pop($lista) == 'a';
        \\$len($lista) == 0
        \\```
    },
    .{
        "slice",
        \\```usrl
        \\$slice(str, indice, tamanho)
        \\```
        \\
        \\Slices and returns the first argument based on the following arguments. The second argument is the start index and may be negative. The third argument is the length of the result and can be negative to capture the string from back to front.
        \\
        \\```usrl
        \\$slice('abcdef', 1, 2) == 'bc',
        \\$slice('abcdef', 1, -2) == 'ab',
        \\$slice('abcdef', -1, 1) == 'f',
        \\$slice('abcdef', -2, 2) == 'ef',
        \\$slice('abcdef', 3, 999) == 'def',
        \\$slice('abcdef', 3, -999) == 'abcd',
        \\```
    },
    .{
        "str",
        \\```usrl
        \\$str(x)
        \\```
        \\
        \\Converts the given value to a string.
    },
    .{
        "num",
        \\```usrl
        \\$num(x)
        \\```
        \\
        \\Converts the given value to a numeric value. Only accepts text or numeric arguments.
    },
    .{
        "ctx",
        \\```usrl
        \\$ctx()
        \\```
        \\
        \\Returns the context as a value, allowing its properties to be accessed through the member access operator.
        \\
        \\```usrl
        \\$ctx().velocidade == velocidade,
        \\$ctx().vida == vida
        \\```
    },
    .{
        "fileId",
        \\```usrl
        \\$fileId(ref)
        \\```
        \\
        \\Returns the file ID of the reference value as a numeric value.
    },
    .{
        "guid",
        \\```usrl
        \\$guid(ref)
        \\```
        \\
        \\Returns the GUID of the reference value as a string.
    },
    .{
        "guidOf",
        \\```usrl
        \\$guidOf(path)
        \\```
        \\
        \\Looks up and returns the GUID of the asset at `path`, relative to the project root.
        \\
        \\```usrl
        \\$guidOf("./Assets/Prefabs/Player.prefab") == "some guid"
        \\```
    },
    .{
        "assert",
        \\```usrl
        \\$assert(condition)
        \\```
        \\
        \\Assures that `condition` is true and returns its value.
        \\Otherwise, it stops query execution by raising an assertion error.
        \\
        \\```usrl
        \\$assert(rb);
        \\$assert(!rb.m_IsKinematic);
        \\```
    },
});
