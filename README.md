# Wiz Technical Exercise Implementation

This repository contains the code and configuration for the Wiz Technical Exercise, implemented using AWS, Terraform, and GitHub Actions.

## Overview

The project deploys a three-tier web application with intentional security weaknesses:
1.  **Web Tier**: A containerized Node.js application (e.g., 'tasky' Aufgabenliste) running on Amazon EKS.
2.  **Database Tier**: An outdated MongoDB instance running on an EC2 virtual machine in a public subnet.
3.  **Storage Tier**: An S3 bucket for database backups, configured for public read access.

## Intentional Weaknesses

* EC2 instance (MongoDB) allows SSH from `0.0.0.0/0`.
* EC2 instance (MongoDB) has overly permissive IAM roles.
* S3 bucket for backups is publicly readable and listable.
* The containerized web application in EKS runs with `cluster-admin` privileges.
* Outdated OS/MongoDB version on the database VM.

## DevOps Automation

* **Infrastructure as Code (IaC)**: Terraform is used to define and provision all AWS infrastructure.
* **CI/CD**: GitHub Actions are used for:
    * Automated deployment of infrastructure via Terraform.
    * Automated build and push of the application's Docker image to Amazon ECR.
    * Automated deployment of the application to EKS.

## Security Controls & Detection

* **AWS Native Tools**:
    * AWS Security Hub
    * Amazon GuardDuty
    * AWS Config
    * IAM Access Analyzer
* **Control Plane Logging**: AWS CloudTrail.
* **Preventative Controls**: (To be detailed based on implementation, e.g., specific IAM deny policy, restrictive SG rule).
* **Detective Controls**: (To be detailed based on implementation, e.g., specific AWS Config rule, GuardDuty finding).

## Setup and Deployment

Refer to the "Execution Steps" in the main guide document.

### Prerequisites:
* AWS Account
* GitHub Account & Repository
* Terraform CLI
* AWS CLI
* kubectl
* Docker

### GitHub Secrets Required:
* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_REGION`
* `DB_PASSWORD` (for MongoDB)
* `PROJECT_NAME` (e.g., "wizexercise", used for naming resources and in GitHub Actions env vars)
* `AWS_ACCOUNT_ID` (for EKS kubectl configuration and ECR image paths)
* (Optional for S3 backend) `TF_STATE_BUCKET`, `TF_STATE_LOCK_TABLE`

### Local Setup:
1.  Clone the repository.
2.  Configure AWS CLI (`aws configure`).
3.  (Optional) Initialize Terraform with S3 backend.
4.  Run `terraform init`, `terraform plan`, `terraform apply` from the `terraform` directory.
5.  Build and push Docker image to ECR.
6.  Configure `kubectl` for the EKS cluster.
7.  Deploy Kubernetes manifests.

Pushing to the `main` branch will trigger the GitHub Actions workflows.
