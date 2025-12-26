# Docment file:
https://drive.google.com/file/d/1SRS4FyHLd5Cb31VC4ji4yrOhN_x-Ry0g/view?usp=sharing




# Raneen

Media streaming platform built with Ruby on Rails.

## Quick Start

#### 1. Setup Environment

Create `.env` file with your AWS credentials:

```bash
cp .env.example .env
```

### 2. Run with Docker

```bash
# Start all services
make up

# Application will be available at:
# http://localhost:3000
```

### 3. Seed Database (Optional)

```bash
make db-seed
```

This creates:
- Admin user: `admin@raneen.com` / `password123`
- Editor user: `editor@raneen.com` / `password123`
- Sample programs (podcasts & documentaries)

### 4. Access CMS

- URL: http://localhost:3000/cms/programs
- Username: `admin@raneen.com`
- Password: `password123`

## Common Commands

```bash
make up              # Start application
make down            # Stop application
make logs            # View logs
make console         # Rails console
make db-reset        # Reset database
```

## Requirements

- Docker
- Docker Compose
- Make
