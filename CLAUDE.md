# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TodoList is a full-stack application with:
- **Frontend**: Vue 3 + Vite (port 5173 dev, served on port 80 in production via nginx)
- **Backend**: Express.js API (port 3000)
- **Database**: MySQL 8.0

## Development Commands

### Frontend
```bash
cd frontend
npm install
npm run dev      # Development server (port 5173)
npm run build    # Production build to dist/
npm run preview # Preview production build
```

### Backend
```bash
cd backend
npm install
npm run dev      # Development with nodemon
npm run start    # Production
```

## Architecture

### Frontend (`frontend/`)
- Vue 3 SPA with Composition API
- Axios for API calls with JWT interceptor
- Single-page app with auth flow (login/register)
- API base URL configured via `VITE_API_BASE_URL` env var

### Backend (`backend/src/`)
- Express REST API with JWT authentication
- Routes: `/api/auth/login`, `/api/auth/register`, `/api/todos`
- Database schema auto-initializes on startup (creates `users` and `todos` tables)
- Default admin user: `admin` / `admin123`

### API Endpoints
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | /api/auth/register | No | Register new user |
| POST | /api/auth/login | No | Login, returns JWT |
| GET | /api/todos | Yes | List user's todos |
| POST | /api/todos | Yes | Create todo |
| PUT | /api/todos/:id | Yes | Update todo (title/completed) |
| DELETE | /api/todos/:id | Yes | Delete todo |
| GET | /health | No | Health check |

## Docker Deployment

Root-level `docker-compose.yml` orchestrates all three services:
```bash
docker-compose up -d --build
```

Backend Dockerfile uses Node 20 Alpine, frontend uses nginx:alpine for serving the built Vue app.

## Environment Variables

### Backend (`backend/.env`)
```
DB_HOST=mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=<password>
DB_NAME=todolist
PORT=3000
JWT_SECRET=<secret>
MYSQL_ROOT_PASSWORD=<password>
```

### Frontend (`.env`)
```
VITE_API_BASE_URL=http://localhost:3000/api  # or production URL
```
