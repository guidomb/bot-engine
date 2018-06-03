FROM ibmcom/swift-ubuntu-runtime:4.1
MAINTAINER IBM Swift Engineering at IBM Cloud
LABEL Description="Template Dockerfile that extends the ibmcom/swift-ubuntu-runtime image."

# We can replace this port with what the user wants
EXPOSE 8080

# Install system level packages
# RUN apt-get update && apt-get dist-upgrade -y

WORKDIR /botengine

# Bundle application source & binaries
COPY ./.build-ubuntu/x86_64-unknown-linux/release/BotEngine BotEngine

# Command to start Swift application
CMD [ "sh", "-c", "BotEngine" ]
