---
name: google-style-ts
description: Auto-attaches when JS/TS files are touched. Injects the Google JavaScript and TypeScript style rules — naming, formatting, imports, types, JSDoc, required and forbidden patterns — so generated and edited code is born-compliant. Cites RUBRIC.yaml IDs and Google's published style guide anchors. Use this whenever writing or modifying .ts/.tsx/.js/.jsx code.
paths: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx", "**/*.mjs", "**/*.cjs"]
---

# Google JavaScript / TypeScript style — applied rules

You are editing JS/TS code. Every line you write must satisfy the
Google JavaScript Style Guide and the Google TypeScript Style Guide.
The full extract is in `docs/standards/google-js-ts-style.md`. The
machine-checkable subset is in `rubric/RUBRIC.yaml` (rules `g-ts-*`).

## Required patterns (must do)

- `const` by default, `let` only when reassignment is needed; **never** `var`. ([RUBRIC g-ts-003](../../rubric/RUBRIC.yaml), [jsguide#features-use-const-and-let](https://google.github.io/styleguide/jsguide.html#features-use-const-and-let))
- One variable per declaration: `let a = 1; let b = 2;` not `let a = 1, b = 2;`.
- `===` and `!==` always; the only exception is `== null` to catch both `null` and `undefined`. ([g-ts-005](../../rubric/RUBRIC.yaml), [tsguide#equality-checks](https://google.github.io/styleguide/tsguide.html#equality-checks))
- Throw `new Error(...)` (or a subclass) only — never strings, never plain objects. Always include `new`. ([g-ts-009](../../rubric/RUBRIC.yaml))
- `catch (e: unknown)`, narrow via `instanceof Error`. Empty `catch` blocks must carry a comment explaining why.
- Function declarations for named functions (`function foo() {}`); arrow functions for callbacks and expressions.
- `for…of` for arrays; `for…in` only on dict objects with a `hasOwnProperty` guard.
- Mark unchanged class fields `readonly`; prefer parameter properties: `constructor(private readonly svc: Svc) {}`.
- Initialize fields at declaration when possible.

## Forbidden patterns (must not do)

- `var`, `with`, `eval`, `new Function(string)`, `debugger;` in production code. ([g-ts-003, g-ts-004, g-ts-010](../../rubric/RUBRIC.yaml))
- `const enum`, `#privateField`, `public` modifier (except on parameter properties), `obj['foo']` to bypass visibility.
- Prototype manipulation, mixins, monkey-patching builtins.
- `new String/Boolean/Number/Symbol` wrapper instantiations.
- `Array(x1, x2, x3)` constructor — use `[x1, x2, x3]`.
- `+x` unary plus or `parseInt(x)` for base-10 — use `Number(x)` + `isFinite`.
- Default exports — always use named exports. ([g-ts-002](../../rubric/RUBRIC.yaml))
- `any` without an explicit suppression comment justifying it. Prefer `unknown` and narrow. ([g-ts-006](../../rubric/RUBRIC.yaml))
- Wrapper types `String`, `Boolean`, `Number`, `Object` — use lowercase primitives.
- `|undefined` in type aliases — use `?` optional fields.
- `<Foo>x` type assertion syntax — use `x as Foo`. Double-assert via `unknown`.
- Non-null assertion `!` without a justifying comment.

## Naming (g-ts-001)

| Kind | Style | Example |
|---|---|---|
| Class / interface / type / enum / decorator / type-param | UpperCamelCase | `class Request`, `interface Readable` |
| Variable / parameter / function / method / property / module alias | lowerCamelCase | `sendMessage`, `customerId` |
| Module-level immutable constants and enum members | CONSTANT_CASE | `const MAX_RETRIES = 3` |
| TS file names | snake_case | `import * as fooBar from './foo_bar'` |
| Acronyms in identifiers | Treat as words | `loadHttpUrl`, not `loadHTTPURL` |

No `_` prefix or suffix; no `IFoo` Hungarian; no `$` prefix (except framework requirements); one-letter names only in scopes ≤10 lines.

## Imports

- Use modules, not namespaces. No `///<reference>`, no `namespace Foo {}`.
- Named exports only (`export class Foo {}`); no `export default`.
- Type-only imports: `import type {Foo} from './foo';` or inline `import {type Foo, Bar} from './foo';`.
- Relative paths for same-project files; minimize `../../..`.

## Comments / JSDoc

- `/** … */` for documentation; `//` for implementation comments.
- Document every top-level export of a module. ([g-ts-011](../../rubric/RUBRIC.yaml))
- No type annotations in TS JSDoc (`@param {string}`, `@implements`, `@private`, `@override`, `@enum` — TypeScript syntax already conveys it).
- Method descriptions start with a third-person verb: "Computes…", "Returns…".

## Formatting (g-ts-012, delegated to Prettier with the Google preset)

2-space indent, 80-col wrap, single quotes, semicolons required, K&R braces, trailing commas where the closing bracket is on its own line.

## When you write or edit code

1. **Cite rule IDs** in the commit message body when you make a non-trivial style choice (e.g. "named export per g-ts-002").
2. **If you must violate** a rule (e.g. test fixture needs `any`), include a comment on the offending line: `// SUPPRESS g-ts-006: <reason>`.
3. **Run `bash rubric/runner.sh --diff --md`** before declaring done; resolve P0 findings, address P1 findings or justify them.
4. **Refuse changes that bundle reformatting + logic** — split into a pure-format CL first per Google eng-practices.
