FROM alpine:3.20
RUN apk add --no-cache ca-certificates curl unzip python3 wget \
 && curl -fsSL -o /tmp/core.zip \
      "https://github.com/XTLS/Xray-core/releases/download/v25.9.11/Xray-linux-64.zip" \
 && unzip -q /tmp/core.zip -d /tmp/core \
 && install -m 755 /tmp/core/xray /usr/local/bin/appd \
 && mkdir -p /usr/local/share/appd \
 && if [ -f /tmp/core/geoip.dat ]; then cp /tmp/core/geoip.dat /usr/local/share/appd/; fi \
 && if [ -f /tmp/core/geosite.dat ]; then cp /tmp/core/geosite.dat /usr/local/share/appd/; fi \
 && rm -rf /tmp/core /tmp/core.zip \
 && adduser -D -u 1000 app
WORKDIR /opt/app
COPY server.py /opt/app/server.py
COPY start.sh /opt/app/start.sh
RUN chmod +x /opt/app/start.sh /opt/app/server.py
ENV PORT=8080 \
    APP_BIN=/usr/local/bin/appd \
    XRAY_LOCATION_ASSET=/usr/local/share/appd
EXPOSE 8080
USER 1000
ENTRYPOINT ["/opt/app/start.sh"]
