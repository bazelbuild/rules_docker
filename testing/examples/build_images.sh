#!/bin/bash

basic_alpine=basic_alpine:dockerfile
docker build -t $basic_alpine ./basic
docker save -o basic/basic_alpine_img.tar $basic_alpine
