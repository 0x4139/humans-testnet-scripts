FROM alpine:3.16.2

WORKDIR /opt/humans/
RUN apk add wget tar
RUN wget https://github.com/humansdotai/humans/releases/download/latest/humans_latest_linux_arm64.tar.gz
RUN tar -xvf humans_latest_linux_arm64.tar.gz
CMD [ "./humansd" ]