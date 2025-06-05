# Use an appropriate base image (e.g., Node.js)
FROM node:18-alpine As builder

WORKDIR /app

# Copy application dependency manifests to the container image.
# A wildcard is used to ensure both package.json AND package-lock.json are copied.
# Copying this first prevents re-running npm install on every code change.
COPY package*.json ./

# Install app dependencies using the `npm ci` command instead of `npm install`
# Ensure you have a package-lock.json or npm-shrinkwrap.json for `npm ci`
# If not, use `npm install`
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi


# Copy local code to the container image.
COPY . .

# Create the wizexercise.txt file as required
RUN echo "This is the Wiz Exercise marker file. Success!" > ./wizexercise.txt

# --- Optional: Build step if you have one ---
# RUN npm run build

# --- Release Stage ---
FROM node:18-alpine

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
# This copies everything including wizexercise.txt
COPY --from=builder /app . 

# Expose the port the app runs on
EXPOSE 3000 
# Set environment variables (can also be done in K8s manifests)
# ENV MONGODB_URI="mongodb://user:pass@host:port/db" # Better to use K8s secrets

# Run the web service on container startup.
# Ensure server.js (or your entrypoint) exists in the app directory
CMD [ "node", "server.js" ]
