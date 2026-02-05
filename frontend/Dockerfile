# Build stage - Use full Node image
FROM node:18 AS build

WORKDIR /app

# Copy package files
COPY package.json ./

# Install dependencies with verbose logging
RUN npm install --loglevel verbose

# Verify react-scripts exists
RUN ls -la node_modules/.bin/

# Copy source
COPY . .

# Build
RUN npm run build

# Production stage
FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
