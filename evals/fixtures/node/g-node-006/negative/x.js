if (!writable.write(chunk)) await once(writable, "drain");
