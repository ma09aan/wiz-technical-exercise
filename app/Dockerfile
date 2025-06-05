# Dockerfile that defines how to build a container image for my Node.js app.


# Use an appropriate base image (e.g., Node.js)
FROM node:18-alpine As builder

# Sets the working directory inside the container to /app

WORKDIR /app           
# A wildcard is used to ensure both package.json AND package-lock.json are copied.
# Copying this first prevents re-running npm install on every code change.



# Copies both package.json and package-lock.json to /app

COPY package*.json ./

# Install app dependencies using the `npm ci` command instead of `npm install`
# Ensure you have a package-lock.json or npm-shrinkwrap.json for `npm ci`
# If not, use `npm install`
# Installs dependencies efficiently:Uses npm ci if package-lock.json exists (clean and reproducible).
# Falls back to npm install otherwise.

RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi


# Copy local code to the container image.
#Copies the entire app source code to the container’s /app directory.

COPY . .

# Create the wizexercise.txt file as required
# Writes a marker file, likely for automated testing or validation of the exercise.

RUN echo "This is the Wiz Exercise marker file. Success!" > ./wizexercise.txt

# --- Optional: Build step if you have one ---
# RUN npm run build

# --- Release Stage ---
# Starts a new clean stage, again using the same base image.

FROM node:18-alpine

# Sets the working directory again (fresh context).
WORKDIR /app


# Copies only the built dependencies and package manifests from the builder stage.


COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./


# Copies the rest of the application code (including the wizexercise.txt marker).
# This copies everything including wizexercise.txt
COPY --from=builder /app . 

# Expose the port the app runs on
# Declares that the container listens on port 3000 — common for Node apps


EXPOSE 3000 
# Set environment variables (can also be done in K8s manifests)
# ENV MONGODB_URI="mongodb://user:pass@host:port/db" # Better to use K8s secrets

# Run the web service on container startup.
# Ensure server.js (or your entrypoint) exists in the app directory
CMD [ "node", "server.js" ]
