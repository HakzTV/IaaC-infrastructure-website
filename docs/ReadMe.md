# WordPress Azure Architecture – eSolutions Consulting

## Overview
This project deploys a secure, scalable, and production-ready WordPress site on Azure using Bicep, Azure Front Door, MySQL Flexible Server, and Azure Monitor.

## Architecture Diagram
(Insert diagram here)

## Key Technologies
- Azure App Service (Linux)
- Azure MySQL Flexible Server
- Azure Front Door with WAF
- Azure Monitor, App Insights, Log Analytics
- Azure DNS
- Bicep (Infrastructure as Code)

## CI/CD Pipeline
- GitHub Actions deploys WordPress code to App Service

## Getting Started
```bash
./deploy.sh

# Reason i picked P1V2 is because it is supports autoscaling and runs on Modern hardware for faster performance and overall it future proofs this solution.
