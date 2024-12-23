FROM docker.io/library/alpine

LABEL org.opencontainers.image.source=https://github.com/computator/smtp-proxy-container

RUN set -eux; \
	apk add --no-cache dma msmtp s-nail tini; \
	mv /etc/dma/dma.conf /etc/dma/dma.conf.default

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["msmtpd"]

ENV \
	DMA_NULLCLIENT=true \
	DMA_SECURETRANSFER=true \
	DMA_STARTTLS=true

VOLUME /var/spool/dma
EXPOSE 25
