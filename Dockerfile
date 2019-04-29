FROM ubuntu:bionic

RUN mkdir -p /opt/django

WORKDIR /opt/django

COPY . /opt/django

## for apt to be noninteractive
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

## preesed tzdata, update package index, upgrade packages and install needed software
RUN echo "tzdata tzdata/Areas select Europe" > /tmp/preseed.txt; \
    echo "tzdata tzdata/Zones/Europe select Berlin" >> /tmp/preseed.txt; \
    debconf-set-selections /tmp/preseed.txt && \
    rm /etc/timezone | true && \
    rm /etc/localtime | true && \
    apt-get update && \
    apt-get install -y tzdata texlive-latex-extra

RUN apt-get install -y python-pip

## cleanup of files from setup
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install -r requirements.txt


CMD make latexpdf && make epub
