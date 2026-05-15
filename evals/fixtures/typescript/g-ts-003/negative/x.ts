type T = {k:"a"}|{k:"b"};
function f(t:T){switch(t.k){case "a":return 1; case "b":return 2; default:{const _:never=t;throw new Error(_);}}}
