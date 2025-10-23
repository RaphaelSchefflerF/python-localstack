#!/bin/bash

echo "Waiting for LocalStack to be ready..."
until awslocal s3 ls &>/dev/null; do
    sleep 1
done

echo "LocalStack is ready! Creating resources..."