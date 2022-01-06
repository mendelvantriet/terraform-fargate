# terraform-fargate

This is unfinished business...

Purpose of the code is to provision Fargate with a Task running a container. In the `example._tfvars` file are the variables that could be used to run a container with a spark job (which can be found at the [pyspark-parquet](https://github.com/mendelvantriet/pyspark-parquet) repository).

## The original excercise

The original excercise was to transform a parquet file and store it in s3, using Python and Terraform. For that I could have made a simple AWS Lambda with some python code. I know many companies use Lambda's for batch jobs, but as their data grows, sooner or later they hit the 5(?) minute timeout.

Fargate does not have such a limit. And with spark, we don't have to worry much about the amout of data either. That is a choice I can defend. Otherwise I would have to say *"I chose AWS Lambda because it is easy and I like easy"*.

## Run

    terraform -chdir=stacks init -backend-config="../backends/demo.tf"
    terraform -chdir=stacks plan -var-file="../tfvars/demo.tfvars"
