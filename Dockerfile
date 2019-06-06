FROM node:10.15.2-alpine
RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh
ENV TIC_WEBAPP_DIR /tic
VOLUME /tic/work /tic/logs /tic/config
WORKDIR ${TIC_WEBAPP_DIR}
ADD . ${TIC_WEBAPP_DIR}
RUN npm install
EXPOSE 6030
ENTRYPOINT ["node", "index.js", "-c", "development"]
