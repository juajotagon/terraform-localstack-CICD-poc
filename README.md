# Prueba técnica para Constella Intelligence de Terraform, Localstack y Github Actions.

Esta repo contiene el código de simulación cloud con Localstack de una creación de un bucket S3 y una cola SQS para publicar mensajes a consumidores cuando se actualiza el S3. 

Se presenta el código tanto como para reproducir en local como para comprobar mediante Github Actions la totalidad de la prueba.

### Python

Se ha realizado una API mediante FastAPI con dos decoradores de GET y POST para obtener los objetos dentro del S3 y publicar al S3, incluyendo JSON de entrada.

Para conectar con aws(localstack) usamos un cliente de boto3.

```python
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
```

### Terraform

Los archivos de Terraform se han creado de acuerdo a Localstack de manera pre-definida añadiendo `skip_requesting_account_id  = true` para poder acceder de forma local de acuerdo con la documentación oficial. 

Además, se ha añadido la política para la cola SQS y el S3.

```terraform
# Política para que S3 pueda enviar mensajes a la cola SQS
resource "aws_sqs_queue_policy" "queue_policy" {
  queue_url = aws_sqs_queue.local_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.local_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.local_bucket.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.local_bucket.id

  queue {
    queue_arn = aws_sqs_queue.local_queue.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.queue_policy]
```

### Localstack (docker-compose)

Igualmente, se ha creado localstack de manera predefinida evitando pasarle docker.sock a la aplicación, la cual no lo necesita para el bucket de S3 y la cola SQS.

```
  localstack:
    container_name: "${LOCALSTACK_DOCKER_NAME:-localstack-main}"
    image: localstack/localstack
    ports:
      - "127.0.0.1:4566:4566"            # LocalStack Gateway
      - "127.0.0.1:4510-4559:4510-4559"  # external services port range
    environment:
      # LocalStack configuration: https://docs.localstack.cloud/references/configuration/
      - DEBUG=${DEBUG:-0}
    volumes:
      #Crea un volumen en la misma carpeta del proyecto.
      - "${LOCALSTACK_VOLUME_DIR:-./volume}:/var/lib/localstack"
```

Además, se han añadido healthchecks y se ha esperado a la creación de localstack para deployear la API de Python.


### Github Actions

Se han realizado dos jobs. El primero, `terraform-check` incluye los pasos de validación de Terraform en primer lugar. En el segundo, `localstack-api-docker-compose` levantamos mediante `docker compose` los contenedores tanto de la API de Python como Localstack, con su posterior ejecución. 

Se puede comprobar en ci.yml ambos jobs.


## Guía de Uso.

1. **Pre-requisitos**
Se necesitará tener `docker`, `terraform`, `aws-cli` instalados. Adicionalmente, se utiliza en Linux `curl` para comunicarse con la API.

2. **Levantar los servicios**
Se levantarán primero los servicios:

```bash
docker compose up -d --build
```

3. **Levantar la infraestructura mediante Terraform**

Navegar a la carpeta de terraform, iniciarlo y aplicar los despliegues del cubo `bucket-local` y la cola `queue-local`:

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

4. **Validar la API**

Aquí se pueden hacer pruebas con la API. Se sugiere exportar además algunas variables a la sesión de la terminal para acortar los comandos de AWS. En este ejemplo, se muestran los de la prueba de Github Actions.


```
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

curl -f http://localhost:8000/objects

aws --endpoint-url=http://localhost:4566 sqs list-queues

curl -X POST http://localhost:8000/objects \
-H "Content-Type: application/json" \
-d '{"accion": "test", "cola": "numero1"}'

curl -X POST http://localhost:8000/objects \
-H "Content-Type: application/json" \
-d '{"accion": "test", "cola": "numero2"}'

aws --endpoint-url=http://localhost:4566 sqs receive-message --queue-url http://localhost:4566/000000000000/queue-local

curl -f http://localhost:8000/objects

```

Pasos en orden:

  -- Se añaden las variables para aws-cli
  -- Se comprueba el bucket vacío en primer lugar.
  -- Se comprueba la cola SQS (aparecerá queue-local)
  -- Se hacen un par de posts de objetos JSON, el usuario puede elegir que otros posts hacer al bucket, pudiendo ser por supuesto otros objetos.
  -- Se comprueba los mensajes en la cola queue-local.

5. **Destruir la infraestructura**

Lo primero aseguramos que no haya nada en la cola ni en el bucket antes de borrarse:

```bash
aws --endpoint-url=http://localhost:4566 sqs purge-queue --queue-url http://localhost:4566/000000000000/queue-local

aws --endpoint-url=http://localhost:4566 s3 rm s3://bucket-local --recursive
```

Posteriormente, destruimos la infraestructura con Terraform:

```bash
terraform destroy -auto-approve
```

Por último, borramos los contenedores y el servicio:

```bash
cd ..
docker compose down
```