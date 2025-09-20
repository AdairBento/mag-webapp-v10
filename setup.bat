
@echo off
setlocal
cd api
if not exist .env ( copy .env.example .env >nul )
call npm install
call npm run db:generate
echo Configure DATABASE_URL e rode: npm run db:migrate
