# AWS Infrastructure Sandbox: Multi-Tier Web Architecture

An enterprise-ready, highly available infrastructure-as-code (IaC) laboratory built using **Terraform (v1.15+)** and the **AWS Provider (v6.28+)**. This project focuses on immutable infrastructure deployment patterns, decoupled state orchestration, and isolated network segmentation.

This repository follows the architectural blueprints and design principles established in *Chapter 3: How to Manage Terraform State* of **"Terraform: Up & Running" (3rd Edition)** by Yevgeniy Brikis, augmented with environment decoupling patterns for zero-cost local prototyping.

---

## 🏗️ Architecture Blueprint

The infrastructure provisions a scalable, production-grade network topology:

*   **Network Isolation:** A custom Virtual Private Cloud (VPC) spanning 3 Availability Zones (AZs) with separated Public (Ingress/ALB) and Private (Application/ASG) subnet tiers to protect private compute assets.
*   **High Availability & Compute:** An Auto Scaling Group (ASG) maintaining a pool of EC2 instances driven by an immutable Launch Template configuration.
*   **Traffic Distribution:** An Application Load Balancer (ALB) acting as the ingress target group proxy, distributing HTTP traffic and executing automated health checks.
*   **Decoupled State Persistence:** High-performance Relational Database Service (RDS MySQL) provisioned in an independent lifecycle state layer, linked via secure `terraform_remote_state` lookup fabrics.
*   **State Locking & Backend Governance:** Remote state tracking hosted inside S3 with mandatory default AES256 server-side encryption, public access blocks, object versioning, and state race condition protection handled via DynamoDB `LockID` tracking.

---

## 🧪 Local Laboratory Simulation & Testing (LocalStack + Floci)

To enable rapid debugging, linting, and testing loops without incurring cloud consumption costs, this project is built to execute inside a local cloud emulation boundary using **LocalStack** and **Floci**.

### Production-Grade Code Decoupling
To keep our core Terraform files pure and free of hardcoded mock values, this project leverages two advanced decoupling patterns:
1.  **Terminal Environment Injection:** A configuration script to globally direct the standard AWS Provider to our local container stack via native `AWS_ENDPOINT_URL` environment structures.
2.  **Partial Backend Configuration:** Since Terraform backend blocks do not allow variables, local testing overrides are completely abstracted out of the core code into an independent `backend-local.tfvars` file passed dynamically during the initialization sequence.

---

## 🚀 Getting Started Locally

### 1. Requirements & Prerequisites
Ensure your local system has the following toolchains installed and configured:
*   [Terraform CLI](https://hashicorp.com) (>= 1.15.8)
*   [LocalStack CLI / Desktop](https://localstack.cloud)
*   [Floci Sandbox Engine](https://github.com) (Ensure your local container runtime daemon is running)

### 2. Configure Your Local Terminal Environment
Before running any Terraform operations, you **must source** the environmental setup script to safely bind your active shell session to the local emulator:

```bash
source setup-local.sh
```

### 3. Step-by-Step Deployment Pipeline

Execute the following deployment stages in order. Notice that we pass our shared local backend variables configuration file during the `init` stage of each component to force state routing through LocalStack.

#### **Stage A: Initialize the Global Remote Storage Layer**
```bash
cd global/s3
terraform init -backend-config=../../backend-local.tfvars
terraform apply -auto-approve
```

#### **Stage B: Deploy the Relational Database Tier**
```bash
cd ../../stage/data-stores/mysql
terraform init -backend-config=../../../backend-local.tfvars
terraform apply -auto-approve
```

#### **Stage C: Deploy the Scalable Application Layer**
```bash
cd ../../stage/services/webserver-cluster
terraform init -backend-config=../../../backend-local.tfvars
terraform apply -auto-approve
```

Once the apply stage finishes, you can view the exposed load-balanced container endpoint in your local browser instance at:
👉 **`http://localhost:30000`**

---

## 🛠️ Interacting with the Infrastructure

This local sandbox environment automatically aliases your local terminal instance `aws` command straight to the `awslocal` wrapper CLI tool. You can interact with your mocked cloud state natively:

```bash
# Verify that your Auto Scaling instances are correctly registered in the sandbox
awslocal ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name]" --output table
```

---

## 🌐 Transitioning to Production AWS

To safely lift this entire laboratory suite directly out of the local simulation block and scale it across a true live **Amazon Web Services** environment, you do not need to rewrite your code files:

1.  **Purge Local Shell Session:** Open a fresh terminal shell that has not sourced `setup-local.sh`.
2.  **Inject Valid Production Credentials:** 
    ```bash
    export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
    export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    export AWS_DEFAULT_REGION="us-east-1"
    ```
3.  **Run Pure Core Initializations:** Simply drop the `-backend-config` parameter. Running standard `terraform init` and `terraform apply` commands will automatically build and track everything directly on live cloud resources.
