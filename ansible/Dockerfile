FROM python:3.7.6-stretch

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sshpass

RUN pip install pip --upgrade
RUN pip install ansible