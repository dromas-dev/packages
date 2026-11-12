# The image scripts/build.sh signs and indexes the apk repository in: Alpine
# with abuild. Its base is pinned by its index digest, which Dependabot moves.
FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
RUN apk add --no-cache abuild
