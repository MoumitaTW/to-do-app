FROM alpine:3.14

RUN apk add --update nodejs yarn

COPY . .

CMD yarn start

EXPOSE 3000
