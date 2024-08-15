ARG UPSTREAM=2.4.4
FROM analogic/poste.io:$UPSTREAM
RUN apt-get update && apt-get install less

# Default to listening only on IPs bound to the container hostname
ENV LISTEN_ON=host
ENV SEND_ON=

COPY files /

RUN chmod +x /patches

RUN /patches && rm /patches
