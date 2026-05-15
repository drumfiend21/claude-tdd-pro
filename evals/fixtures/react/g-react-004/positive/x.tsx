import { useState, useEffect } from "react";
export const X = ({ a, b }) => { const [s, set] = useState(0); useEffect(() => set(a + b), [a, b]); return s; };
