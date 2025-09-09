from fastapi import FastAPI, Request, File, Form, UploadFile
from fastapi.responses import HTMLResponse, Response
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
import base64

app = FastAPI()
templates = Jinja2Templates(directory="templates")

# Mount static files (CSS, JS) to be served at /static
app.mount("/static", StaticFiles(directory="static"), name="static")

# In-memory storage for uploaded images
uploads = []


# Home page endpoint - displays upload form and image gallery
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse(
        "upload.html", {"request": request, "uploads": uploads}
    )


# Upload endpoint - handles file upload with title and description
@app.post("/upload")
async def upload(title: str = Form(), note: str = Form(), file: UploadFile = File()):
    content = await file.read()

    # Store upload data in memory with base64 encoded image
    uploads.insert(
        0,
        {
            "id": len(uploads),
            "title": title,
            "note": note,
            "image": base64.b64encode(content).decode(),
            "type": file.content_type,
        },
    )
    return {"ok": True}


# Image serving endpoint - returns image by ID from memory
@app.get("/image/{id}")
async def image(id: int):
    upload = uploads[id]

    return Response(base64.b64decode(upload["image"]), media_type=upload["type"])
