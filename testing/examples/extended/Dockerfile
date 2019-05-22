FROM alpine:3.8
ENV envVar My environment variable
ENV xyz=321
ENTRYPOINT ["echo", "Hello"]
CMD ["World"]
ADD image_data/Data_file.txt /
ADD image_data/More_data.txt /usr
ADD image_data/tarfile.tar /
COPY image_data/file_to_copy.txt /
LABEL version="7.7" \
      desc="Description for version 7.7"
EXPOSE 8080/tcp
EXPOSE 9876/udp
VOLUME /myVol1 /usr/myVol2
