class MyError extends Error { constructor(m,code){super(m);this.code=code;}}
throw new MyError("bad","E_BAD");
