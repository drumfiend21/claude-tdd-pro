export default async function Page() { const u = await fetch("/api/users"); return <div>{u.toString()}</div>; }
