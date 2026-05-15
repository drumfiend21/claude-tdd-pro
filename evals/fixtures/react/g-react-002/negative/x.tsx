import { useEffect } from "react";
export const X = ({ id }) => { useEffect(() => { fetch("/api/" + id); }, [id]); return null; };
