FROM node:14-buster-slim

WORKDIR /code

RUN apt-get -y update
RUN apt-get -y --no-install-recommends install jq curl ca-certificates

RUN yarn global add @oada/oada-certs

RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.6.1/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq

COPY ./support /support

CMD ["bash"]
