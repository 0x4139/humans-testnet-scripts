FROM golang:latest

WORKDIR /opt/humans/
RUN wget https://github.com/humansdotai/humans/releases/download/latest/humans_latest_linux_amd64.tar.gz
RUN tar -xvf humans_latest_linux_amd64.tar.gz
CMD [ "./humansd" ]