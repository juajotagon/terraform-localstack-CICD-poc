import os
import json
import boto3
from datetime import datetime
from fastapi import FastAPI, HTTPException

app = FastAPI()

s3_client = boto3.client('s3',
    endpoint_url='http://localstack:4566', 
    region_name='us-east-1', #Levantamos lo mismo que de Terraform.
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

BUCKET_NAME = 'bucket-local'

#Creamos los endpoints de la API.

@app.get('/objects')
def list_objects():
    try:
        response = s3_client.list_objects_v2(Bucket=BUCKET_NAME)
        #Indicar que el bucket existe, pero no tiene objetos si está vacío.
        if 'Contents' not in response: 
            return {'message':'El bucket existe, pero no tiene objetos.'}
        
        objects = [obj['Key'] for obj in response['Contents']]
        return {"objects": objects}

    except Exception as e:
        #le mandamos un 500 si no conecta con el S3.
        raise HTTPException(status_code=500, detail=str(e))

@app.post('/objects')
def push_objects(data: dict):
    try:
        file_name = 'object-'+datetime.today().strftime('%Y-%m-%d-%hh-%mm-%ss')+'.json'
        s3_client.put_object(Bucket=BUCKET_NAME,Key=file_name, Body=json.dumps(data))
    
    except Exception as e:
        #le mandamos un 500 si no conecta con el S3.
        raise HTTPException(status_code=500, detail=str(e))
