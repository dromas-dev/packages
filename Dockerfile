# packages.dromas.dev: the tree scripts/build.sh made, served by NGINX's
# unprivileged image on 8080 (nginx.conf). Nothing runs in the build: the
# tree and the config are copied in.
FROM nginxinc/nginx-unprivileged:1.31.7-alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY tree/ /srv/packages/
