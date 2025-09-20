
# syntax=docker/dockerfile:1
FROM node:20-bullseye AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npx prisma generate
RUN npm run build

FROM node:20-bullseye AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/package*.json ./
RUN npm install --omit=dev
COPY --from=build /app/node_modules/.prisma /app/node_modules/.prisma
COPY --from=build /app/node_modules/@prisma /app/node_modules/@prisma
COPY --from=build /app/dist ./dist
COPY prisma ./prisma
EXPOSE 3000
CMD ["node","dist/index.js"]
