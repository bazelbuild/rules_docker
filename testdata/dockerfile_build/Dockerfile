ARG ALPINE_version
ARG SOME_VAR=default_value

FROM alpine:${ALPINE_version}
ENTRYPOINT ["echo"]
CMD ["Hello World!"]

ENV envVar My environment variable
ENV xyz=321
ENV SOME_VAR=${SOME_VAR}

ADD Data_file.txt /
ADD More_data.txt /usr/
COPY file_to_copy.txt /
LABEL version="7.7" \
      desc="Description for version 7.7"
EXPOSE 8080/tcp
EXPOSE 9876/udp
VOLUME /myVol1 /usr/myVol2

RUN apk add gcc python2
