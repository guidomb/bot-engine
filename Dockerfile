#FROM ibmcom/swift-ubuntu-runtime:4.1
FROM guidomb/swift-snapshots:16.04-4.2-2018-08-20
MAINTAINER Guido Marucci Blas
LABEL Description="Dockerfile that provides Swift's runtime to embed the BotEngine application"

# We can replace this port with what the user wants
EXPOSE 8080

WORKDIR /botengine

# Bundle application source & binaries
COPY .build-ubuntu/x86_64-unknown-linux/release/WotServer wotserver

# Command to start Swift application
CMD ./wotserver --admins $ADMINS --output-channel wot-log --port $PORT --gcloud-delegated-account $GCLOUD_DELEGATED_ACCOUNT
