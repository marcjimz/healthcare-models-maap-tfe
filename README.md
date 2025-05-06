# Azure AI Foundry

This repo has:

- **Root** (`hub.tf`):  
  - Calls `dependent-resources` module  
  - Creates AI Foundry hub + project  
- **Module** `dependent-resources`:  
  - Resource Group, Key Vault, Storage, AI Services  

## Prerequisites

- Terraform ≥ 1.1  
- AZ CLI logged in (`az login`)  
- Subscription set (`az account set -s <your-subscription-id>`)

## Steps

1. **Clone** repo & `cd` in  
2. **Init** Terraform  
```bash
terraform init
```  
3. **Plan**  
```bash
terraform plan \
  -var="subscription_id=28d2df62-e322-4b25-b581-c43b94bd2607" \
  -var="resource_group_location=westus" \
  -var="aihubname=ihc-tfe-deploy" \
  -var="vm_name=windows-bastion" \
  -var="admin_username=azureuser" \
  -var="admin_password=YourPassword\!" \
  -out=tfplan
```  
4. **Apply**  
```bash
terraform apply "tfplan"
```  

After apply you’ll get outputs for resource group, AI Foundry hub ID, and project ID.