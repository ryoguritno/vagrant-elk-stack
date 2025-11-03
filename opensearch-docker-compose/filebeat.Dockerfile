#FROM docker.elastic.co/beats/filebeat-oss:8.11.0
FROM docker.elastic.co/beats/filebeat-oss:7.10.2
COPY filebeat.yml /usr/share/filebeat/filebeat.yml
USER root
COPY certs /usr/share/filebeat/certs/
RUN chown -R root:root /usr/share/filebeat/certs     
RUN chown root:root /usr/share/filebeat/filebeat.yml
