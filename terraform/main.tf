resource "aws_s3_bucket" "local_bucket" {
  bucket = "bucket-local"
}

resource "aws_sqs_queue" "local_queue" {
  name = "queue-local"
}

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
}
