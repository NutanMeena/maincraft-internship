# Task 2 – Dockerized Nginx Web Server Deployment on AWS EC2

A personal portfolio website (Nutan Meena – Cloud Architect) containerized with Docker using an Nginx Alpine base image and deployed to an AWS EC2 instance.

---

## 🗂️ Project Structure

```
task2/
├── Dockerfile
├── nginx.conf
├── index.html
└── (static assets)
```

---

## 🐳 Docker Setup (Local)

### 1. Build the Docker Image

```bash
docker build -t task2-nginx .
```

The Dockerfile performs the following steps:
- Base image: `nginx:alpine`
- Removes default Nginx HTML files (`/usr/share/nginx/html/*`)
- Copies project files into `/usr/share/nginx/html`
- Copies custom `nginx.conf` to `/etc/nginx/conf.d/default.conf`

**Build output:**
 


---

### 2. Run the Container Locally

```bash
docker run -d -p 8080:80 task2-nginx
```

 

---

### 3. Access Locally

Open your browser and navigate to `http://localhost:8080`
 

---

## ☁️ AWS EC2 Deployment

### Step 1: Launch an EC2 Instance & Get SSH Details

- **Instance name:** My web server
- **Instance ID:** `i-0e54cfb5a66a32bdc`
- **AMI:** Ubuntu 26.04 LTS
- **Region:** ap-south-1 (Mumbai)
- **VPC:** `vpc-05339cab6008c89e2`
- **Security Group:** `sg-0c63377c7db06b508` (launch-wizard-4)
- **Key Pair:** `ABC.pem`
 
---

### Step 2: Connect via SSH

```bash
chmod 400 "ABC.pem"
ssh -i "ABC.pem" ubuntu@ec2-13-201-32-196.ap-south-1.compute.amazonaws.com
```


---

### Step 3: Update System & Install Docker

```bash
sudo apt update -y
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
```
 
---

### Step 4: Clone the Repository

```bash
git clone https://github.com/NutanMeena/maincraft-internship.git
cd maincraft-internship/task2/
```
 
---

### Step 5: Build & Run the Container on EC2

```bash
docker build -t task2-nginx .
docker run -d -p 80:80 task2-nginx
```

---

### Step 6: Access the Live Site

Open your browser and navigate to `http://13.201.32.196`

 
---

## 🌐 Live Demo

| Environment | URL |
|-------------|-----|
| Local       | http://localhost:8080 |
| AWS EC2     | http://13.201.32.196  |

---

## 🛠️ Tech Stack

- **Frontend:** HTML, CSS, JavaScript (Portfolio website)
- **Web Server:** Nginx (Alpine)
- **Containerization:** Docker
- **Cloud:** AWS EC2 (Ubuntu 26.04 LTS, ap-south-1)

---

## 👤 Author

**Nutan Meena** – Cloud Architect / Cloud & DevOps Engineer  
[GitHub](https://github.com/NutanMeena) | [LinkedIn](#) | [Instagram](#)
