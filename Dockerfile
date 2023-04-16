FROM ubuntu:latest

RUN apt-get update && \
    apt-get -y install software-properties-common && \
    apt-add-repository --yes --update ppa:ansible/ansible && \
    apt-get -y install ansible

WORKDIR /ansible

COPY . .

CMD ["tail", "-f", "/dev/null"]