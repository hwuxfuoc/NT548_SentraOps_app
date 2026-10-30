from fastapi import FastAPI

app = FastAPI(title="SentraOps")


@app.get("/health")
def health():
    return {"status": "ok"}
