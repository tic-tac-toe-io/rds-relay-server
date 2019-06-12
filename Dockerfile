FROM node:12.4.0-alpine
RUN apk update && apk upgrade && \
	apk add --no-cache bash git openssh
ENV APP_NAME rds-relay-server
ENV APP_DIR /tic
VOLUME /tic/work /tic/logs /tic/config
WORKDIR ${APP_DIR}
ADD . ${APP_DIR}
RUN npm install
EXPOSE 6030
ENTRYPOINT ["node", "/tic/index.js"]
CMD ["start", "-w", "1", "-c", "/tic/config/default.yml"]
