#FROM ibmcom/swift-ubuntu-runtime:4.1
FROM guidomb/swift-snapshots:16.04-4.2-2018-06-21
MAINTAINER Guido Marucci Blas
LABEL Description="Dockerfile that provides Swift's runtime to embed the BotEngine application"

# We can replace this port with what the user wants
EXPOSE 8080

WORKDIR /botengine

# Bundle application source & binaries
COPY .build-ubuntu/x86_64-unknown-linux/release/BotEngine BotEngine
COPY google-service-account-credentials-prod.json google-service-account-credentials-prod.json

# Command to start Swift application
CMD [ "sh", "-c", "BotEngine", "-C", "google-service-account-credentials-prod.json" ]
