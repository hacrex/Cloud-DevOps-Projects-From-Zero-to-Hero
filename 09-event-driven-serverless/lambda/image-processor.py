import json
import boto3
import os
from PIL import Image
import io
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

# Environment variables
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
THUMBNAIL_SIZES = [(150, 150), (300, 300), (600, 600)]

def lambda_handler(event, context):
    """
    Lambda function to process images uploaded to S3
    Creates thumbnails and sends notifications
    """
    try:
        # Parse S3 event
        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']
            
            logger.info(f"Processing image: {object_key} from bucket: {bucket_name}")
            
            # Skip if it's already a processed image
            if 'thumbnails/' in object_key:
                logger.info(f"Skipping already processed image: {object_key}")
                continue
            
            # Check if it's an image file
            if not is_image_file(object_key):
                logger.info(f"Skipping non-image file: {object_key}")
                continue
            
            # Download the image from S3
            try:
                response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
                image_data = response['Body'].read()
                
                # Process the image
                thumbnails_created = process_image(image_data, object_key)
                
                # Send notification
                send_notification(object_key, thumbnails_created)
                
                logger.info(f"Successfully processed {object_key}")
                
            except Exception as e:
                logger.error(f"Error processing {object_key}: {str(e)}")
                send_error_notification(object_key, str(e))
    
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Images processed successfully'
        })
    }

def is_image_file(filename):
    """Check if the file is an image based on extension"""
    image_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp']
    return any(filename.lower().endswith(ext) for ext in image_extensions)

def process_image(image_data, original_key):
    """Process image and create thumbnails"""
    thumbnails_created = []
    
    try:
        # Open the image
        with Image.open(io.BytesIO(image_data)) as img:
            # Convert to RGB if necessary
            if img.mode in ('RGBA', 'LA', 'P'):
                img = img.convert('RGB')
            
            # Get original dimensions
            original_width, original_height = img.size
            
            # Create thumbnails
            for width, height in THUMBNAIL_SIZES:
                # Calculate aspect ratio
                aspect_ratio = original_width / original_height
                
                if aspect_ratio > 1:  # Landscape
                    new_width = width
                    new_height = int(width / aspect_ratio)
                else:  # Portrait or square
                    new_height = height
                    new_width = int(height * aspect_ratio)
                
                # Resize image
                thumbnail = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                
                # Save thumbnail to memory
                thumbnail_buffer = io.BytesIO()
                thumbnail.save(thumbnail_buffer, format='JPEG', quality=85, optimize=True)
                thumbnail_buffer.seek(0)
                
                # Generate thumbnail key
                file_name = os.path.splitext(original_key)[0]
                file_ext = os.path.splitext(original_key)[1]
                thumbnail_key = f"thumbnails/{file_name}_{width}x{height}{file_ext}"
                
                # Upload thumbnail to S3
                s3_client.put_object(
                    Bucket=OUTPUT_BUCKET,
                    Key=thumbnail_key,
                    Body=thumbnail_buffer.getvalue(),
                    ContentType='image/jpeg',
                    Metadata={
                        'original-image': original_key,
                        'thumbnail-size': f"{width}x{height}",
                        'processed-by': 'lambda-image-processor'
                    }
                )
                
                thumbnails_created.append({
                    'size': f"{width}x{height}",
                    'key': thumbnail_key,
                    'dimensions': f"{new_width}x{new_height}"
                })
                
                logger.info(f"Created thumbnail: {thumbnail_key}")
    
    except Exception as e:
        logger.error(f"Error processing image {original_key}: {str(e)}")
        raise e
    
    return thumbnails_created

def send_notification(original_key, thumbnails_created):
    """Send SNS notification about successful processing"""
    try:
        message = {
            'event': 'image_processed',
            'original_image': original_key,
            'thumbnails_created': len(thumbnails_created),
            'thumbnails': thumbnails_created,
            'timestamp': context.aws_request_id if 'context' in globals() else 'unknown'
        }
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f'Image Processed: {original_key}',
            Message=json.dumps(message, indent=2)
        )
        
        logger.info(f"Sent notification for {original_key}")
        
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")

def send_error_notification(original_key, error_message):
    """Send SNS notification about processing error"""
    try:
        message = {
            'event': 'image_processing_error',
            'original_image': original_key,
            'error': error_message,
            'timestamp': context.aws_request_id if 'context' in globals() else 'unknown'
        }
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f'Image Processing Error: {original_key}',
            Message=json.dumps(message, indent=2)
        )
        
        logger.info(f"Sent error notification for {original_key}")
        
    except Exception as e:
        logger.error(f"Error sending error notification: {str(e)}")