import os
import uuid
import json
from typing import List, Optional
from fastapi import FastAPI, File, UploadFile, Form, Request
from fastapi.responses import HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
import io

app = FastAPI()

# Static files och templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# AWS Configuration - hämtas från environment variables
AWS_REGION = os.getenv("AWS_REGION", "eu-north-1")
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")
DYNAMODB_TABLE_NAME = os.getenv("DYNAMODB_TABLE_NAME")

# Lokal storage (när AWS inte är tillgängligt)
LOCAL_STORAGE = {}
LOCAL_IMAGES = {}


def get_aws_status():
    """Kontrollera om AWS-tjänster är tillgängliga"""
    try:
        # Test S3 access
        s3_client = boto3.client("s3", region_name=AWS_REGION)
        if S3_BUCKET_NAME:
            s3_client.head_bucket(Bucket=S3_BUCKET_NAME)
            s3_available = True
        else:
            s3_available = False

        # Test DynamoDB access
        dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
        if DYNAMODB_TABLE_NAME:
            table = dynamodb.Table(DYNAMODB_TABLE_NAME)
            table.load()
            dynamodb_available = True
        else:
            dynamodb_available = False

        # Visualizer är tillgänglig om vi har AWS-tjänster
        visualizer_available = s3_available or dynamodb_available

        return {
            "s3_available": s3_available,
            "s3_bucket": S3_BUCKET_NAME if s3_available else "Local Storage",
            "dynamodb_available": dynamodb_available,
            "dynamodb_table": (
                DYNAMODB_TABLE_NAME if dynamodb_available else "Local Storage"
            ),
            "visualizer_available": visualizer_available,
            "visualizer_url": "Port 8080" if visualizer_available else "Not Available",
        }
    except (ClientError, NoCredentialsError, Exception):
        return {
            "s3_available": False,
            "s3_bucket": "Local Storage",
            "dynamodb_available": False,
            "dynamodb_table": "Local Storage",
            "visualizer_available": False,
            "visualizer_url": "Not Available",
        }


def save_post_aws(post_data):
    """Spara post till DynamoDB"""
    try:
        dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        table.put_item(Item=post_data)
        return True
    except Exception as e:
        print(f"Error saving to DynamoDB: {e}")
        return False


def get_posts_aws():
    """Hämta posts från DynamoDB"""
    try:
        dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        response = table.scan()
        return response.get("Items", [])
    except Exception as e:
        print(f"Error getting from DynamoDB: {e}")
        return []


def upload_image_s3(file_content, file_key):
    """Ladda upp bild till S3"""
    try:
        s3_client = boto3.client("s3", region_name=AWS_REGION)
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=file_key,
            Body=file_content,
            ContentType="image/jpeg",
        )
        return True
    except Exception as e:
        print(f"Error uploading to S3: {e}")
        return False


def get_image_s3(file_key):
    """Hämta bild från S3"""
    try:
        s3_client = boto3.client("s3", region_name=AWS_REGION)
        response = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=file_key)
        return response["Body"].read()
    except Exception as e:
        print(f"Error getting from S3: {e}")
        return None


@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    aws_status = get_aws_status()

    # Hämta posts baserat på tillgänglighet
    if aws_status["dynamodb_available"]:
        uploads = get_posts_aws()
    else:
        uploads = list(LOCAL_STORAGE.values())

    return templates.TemplateResponse(
        "upload.html",
        {"request": request, "uploads": uploads, "aws_status": aws_status},
    )


@app.post("/upload")
async def upload_file(
    title: str = Form(...), note: str = Form(...), file: UploadFile = File(...)
):
    # Generera UUID för posten
    post_id = str(uuid.uuid4())
    file_content = await file.read()

    aws_status = get_aws_status()

    # Spara bild
    if aws_status["s3_available"]:
        file_key = f"images/{post_id}.jpg"
        upload_success = upload_image_s3(file_content, file_key)
        if not upload_success:
            # Fallback till lokalt
            LOCAL_IMAGES[post_id] = file_content
    else:
        # Spara lokalt
        LOCAL_IMAGES[post_id] = file_content

    # Spara post data
    post_data = {"id": post_id, "title": title, "note": note}

    if aws_status["dynamodb_available"]:
        save_success = save_post_aws(post_data)
        if not save_success:
            # Fallback till lokalt
            LOCAL_STORAGE[post_id] = post_data
    else:
        # Spara lokalt
        LOCAL_STORAGE[post_id] = post_data

    return {"message": "Upload successful", "id": post_id}


@app.get("/image/{image_id}")
async def get_image(image_id: str):
    aws_status = get_aws_status()

    # Hämta bild
    if aws_status["s3_available"]:
        file_key = f"images/{image_id}.jpg"
        image_data = get_image_s3(file_key)
        if image_data is None:
            # Fallback till lokalt
            image_data = LOCAL_IMAGES.get(image_id)
    else:
        # Hämta lokalt
        image_data = LOCAL_IMAGES.get(image_id)

    if image_data:
        return StreamingResponse(io.BytesIO(image_data), media_type="image/jpeg")
    else:
        return {"error": "Image not found"}, 404


@app.get("/health")
async def health_check():
    aws_status = get_aws_status()
    return {"status": "healthy", "aws_services": aws_status}
