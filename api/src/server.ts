import app from "./http/app";

if (process.env.NODE_ENV !== "test") {
  const port = Number(process.env.PORT ?? 3001);
  app.listen(port, () => {
    console.log(`[api] listening on :${port}`);
  });
}

export default app;
