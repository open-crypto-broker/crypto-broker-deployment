FROM alpine:3.24

WORKDIR /app

COPY --chown=1000:1000 crypto-broker-cli-go/bin/stress-test .

USER 1000:1000

ENTRYPOINT ["sleep", "infinity"]
