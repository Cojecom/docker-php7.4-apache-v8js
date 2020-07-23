FROM php:7.4-apache

# Install required dependencies
RUN apt-get update \
    && apt-get install -y build-essential git python libglib2.0-dev patchelf

RUN cd /tmp \
    && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git

RUN cd /tmp \
    && export PATH=/tmp/depot_tools:"$PATH" \
    && fetch v8

RUN cd /tmp/v8 \
    && export PATH=/tmp/depot_tools:"$PATH" \
    && git checkout 7.7.310 \
    && gclient sync \
    && tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false

RUN cd /tmp/v8 \
    && export PATH=/tmp/depot_tools:"$PATH" \
    && ninja -C out.gn/x64.release/

RUN cd /tmp/v8 \
    && mkdir -p /opt/libv8/lib /opt/libv8/include \
    && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/libv8/lib/ \
    && cp -R include/* /opt/libv8/include/ \
    && for A in /opt/libv8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A;done

RUN cd /tmp \
    && git clone https://github.com/phpv8/v8js.git \
    && cd v8js \
    && phpize \
    && ./configure --with-v8js=/opt/libv8 LDFLAGS="-lstdc++"

RUN cd /tmp/v8js \
    && make test \
    && make install

RUN docker-php-ext-enable v8js

RUN apt-get remove -y build-essential git python libglib2.0-dev patchelf \
    && apt autoremove -y \
    && rm -rf /tmp/v8js /tmp/v8 /tmp/depot_tools

