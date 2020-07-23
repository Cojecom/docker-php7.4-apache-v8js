FROM php:7.4-cli AS v8builder

RUN apt-get update \
    # Install build dependancies
    && apt-get install -y build-essential git python libglib2.0-dev patchelf \
    \
    ######## libv8 build ########
    && cd /tmp \
    # Download build tools
    && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git  \
    && export PATH=/tmp/depot_tools:"$PATH" \
    # Get V8 sources
    && fetch v8 \
    && cd /tmp/v8 \
    # v7.7.310 was released shortly before v8js 2.1.1, therefore was supposed compatible, and turned out to be
    # more recent versions of the 7.x branch might be working, however more recent 8.x version break because of pointer compression
    && git checkout 7.7.310 \
    && gclient sync \
    && tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false \
    && ninja -C out.gn/x64.release/ \
    # Move compiled lib files to /opt/libv8
    && mkdir -p /opt/libv8/lib /opt/libv8/include \
    && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/libv8/lib/ \
    && cp -R include/* /opt/libv8/include/ \
    && for A in /opt/libv8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A;done \
    \
    ######## v8js build ########
    && cd /tmp \
    && git clone https://github.com/phpv8/v8js.git \
    # 2.1.1 is the most recent v8js version as of July 2020
    && git checkout 2.1.1 \
    && cd /tmp/v8js \
    && phpize \
    && ./configure --with-v8js=/opt/libv8 LDFLAGS="-lstdc++" \
    && make test \
    && make install \
    # Copy the extension's .so file to be able to extract it easily
    && cp "$(php -i | grep ^extension_dir | awk '{print $3}')"/v8js.so /tmp


FROM php:7.4-apache
COPY --from=v8builder /tmp/v8js.so "$(php -i | grep ^extension_dir | awk '{print $3}')"

RUN docker-php-ext-enable v8js