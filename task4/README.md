Task 4 — Automated Deployment of Dockerized Application on Cloud VM with Nginx Reverse Proxy
📌 What This Task Is About
This task completes the end-to-end DevOps automation loop by automatically deploying a Dockerized portfolio website to an AWS EC2 cloud VM using GitHub Actions CI/CD pipeline, with Nginx configured as a reverse proxy to serve the application professionally on port 80.

🏗️ Architecture Diagram
Developer (Local Machine)
        |
        | git push
        ↓
    GitHub (main branch)
        |
        | triggers
        ↓
GitHub Actions CI/CD Pipeline
        |
        |── Job 1: docker-build
        |       - Checkout code
        |       - Login to Docker Hub
        |       - Build Docker image
        |       - Push image to Docker Hub
        |
        |── Job 2: deploy (runs after docker-build)
                - SSH into EC2 VM
                - Pull latest image from Docker Hub
                - Stop & remove old container
                - Run new container on port 8080
        |
        ↓
AWS EC2 Cloud VM (Ubuntu)
        |
        |── Docker Container (port 8080) ← portfolio-website image
        |
        |── Nginx Reverse Proxy (port 80)
                - Listens on port 80 (public)
                - Forwards traffic → localhost:8080
        |
        ↓
Public Internet → http://13.201.32.196

🔄 Deployment Flow

Developer pushes code to the main branch on GitHub
GitHub Actions automatically triggers the CI/CD pipeline
CI Job (docker-build):

Checks out the latest code
Logs into Docker Hub using stored secrets
Builds a new Docker image from the Dockerfile
Pushes the image to Docker Hub as nutanmeena/portfolio-website:latest


CD Job (deploy):

Uses appleboy/ssh-action to SSH into the EC2 VM
Pulls the latest Docker image from Docker Hub
Stops and removes the existing container
Runs a fresh container on port 8080


Nginx reverse proxy on the VM forwards all incoming traffic from port 80 to the container on port 8080
The updated application is live at the public IP — no manual steps required


🌐 Nginx Role
Nginx acts as a reverse proxy between the public internet and the Docker container.
Why Nginx?

Applications should never be exposed directly via container ports in production
Nginx handles incoming HTTP requests on port 80 (standard web port)
It forwards those requests internally to the Docker container running on port 8080
This is industry-standard production architecture

Nginx Configuration (/etc/nginx/sites-available/docker-app)
nginxserver {
    listen 80;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

⚙️ CI/CD Architecture
Tools Used
ToolPurposeGitHub ActionsAutomates build and deployment on every pushDockerContainerizes the portfolio applicationDocker HubStores and serves the Docker imageSSH (appleboy/ssh-action)Securely connects GitHub Actions to EC2NginxReverse proxy on the VMAWS EC2 (Ubuntu)Cloud VM hosting the application
GitHub Secrets Used
SecretDescriptionDOCKER_USERNAMEDocker Hub usernameDOCKER_PASSWORDDocker Hub passwordVM_HOSTEC2 public IP addressVM_USEREC2 SSH username (ubuntu)VM_SSH_KEYPrivate SSH key for VM access
Workflow File (.github/workflows/docker-ci.yml)
yamlname: Docker CI Pipeline

on:
  push:
    branches:
      - main

jobs:
  docker-build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build Docker Image
        run: docker build -t ${{ secrets.DOCKER_USERNAME }}/portfolio-website:latest ./task2

      - name: Push Docker Image
        run: docker push ${{ secrets.DOCKER_USERNAME }}/portfolio-website:latest

  deploy:
    needs: docker-build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VM
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.VM_HOST }}
          username: ${{ secrets.VM_USER }}
          key: ${{ secrets.VM_SSH_KEY }}
          script: |
            docker pull ${{ secrets.DOCKER_USERNAME }}/portfolio-website:latest
            docker stop app || true
            docker rm app || true
            docker run -d --name app -p 8080:80 ${{ secrets.DOCKER_USERNAME }}/portfolio-website:latest

✅ Expected Output
After every git push to main:

CI builds and pushes Docker image automatically
CD deploys the image to EC2 automatically
Nginx routes traffic securely on port 80
No manual Docker commands required
Application is production-style hosted

🌍 Live Application
URL: http://13.201.32.196
