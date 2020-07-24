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
    # v8.4.371.19 is the stable version as of July 2020, checked via https://omahaproxy.appspot.com/
    && git checkout 8.4.371.19 \
    && gclient sync \
    && tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false \
    && ninja -C out.gn/x64.release/ \
    # Move compiled lib files to /opt/libv8
    && mkdir -p /opt/libv8/lib /opt/libv8/include \
    && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/libv8/lib/ \
    && cp -R include/* /opt/libv8/include/ \
    && for A in /opt/libv8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A;done

    ######## v8js build ########
RUN cd /tmp \
    && git clone https://github.com/phpv8/v8js.git \
    && cd /tmp/v8js \
    # 2.1.1 is the most recent v8js version as of July 2020
    && git checkout php7 \
    && phpize \
    && ./configure --with-v8js=/opt/libv8 LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS" \
    && make all -j4 \
    #&& make test \
    && make install \
    # Copy the extension's .so file to be able to extract it easily
    && cp "$(php -i | grep ^extension_dir | awk '{print $3}')"/v8js.so /tmp


FROM php:7.4-apache
COPY --from=v8builder /tmp/v8js.so /tmp/v8js.so
COPY --from=v8builder /opt/libv8/lib/ /opt/libv8/lib/
RUN mv /tmp/v8js.so "$(php -i | grep ^extension_dir | awk '{print $3}')"

RUN docker-php-ext-enable v8js