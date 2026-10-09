ARG JEDI_BASE_IMAGE=crystallang/crystal:1.21.1-alpine
FROM ${JEDI_BASE_IMAGE}

# The official Alpine image provides musl and static standard-library dependencies.
RUN apk add --no-cache bash python3 binutils sqlite-dev sqlite-static gnuplot ca-certificates

WORKDIR /workspace
