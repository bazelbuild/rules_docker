FROM openjdk

WORKDIR /java_app

COPY image_data/*.java ./

RUN javac Greeting.java ProjectRunner.java

ENTRYPOINT ["/bin/bash", "-c", "java ProjectRunner"]
