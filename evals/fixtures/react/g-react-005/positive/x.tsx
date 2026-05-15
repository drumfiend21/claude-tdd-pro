export default async function Page() { const data = await fetch("/api/x"); return <div>{data.toString()}</div>; }
