FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json .npmrc ./
RUN npm ci
COPY . .
# Vite inlines these at build time.
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
RUN npm run build

FROM joseluisq/static-web-server:2
COPY --from=build /app/build /public
ENV SERVER_FALLBACK_PAGE=/public/index.html
