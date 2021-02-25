FROM node:14-buster-slim AS install

WORKDIR /code

RUN yarn global add @oada/oada-certs

COPY ./support /support

CMD ["bash"]
