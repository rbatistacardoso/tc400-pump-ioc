# Build EPICS base + asyn + StreamDevice, then run the config-only IOC
# on the stock streamApp binary. VXI-11 is left out of asyn and streamApp
# (not needed, and it would pull in libtirpc).

FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential perl curl ca-certificates libreadline-dev \
    && rm -rf /var/lib/apt/lists/*

ARG BASE_VERSION=7.0.10
ARG ASYN_VERSION=R4-46
ARG STREAM_VERSION=2.8.26

WORKDIR /opt/epics

RUN curl -fsSL https://github.com/epics-base/epics-base/releases/download/R${BASE_VERSION}/base-${BASE_VERSION}.tar.gz | tar xz \
    && mv base-${BASE_VERSION} base \
    && make -C base -j$(nproc)

RUN curl -fsSL https://github.com/epics-modules/asyn/archive/refs/tags/${ASYN_VERSION}.tar.gz | tar xz \
    && mv asyn-${ASYN_VERSION} asyn \
    && echo "EPICS_BASE=/opt/epics/base" > asyn/configure/RELEASE \
    && make -C asyn -j$(nproc) DRV_VXI11=NO

RUN curl -fsSL https://github.com/paulscherrerinstitute/StreamDevice/archive/refs/tags/${STREAM_VERSION}.tar.gz | tar xz \
    && mv StreamDevice-${STREAM_VERSION} stream \
    && printf "EPICS_BASE=/opt/epics/base\nASYN=/opt/epics/asyn\n" > stream/configure/RELEASE \
    && sed -i /vxi11/d stream/streamApp/asynRegistrars.dbd \
    && make -C stream -j$(nproc)

# Collect the binaries we need in one arch-independent place,
# drop static libraries and debug symbols
RUN mkdir bin && cp stream/bin/*/streamApp \
        base/bin/*/caget base/bin/*/caput base/bin/*/camonitor base/bin/*/cainfo bin/ \
    && find base/lib asyn/lib stream/lib -name '*.a' -delete \
    && find bin base/lib asyn/lib stream/lib -type f \( -name '*.so*' -o -perm -u+x \) \
        -exec strip --strip-unneeded {} +


FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        libreadline8 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/epics/bin         /opt/epics/bin
COPY --from=build /opt/epics/base/lib    /opt/epics/base/lib
COPY --from=build /opt/epics/asyn/lib    /opt/epics/asyn/lib
COPY --from=build /opt/epics/stream/lib  /opt/epics/stream/lib
COPY --from=build /opt/epics/stream/dbd  /opt/epics/stream/dbd

ENV PATH=/opt/epics/bin:$PATH \
    STREAM=/opt/epics/stream

COPY ioc /ioc
WORKDIR /ioc
CMD ["streamApp", "st.cmd"]
