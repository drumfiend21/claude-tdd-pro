import { z } from "zod";
const S=z.object({});
app.post("/x",(req,res)=>res.json(S.parse(req.body)));
