#!/bin/bash
cd api
[ ! -f .env ] && cp .env.example .env
npm i
npm run db:generate
echo "Configure DATABASE_URL e rode: npm run db:migrate"
