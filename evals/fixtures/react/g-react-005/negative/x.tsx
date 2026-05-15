import { Suspense } from "react";
async function Inner() { const d = await fetch("/api/x"); return <div>{d.toString()}</div>; }
export default function Page() { return <Suspense><Inner /></Suspense>; }
