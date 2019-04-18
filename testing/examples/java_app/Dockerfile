# Simple Dockerfile that creates an image to act as a java executable given the
# required source files. It copies the source files and compiles them inside
# the image.
FROM openjdk

WORKDIR /java_app

COPY image_data/*.java ./

RUN javac Greeting.java ProjectRunner.java

ENTRYPOINT ["/bin/bash", "-c", "java ProjectRunner"]
