await fetch("https://api.example.com",{signal:AbortSignal.timeout(5000)});
