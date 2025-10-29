# Stage 1: Build ipmitool from source
FROM debian:bullseye-slim AS ipmitool-builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    autoconf \
    automake \
    libtool \
    make \
    gcc \
    g++ \
    pkg-config \
    libssl-dev \
    libreadline-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build ipmitool
# Note: SSL verification disabled due to Docker build environment certificate issues
RUN git config --global http.sslVerify false && \
    git clone https://github.com/ipmitool/ipmitool.git /tmp/ipmitool
WORKDIR /tmp/ipmitool
RUN ./bootstrap && \
    ./configure --prefix=/usr && \
    make && \
    make install DESTDIR=/ipmitool-root

# Stage 2: Build the Go exporter
FROM golang:1.16 AS go-builder
ADD . / /build/
WORKDIR /build
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -a -o ipmi_exporter .

# Stage 3: Final image
FROM debian:bullseye-slim
# Install runtime dependencies for ipmitool
# Note: libssl1.1 is specific to Debian Bullseye; update if base image changes
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl1.1 \
    libreadline8 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /root/
COPY --from=ipmitool-builder /ipmitool-root/usr /usr
COPY --from=go-builder /build/ipmi_exporter ./
CMD ["./ipmi_exporter"]  
