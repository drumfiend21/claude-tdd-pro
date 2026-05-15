import { expectTypeOf } from "vitest";
export type UserId = string & { readonly __brand: "UserId" };
export function lookup(id:UserId):string{return id;}
