# Google JavaScript + TypeScript Style — Actionable Rules

Sources:
- https://google.github.io/styleguide/jsguide.html
- https://google.github.io/styleguide/tsguide.html

This is the condensed, enforceable subset that the `claude-tdd-pro`
skills reference. The originals are the canonical authority — anchors
are linked inline so the model can cite specific rules in PR/diff
descriptions or review comments.

## Naming

- **Identifiers**: ASCII letters/digits only; no `_` prefix or suffix on identifiers in TS, including `_` alone for unused params — use destructuring holes `[a, , b]` instead. ([ts#identifiers-underscore-prefix-suffix](https://google.github.io/styleguide/tsguide.html#identifiers-underscore-prefix-suffix))
- **Class / interface / type / enum / decorator / type-parameter**: `UpperCamelCase`, typically nouns. e.g. `class Request`, `interface Readable`. No `IFoo` Hungarian prefix on interfaces. ([js#naming-class-names](https://google.github.io/styleguide/jsguide.html#naming-class-names), [ts#naming-style](https://google.github.io/styleguide/tsguide.html#naming-style))
- **Variable / parameter / function / method / property / module alias**: `lowerCamelCase`. e.g. `sendMessage`, `customerId`. ([ts#naming-rules-by-identifier-type](https://google.github.io/styleguide/tsguide.html#naming-rules-by-identifier-type))
- **Constants**: `CONSTANT_CASE` only for module-level immutables and enum values. Function-scoped `const` stays `lowerCamelCase`. e.g. `const MAX_RETRIES = 3`. ([js#naming-constant-names](https://google.github.io/styleguide/jsguide.html#naming-constant-names))
- **Enum**: `UpperCamelCase` singular noun; members `CONSTANT_CASE`. e.g. `enum Animal { JABBERWOCK }`. ([js#naming-enum-names](https://google.github.io/styleguide/jsguide.html#naming-enum-names))
- **Type parameters**: single uppercase letter `T` or `UpperCamelCase`. ([ts#identifiers-type-parameters](https://google.github.io/styleguide/tsguide.html#identifiers-type-parameters))
- **Files**: `snake_case` in TS (module namespace alias is `lowerCamelCase`, intentional mismatch). e.g. `import * as fooBar from './foo_bar';`. ([ts#identifiers-imports](https://google.github.io/styleguide/tsguide.html#identifiers-imports))
- **Camel-case acronyms**: treat acronyms as words: `loadHttpUrl`, not `loadHTTPURL`; `customerId`, not `customerID`. ([ts#camel-case](https://google.github.io/styleguide/tsguide.html#camel-case))
- **No abbreviations** by deleting letters (`cstmrId` bad); no Hungarian (`kSecondsPerDay` bad). One-letter names allowed only in scopes ≤10 lines. ([js#naming-rules-common-to-all-identifiers](https://google.github.io/styleguide/jsguide.html#naming-rules-common-to-all-identifiers))
- **No `$` prefix** except for third-party framework requirements (Angular, Observables, jQuery, three.js). ([ts#identifiers-dollar-sign](https://google.github.io/styleguide/tsguide.html#identifiers-dollar-sign))
- **Test names**: `_` separators allowed: `testX_whenY_doesZ`. ([ts#identifiers-test-names](https://google.github.io/styleguide/tsguide.html#identifiers-test-names))

## Formatting

- **Quotes**: single quotes `'foo'`, never `"foo"`. Use template literals for interpolation/multiline. ([js#features-strings-use-single-quotes](https://google.github.io/styleguide/jsguide.html#features-strings-use-single-quotes))
- **Semicolons**: required on every statement; ASI is forbidden. ([js#formatting-semicolons-are-required](https://google.github.io/styleguide/jsguide.html#formatting-semicolons-are-required))
- **Indentation**: 2 spaces per block. ([js#formatting-block-indentation](https://google.github.io/styleguide/jsguide.html#formatting-block-indentation))
- **Column limit**: 80 chars. Exceptions: `import`/`export from`, long URLs, shell commands. ([js#formatting-column-limit](https://google.github.io/styleguide/jsguide.html#formatting-column-limit))
- **Trailing commas**: required when the closing bracket is on its own line. ([js#features-arrays-trailing-comma](https://google.github.io/styleguide/jsguide.html#features-arrays-trailing-comma))
- **Braces**: K&R / Egyptian. Opening brace on same line; required for all `if`/`else`/`for`/`while`. Single-line `if (x) foo();` allowed only if no `else` and fits on one line. ([js#formatting-braces-all](https://google.github.io/styleguide/jsguide.html#formatting-braces-all))
- **One statement per line**, blank lines never at start/end of function body. ([js#formatting-one-statement-perline](https://google.github.io/styleguide/jsguide.html#formatting-one-statement-perline))
- **No line continuations** (`\` at end of string line). Concatenate or use template literals. ([js#features-strings-no-line-continuations](https://google.github.io/styleguide/jsguide.html#features-strings-no-line-continuations))
- **Number literals**: lowercase prefixes `0x`, `0o`, `0b`. Never leading-zero decimals. ([js#features-number-literals](https://google.github.io/styleguide/jsguide.html#features-number-literals))
- **Switch**: `default` case required and last; cases either terminate or are commented `// fall through`. ([js#features-switch-default-case](https://google.github.io/styleguide/jsguide.html#features-switch-default-case))

## Imports

- **Four import variants**: `import * as foo from '…'` (namespace, preferred for large APIs); `import {x} from '…'` (named, preferred for clear/frequent symbols); `import x from '…'` (default — only for external modules that require it); `import '…'` (side-effect, only for libs like `'jasmine'`). ([ts#imports](https://google.github.io/styleguide/tsguide.html#imports))
- **Paths**: relative (`./sibling`, `../parent/file`) for same-project files; minimize `../../..`. ([ts#import-paths](https://google.github.io/styleguide/tsguide.html#import-paths))
- **No default exports**: always use named exports. `export class Foo {}`, never `export default class Foo {}`. ([ts#exports](https://google.github.io/styleguide/tsguide.html#exports))
- **No `export let`**: exports are immutable bindings; expose mutable state via getter functions. ([ts#mutable-exports](https://google.github.io/styleguide/tsguide.html#mutable-exports))
- **No container classes** for namespacing — export individual `const`/`function` instead. ([ts#container-classes](https://google.github.io/styleguide/tsguide.html#container-classes))
- **Type-only imports (TS)**: use `import type {Foo} from './foo';` or inline `import {type Foo, Bar} from './foo';` when the symbol is only used in type position. Use `export type {Foo}` for type re-exports. ([ts#import-type](https://google.github.io/styleguide/tsguide.html#import-type))
- **Renaming**: `import {Foo as Bar}` allowed for collisions, generated names, or clarity. ([ts#renaming-imports](https://google.github.io/styleguide/tsguide.html#renaming-imports))
- **Use modules, not namespaces** (no `namespace Foo {}` or `///<reference>`). ([ts#use-modules-not-namespaces](https://google.github.io/styleguide/tsguide.html#use-modules-not-namespaces))

## Types (TS only)

- **Rely on inference** for trivially inferred initializers; do not annotate `const x: boolean = true` or `const s: Set<string> = new Set()` (instead `new Set<string>()`). ([ts#type-inference](https://google.github.io/styleguide/tsguide.html#type-inference))
- **Annotate generic empties** to avoid `unknown`: `const x = new Set<string>();`.
- **Return types**: optional; reviewer may request when complex. ([ts#return-types](https://google.github.io/styleguide/tsguide.html#return-types))
- **Use structural types via `interface`**, declare type at the symbol: `const foo: Foo = {…}` so errors surface at the literal. ([ts#use-structural-types](https://google.github.io/styleguide/tsguide.html#use-structural-types))
- **`interface` over `type` for object shapes**. Use `type` only for unions, primitives, tuples. ([ts#prefer-interfaces](https://google.github.io/styleguide/tsguide.html#prefer-interfaces))
- **Array type**: `T[]` / `readonly T[]` for simple types; `Array<T>` for unions or complex types like `Array<string|number>`. ([ts#arrayt-type](https://google.github.io/styleguide/tsguide.html#arrayt-type))
- **`any` is forbidden by default**: prefer specific type, `unknown`, or generics. If used, suppress with comment explaining why. ([ts#any](https://google.github.io/styleguide/tsguide.html#any))
- **`unknown` over `any`** when type isn't known; narrow via type guards before use. ([ts#any-unknown](https://google.github.io/styleguide/tsguide.html#any-unknown))
- **Forbidden types**: `String`, `Boolean`, `Number`, `Object` wrapper types — always use lowercase `string`/`boolean`/`number`. Don't `new` them. ([ts#wrapper-types](https://google.github.io/styleguide/tsguide.html#wrapper-types))
- **No `{}` type** in most cases; prefer `unknown`, `Record<string, T>`, or `object`. ([ts#empty-interface-type](https://google.github.io/styleguide/tsguide.html#empty-interface-type))
- **Optional fields use `?`, not `|undefined`** in type aliases. `milk?: Milk`, not `milk: Milk|undefined`. Never put `|null`/`|undefined` in a type alias definition. ([ts#prefer-optional-over-undefined](https://google.github.io/styleguide/tsguide.html#prefer-optional-over-undefined))
- **Type assertions**: use `x as Foo` (never `<Foo>x`); double-assert via `unknown` (`x as unknown as Foo`). For object literals use annotation `const x: Foo = {…}`, not assertion. ([ts#type-assertions-syntax](https://google.github.io/styleguide/tsguide.html#type-assertions-syntax))
- **Avoid `!` non-null assertion** without comment justifying it; prefer runtime checks. ([ts#type-and-non-nullability-assertions](https://google.github.io/styleguide/tsguide.html#type-and-non-nullability-assertions))
- **Avoid return-type-only generics**; always specify generics explicitly when calling such APIs. ([ts#return-type-only-generics](https://google.github.io/styleguide/tsguide.html#return-type-only-generics))

## Comments / JSDoc

- **JSDoc `/** … */` for documentation; `//` for implementation comments**. Multi-line implementation comments must use stacked `//`, not `/* */` blocks. ([ts#jsdoc-vs-comments](https://google.github.io/styleguide/tsguide.html#jsdoc-vs-comments))
- **Document all top-level exports** of a module; private members only when purpose isn't obvious. ([ts#document-all-top-level-exports-of-modules](https://google.github.io/styleguide/tsguide.html#document-all-top-level-exports-of-modules))
- **No type annotations in TS JSDoc**: never write `@param {string}`, `@implements`, `@private`, `@override`, `@enum` — TS keywords already convey it. ([ts#jsdoc-type-annotations](https://google.github.io/styleguide/tsguide.html#jsdoc-type-annotations))
- **One tag per line**: `@param left desc` on its own line; never combine. Wrapped descriptions indent 4 spaces. ([ts#jsdoc-tags](https://google.github.io/styleguide/tsguide.html#jsdoc-tags))
- **Markdown allowed**; use `-` lists, not raw indented lines. ([ts#jsdoc-markdown](https://google.github.io/styleguide/tsguide.html#jsdoc-markdown))
- **Don't restate names/types**. Omit `@param`/`@return` when they add nothing. ([ts#redundant-comments](https://google.github.io/styleguide/tsguide.html#redundant-comments))
- **Method descriptions** start with a third-person verb ("Computes…", "Returns…"), not imperative. ([ts#method-and-function-comments](https://google.github.io/styleguide/tsguide.html#method-and-function-comments))
- **JSDoc goes before decorators**, never between decorator and decorated symbol. ([ts#place-documentation-prior-to-decorators](https://google.github.io/styleguide/tsguide.html#place-documentation-prior-to-decorators))
- **Parameter-name comments**: `someFunc(x, /* shouldRender= */ true)` when value isn't self-explanatory. ([ts#comments-when-calling-a-function](https://google.github.io/styleguide/tsguide.html#comments-when-calling-a-function))

## Required patterns (MUST do)

- **Use `const` by default, `let` when reassignment needed**. ([js#features-use-const-and-let](https://google.github.io/styleguide/jsguide.html#features-use-const-and-let))
- **One variable per declaration**: `let a = 1; let b = 2;`, never `let a = 1, b = 2;`. ([js#features-one-variable-per-declaration](https://google.github.io/styleguide/jsguide.html#features-one-variable-per-declaration))
- **Declare locals close to first use**, not at top of block. ([js#features-declared-when-needed](https://google.github.io/styleguide/jsguide.html#features-declared-when-needed))
- **Use `===` and `!==`**. Exception: `== null` to catch both `null` and `undefined`. ([ts#equality-checks](https://google.github.io/styleguide/tsguide.html#equality-checks))
- **Throw `new Error(...)` (or subclass) only**, never strings or plain objects. Always include `new`. ([ts#instantiate-errors-using-new](https://google.github.io/styleguide/tsguide.html#instantiate-errors-using-new))
- **`catch (e: unknown)`**, assert via `instanceof Error`; don't defensively handle non-Errors. ([ts#catching-and-rethrowing](https://google.github.io/styleguide/tsguide.html#catching-and-rethrowing))
- **Empty catch must be commented** explaining why. ([js#features-empty-catch-blocks](https://google.github.io/styleguide/jsguide.html#features-empty-catch-blocks))
- **Function declarations for named functions**: `function foo() {…}` over `const foo = () => …`. ([ts#function-declarations](https://google.github.io/styleguide/tsguide.html#function-declarations))
- **Arrow functions for callbacks/expressions**, never `function() {…}` expressions (except generators or explicit `this` rebinding). ([ts#function-expressions](https://google.github.io/styleguide/tsguide.html#function-expressions))
- **Wrap named callbacks**: `arr.map(n => parseInt(n, 10))`, not `arr.map(parseInt)`. ([ts#functions-as-callbacks](https://google.github.io/styleguide/tsguide.html#functions-as-callbacks))
- **Concise arrow body only when return value is used**; otherwise block body. ([ts#arrow-function-bodies](https://google.github.io/styleguide/tsguide.html#arrow-function-bodies))
- **Use `for…of`** to iterate arrays; `for…in` only on dict objects with `hasOwnProperty` guard. ([ts#iterating-containers](https://google.github.io/styleguide/tsguide.html#iterating-containers))
- **Use rest `...args`**, never `arguments`. Use spread `f(...arr)` instead of `f.apply(null, arr)`. ([ts#rest-and-spread](https://google.github.io/styleguide/tsguide.html#rest-and-spread))
- **Always use `()` with `new`**: `new Foo()`, never `new Foo`. ([js#disallowed-features-omitting-parents-with-new](https://google.github.io/styleguide/jsguide.html#disallowed-features-omitting-parents-with-new))
- **Mark unchanged class fields `readonly`**. Use parameter properties: `constructor(private readonly svc: Svc) {}`. ([ts#use-readonly](https://google.github.io/styleguide/tsguide.html#use-readonly))
- **Initialize fields at declaration** when possible: `private readonly users: string[] = [];`. ([ts#field-initializers](https://google.github.io/styleguide/tsguide.html#field-initializers))
- **Coerce via `String(x)`, `Boolean(x)`, `!!x`** — without `new`. Parse numbers via `Number(x)` + `isFinite` check, not `+x` or `parseInt` (except non-base-10). ([ts#type-coercion](https://google.github.io/styleguide/tsguide.html#type-coercion))

## Forbidden patterns (MUST NOT do)

- **No `var`**. ([js#features-use-const-and-let](https://google.github.io/styleguide/jsguide.html#features-use-const-and-let))
- **No `with` statement**. ([js#disallowed-features-with](https://google.github.io/styleguide/jsguide.html#disallowed-features-with))
- **No `eval` or `new Function(string)`** (except code loaders). ([js#disallowed-features-dynamic-code-evaluation](https://google.github.io/styleguide/jsguide.html#disallowed-features-dynamic-code-evaluation))
- **No `debugger;` in production code**. ([ts#debugger-statements](https://google.github.io/styleguide/tsguide.html#debugger-statements))
- **No `const enum`** — use plain `enum`. ([ts#enums](https://google.github.io/styleguide/tsguide.html#enums))
- **No defining new decorators** — only consume framework decorators. ([ts#decorators](https://google.github.io/styleguide/tsguide.html#decorators))
- **No `#privateField`** — use `private` keyword. ([ts#private-fields](https://google.github.io/styleguide/tsguide.html#private-fields))
- **No `public` modifier** except on non-readonly parameter properties. ([ts#visibility](https://google.github.io/styleguide/tsguide.html#visibility))
- **No `obj['foo']` to bypass visibility**. ([ts#properties-used-outside-of-class-lexical-scope](https://google.github.io/styleguide/tsguide.html#properties-used-outside-of-class-lexical-scope))
- **No prototype manipulation / mixins / monkey-patching builtins**. ([ts#class-prototypes](https://google.github.io/styleguide/tsguide.html#class-prototypes))
- **No `new String/Boolean/Number/Symbol`** wrappers. ([ts#primitive-types-wrapper-classes](https://google.github.io/styleguide/tsguide.html#primitive-types-wrapper-classes))
- **No `Array(x1, x2, x3)` constructor**. Use `[x1, x2, x3]`. ([js#features-arrays-ctor](https://google.github.io/styleguide/jsguide.html#features-arrays-ctor))
- **No non-numeric properties on arrays**. ([js#features-arrays-non-numeric-properties](https://google.github.io/styleguide/jsguide.html#features-arrays-non-numeric-properties))
- **No `+x` unary plus** or `parseInt(x)` for base-10 parsing. ([ts#type-coercion](https://google.github.io/styleguide/tsguide.html#type-coercion))
- **No explicit boolean coercion in `if`/`while`/`for`**: `if (foo)`, not `if (!!foo)`. But enums must be compared explicitly: `if (level !== Level.NONE)`, never `if (level)`. ([ts#implicit-coercion](https://google.github.io/styleguide/tsguide.html#implicit-coercion))
- **No assignment in control conditions** unless wrapped in `((x = f()))`. ([ts#assignment-in-control-statements](https://google.github.io/styleguide/tsguide.html#assignment-in-control-statements))
- **No fall-through in non-empty `case`**. ([ts#switch-statements](https://google.github.io/styleguide/tsguide.html#switch-statements))
- **No arrow functions as class properties** (except event handlers needing stable `this`-bound reference for uninstall). ([ts#arrow-functions-as-properties](https://google.github.io/styleguide/tsguide.html#arrow-functions-as-properties))
- **No `.bind(this)`** in event-handler installation. ([ts#event-handlers](https://google.github.io/styleguide/tsguide.html#event-handlers))
- **No side effects in default-parameter initializers**. ([ts#parameter-initializers](https://google.github.io/styleguide/tsguide.html#parameter-initializers))
- **No `Object.defineProperty` for getters/setters**. ([ts#classes-getters-and-setters](https://google.github.io/styleguide/tsguide.html#classes-getters-and-setters))
- **Getters must be pure** (no observable state change). ([ts#classes-getters-and-setters](https://google.github.io/styleguide/tsguide.html#classes-getters-and-setters))
- **No non-standard JS features** (TC39 stage <4, vendor extensions). ([js#disallowed-features-non-standard-features](https://google.github.io/styleguide/jsguide.html#disallowed-features-non-standard-features))

## Testing rules

- **Test method names** may use `_` separators: `testPop_emptyStack_throws` or `testX_whenY_doesZ`. ([ts#identifiers-test-names](https://google.github.io/styleguide/tsguide.html#identifiers-test-names))
- **Empty `catch` in tests** is forbidden — use `assertThrows()` instead of `try { fail() } catch {}`. ([ts#empty-catch-blocks](https://google.github.io/styleguide/tsguide.html#empty-catch-blocks))
- **Test-only `any`** for mocks must carry a suppression comment explaining the legitimacy. ([ts#any-suppress](https://google.github.io/styleguide/tsguide.html#any-suppress))
