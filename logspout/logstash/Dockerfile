FROM logstash:5.1

WORKDIR /logstash
EXPOSE 5000/udp 5000/tcp
COPY logstash.conf /logstash
CMD ["-f", "/logstash/logstash.conf"]
