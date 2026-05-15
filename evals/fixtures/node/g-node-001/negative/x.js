import { z } from "zod";
const Schema = z.object({email: z.string()});
app.post("/x",(req,res)=>{const v=Schema.parse(req.body).email;res.json({v})});
