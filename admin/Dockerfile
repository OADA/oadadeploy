FROM node:16-alpine

WORKDIR /code

# If switching back to debian:
#RUN apt-get -y update
#RUN apt-get -y --no-install-recommends install jq curl ca-certificates openssl

RUN apk add bash jq curl ca-certificates openssl

RUN yarn global add @oada/oada-certs

RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.6.1/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq

COPY ./support /support
RUN chmod +x /support/domains/domain-add

CMD ["bash"]
