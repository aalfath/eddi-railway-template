# EDDI for Railway: the official EDDI image with a small Caddy front that adds a
# login (HTTP basic auth, generated password) and an open /healthz for Railway.
# EDDI itself listens on 127.0.0.1:7070 only. Bump both pins together with a
# CHANGELOG.md entry; a merge to main notifies everyone who deployed the template.
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM labsai/eddi:6.7.1@sha256:3f2a38d1621d28165b119ab98881c473ffc9fbdbd4b29b835e78be1a44d820fb

USER root
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY Caddyfile /etc/eddi-railway/Caddyfile
COPY start.sh /usr/local/bin/eddi-railway-start
RUN chmod 0755 /usr/local/bin/eddi-railway-start /usr/local/bin/caddy
USER 185

ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/eddi-railway-start"]
