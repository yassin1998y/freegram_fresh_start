# Use Node.js 18 Alpine image for production
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json (if available)
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy the rest of the application code
COPY . .

# Expose the Cloud Run port
EXPOSE 8080

# Start the server
CMD ["node", "server.js"]
