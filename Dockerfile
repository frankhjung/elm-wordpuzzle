# Stage 1: Build Elm application
FROM node:24-alpine AS builder

WORKDIR /app

# Install Elm compiler
RUN apk add --no-cache curl bash make \
    && curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz \
    && gunzip elm.gz \
    && chmod +x elm \
    && mv elm /usr/local/bin/

COPY package.json package-lock.json ./
RUN npm ci

COPY elm.json Makefile ./
COPY static ./static
COPY src ./src

RUN make build

# Stage 2: Serve static distribution via Nginx
FROM nginx:alpine AS final

COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
