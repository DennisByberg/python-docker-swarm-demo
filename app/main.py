from fastapi import FastAPI, Request, File, Form, UploadFile
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
import uvicorn

app = FastAPI(title="Image Upload Demo")
templates = Jinja2Templates(directory="templates")


@app.get("/", response_class=HTMLResponse)
async def upload_form(request: Request):
    return templates.TemplateResponse("upload.html", {"request": request})


@app.post("/upload")
async def upload_file(
    title: str = Form(...), note: str = Form(...), file: UploadFile = File(...)
):
    return {
        "message": "Upload received!",
        "title": title,
        "note": note,
        "filename": file.filename,
        "content_type": file.content_type,
    }


@app.get("/health")
async def health_check():
    return {"status": "healthy"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
