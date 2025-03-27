# vpn-between-aws-and-azure

## Commands to deploy infrastructure

```
export ARM_CLIENT_ID="INSERT_YOUR_AZURE_CLIENT_ID_HERE"
export ARM_CLIENT_SECRET="INSERT_YOUR_AZURE_CLIENT_SECRET_HERE"
export ARM_TENANT_ID="INSERT_YOUR_AZURE_TENANT_ID_HERE"
export ARM_SUBSCRIPTION_ID="INSERT_YOUR_AZURE_SUBSCRIPTION_ID_HERE"

export AWS_ACCESS_KEY_ID="INSERT_YOUR_AWS_KEY_ID_HERE"
export AWS_SECRET_ACCESS_KEY="INSERT_YOUR_AWS_SECRET_ACCESS_KEY_HERE"

export TF_VAR_ssh_public_key_file="~/.ssh/id_ed25519.pub"

terraform init

terraform plan

terraform apply
```

This `terraform apply` takes about 11 minutes to run

## Testing out VPN connection after infrastructure has been deployed

### SSH into Azure VM to test out HTTP and ICMP connection to AWS EC2 instance

```
ssh ubuntu@$(terraform output azure_jumpbox_public_ip_address | tr -d '"')

curl 10.0.1.4

ping 10.0.1.4
```

### SSH into AWS EC2 instance to test out HTTP and ICMP connection to Azure VM

```
ssh ubuntu@$(terraform output aws_jumpbox_elastic_ip_address | tr -d '"')

curl 10.0.0.4

ping 10.0.0.4
```

