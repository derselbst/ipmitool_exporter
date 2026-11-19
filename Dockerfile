# Stage 1: Build ipmitool from source
FROM debian:trixie-slim AS ipmitool-builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
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
    git clone https://codeberg.org/IPMITool/ipmitool.git /tmp/ipmitool
WORKDIR /tmp/ipmitool
RUN git checkout d62a996c8bad7b3f8d67ffe3742985a3c96ed218 && \
    ./bootstrap && \
    ./configure --prefix=/usr && \
    make && \
    make install DESTDIR=/ipmitool-root

# This is to fix error:
# IANA PEN registry open failed: No such file or directory
RUN mkdir -p /ipmitool-root/usr/share/misc/
RUN wget --no-check-certificate -O /ipmitool-root/usr/share/misc/enterprise-numbers.txt https://www.iana.org/assignments/enterprise-numbers/enterprise-numbers

# Stage 2: Build the Go exporter
FROM golang:1.27 AS go-builder
ADD . / /build/
WORKDIR /build
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -a -o ipmi_exporter .

# Stage 3: Final image
FROM debian:trixie-slim
# Install runtime dependencies for ipmitool
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev \
    libreadline-dev
WORKDIR /root/
COPY --from=ipmitool-builder /ipmitool-root/usr /usr
COPY --from=go-builder /build/ipmi_exporter ./
CMD ["./ipmi_exporter"]  
