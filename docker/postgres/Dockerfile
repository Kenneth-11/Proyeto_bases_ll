FROM postgres:16-bookworm

ARG PG_MAJOR=16
ENV DEBIAN_FRONTEND=noninteractive \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        git \
        libpq-dev \
        postgresql-server-dev-${PG_MAJOR} \
        pkg-config \
        wget \
        freetds-bin \
        freetds-dev \
        libssl-dev \
        libsasl2-dev \
        libzstd-dev \
        libsnappy-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# MongoDB C driver 1.30.2 (dependencia de mongo_fdw)
# ---------------------------------------------------------------------------
WORKDIR /tmp
RUN wget -q https://github.com/mongodb/mongo-c-driver/releases/download/1.30.2/mongo-c-driver-1.30.2.tar.gz \
    && tar xzf mongo-c-driver-1.30.2.tar.gz \
    && cmake -S mongo-c-driver-1.30.2 -B mongo-c-build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF \
        -DENABLE_TESTS=OFF \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_STATIC=OFF \
    && cmake --build mongo-c-build -j2 \
    && cmake --build mongo-c-build --target install \
    && ldconfig \
    && rm -rf /tmp/mongo-c-driver-1.30.2 /tmp/mongo-c-build

# ---------------------------------------------------------------------------
# tds_fdw (PostgreSQL -> SQL Server)
# ---------------------------------------------------------------------------
RUN git clone --depth 1 https://github.com/tds-fdw/tds_fdw.git /tmp/tds_fdw \
    && make -C /tmp/tds_fdw USE_PGXS=1 -j4 \
    && make -C /tmp/tds_fdw USE_PGXS=1 install \
    && rm -rf /tmp/tds_fdw

# ---------------------------------------------------------------------------
# mongo_fdw (PostgreSQL -> MongoDB). Empaqueta json-c como submodulo.
# ---------------------------------------------------------------------------
RUN git clone --depth 1 https://github.com/EnterpriseDB/mongo_fdw.git /tmp/mongo_fdw \
    && wget -qO- https://github.com/json-c/json-c/archive/refs/tags/json-c-0.18-20240915.tar.gz \
        | tar xz -C /tmp \
    && mv /tmp/json-c-json-c-0.18-20240915 /tmp/mongo_fdw/json-c \
    && cmake -S /tmp/mongo_fdw/json-c -B /tmp/mongo_fdw/json-c \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_SHARED_LIBS=ON \
        -DDISABLE_EXTRA_LIBS=ON \
    && make -C /tmp/mongo_fdw/json-c install -j2 \
    && make -C /tmp/mongo_fdw USE_PGXS=1 -j2 \
    && make -C /tmp/mongo_fdw USE_PGXS=1 install \
    && ldconfig \
    && rm -rf /tmp/mongo_fdw

COPY conf/freetds.conf /etc/freetds/freetds.conf
