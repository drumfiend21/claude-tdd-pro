await db.tx(async (t) => { await t.update(a); await t.update(b); });
