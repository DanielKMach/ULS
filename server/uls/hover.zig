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
    var diag = usrl.ParseDiagnostics.init(allocator);
    defer diag.deinit();

    while (tokenizer.token(&diag)) |result| {
        const tkn = result orelse break;
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
        \\Aceita dois argumentos numéricos e retorna o de menor valor. Equivalente a `$x < $y ? $x : $y`.
    },
    .{
        "max",
        \\```usrl
        \\$max(x, y)
        \\```
        \\
        \\Aceita dois argumentos numéricos e retorna o de maior valor. Equivalente a `$x > $y ? $x : $y`.
    },
    .{
        "floor",
        \\```usrl
        \\$floor(x)
        \\```
        \\
        \\Remove a parte fracionária do argumento numérico, arredondando para baixo.
    },
    .{
        "ceil",
        \\```usrl
        \\$ceil(x)
        \\```
        \\
        \\Remove a parte fracionária do argumento numérico, arredondando para cima.
    },
    .{
        "trunc",
        \\```usrl
        \\$trunc(x)
        \\```
        \\
        \\Remove a parte fracionária do argumento numérico, arredondando em direção ao zero.
    },

    .{
        "round",
        \\```usrl
        \\$round(x)
        \\```
        \\
        \\Remove a parte fracionária do argumento numérico, arredondando para o valor inteiro mais próximo.
    },
    .{
        "sqrt",
        \\```usrl
        \\$sqrt(x)
        \\```
        \\
        \\Retorna a raiz quadrada do argumento numérico.
    },
    .{
        "abs",
        \\```usrl
        \\$abs(x)
        \\```
        \\
        \\Retorna o valor absoluto do argumento numérico.
    },
    .{
        "sin",
        \\```usrl
        \\$sin(x)
        \\```
        \\
        \\Aceita um argumento numérico em radianos e retorna o seu seno.
    },
    .{
        "cos",
        \\```usrl
        \\$cos(x)
        \\```
        \\
        \\Aceita um argumento numérico em radianos e retorna o seu cosseno.
    },
    .{
        "prop",
        \\```usrl
        \\$prop(str)
        \\```
        \\
        \\Acessa a propriedade do contexto através de uma string.
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
        \\Aceita um argumento de texto, lista ou objeto e retorna seu comprimento.
        \\
        \\```usrl
        \\$len('abc'), # retorna o número de caracteres no texto
        \\$len(lista), # retorna o número de elementos na lista
        \\$len(objeto) # retorna o número de pares contidos no objeto
        \\```
    },
    .{
        "idx",
        \\```usrl
        \\$idx(elem, lista_str)
        \\```
        \\
        \\Retorna o primeiro índice do primeiro argumento dentro do segundo argumento. `NIL`
        \\se não encontrado.
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
        \\Retorna o último índice do primeiro argumento dentro do segundo argumento. `NIL`
        \\se não encontrado.
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
        \\Adiciona uma lista vazia ao contexto e retorna seu valor.
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
        \\Adiciona um objeto vazio ao contexto e retorna seu valor.
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
        \\Adiciona o primeiro argumento ao final do segundo argumento. Sempre retorna `NIL`.
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
        \\Remove e retorna o último elemento do argumento.
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
        \\Recorta e retorna o primeiro argumento com base nos argumentos seguintes. O segundo argumento é o índice inicial que pode ser negativo. O terceiro argumento é o comprimento do resultado, podendo ser negativo para capturar a string de trás para frente.
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
        \\Converte o valor dado em uma string.
    },
    .{
        "num",
        \\```usrl
        \\$num(x)
        \\```
        \\
        \\Converte o valor dado em um valor numérico. Somente aceita argumentos textuais ou numéricos.
    },
    .{
        "ctx",
        \\```usrl
        \\$ctx()
        \\```
        \\
        \\Retorna o contexto como um valor, podendo obter suas propriedades através do operador de acesso.
        \\
        \\```usrl
        \\$ctx().velocidade == velocidade,
        \\$ctx().vida == vida
        \\```
    },
});
