# terraform-fargate

## Run

    terraform -chdir=stacks init -backend-config="../backends/demo.tf"
    terraform -chdir=stacks plan -var-file="../tfvars/demo.tfvars"
