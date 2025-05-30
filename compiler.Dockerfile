FROM amazonlinux:2023

SHELL ["/bin/bash", "-c"]

ENV BUILD_DIR="/tmp/build"
ENV INSTALL_DIR="/opt"

# ENV PREFIX=/usr/local \
#     BUILD_DIR=/tmp/build \
#     PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig" \
#     PATH="/usr/local/bin:${PATH}"

# Create All The Necessary Build Directories

RUN mkdir -p ${BUILD_DIR}  \
    ${INSTALL_DIR}/bin \
    ${INSTALL_DIR}/doc \
    ${INSTALL_DIR}/include \
    ${INSTALL_DIR}/lib \
    ${INSTALL_DIR}/lib64 \
    ${INSTALL_DIR}/libexec \
    ${INSTALL_DIR}/sbin \
    ${INSTALL_DIR}/share

# Install Development Tools

WORKDIR /tmp

RUN set -xe \
    && dnf makecache \
    && dnf groupinstall -y "Development Tools"  --setopt=group_package_types=mandatory,default \
    && dnf install -y \
    python3-devel \
    python3-pip \
    openssl-devel \
    gcc \
    gcc-c++ \
    pkgconfig \
    flex \
    bison \
    # cairo-devel \
    # cairo-gobject-devel \
    python3-mako \
    python3-markdown \
    ninja-build \
    python3 \
    gtk-doc \
    glib2-devel \
    libffi-devel \
    freetype-devel \
    readline-devel \
    cmake \
    && dnf clean all && rm -rf /var/cache/dnf

# Install CMake

# RUN  set -xe \
#     && mkdir -p /tmp/cmake \
#     && cd /tmp/cmake \
#     && curl -Ls  https://cmake.org/files/v3.26/cmake-3.26.4.tar.gz \
#     | tar xzC /tmp/cmake --strip-components=1 \
#     && sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake \
#     && ./bootstrap \
#     --prefix=/usr/local \
#     --no-system-jsoncpp \
#     --no-system-librhash \
#     --no-system-curl \
#     && make \
#     && make install

# Install GObject Introspection

RUN  set -xe \
    && mkdir -p /tmp/gobject-introspection \
    && cd /tmp/gobject-introspection \
    && curl -Ls  https://download.gnome.org/sources/gobject-introspection/1.76/gobject-introspection-1.76.1.tar.xz \
    | tar xJvC /tmp/gobject-introspection --strip-components=1 \
    && mkdir build \
    && cd build \
    && pip3 install meson \
    && meson setup \
    --prefix=${INSTALL_DIR} \
    --buildtype=release \
    .. \
    && ninja \
    && ninja install

# Install Boost (https://github.com/boostorg/boost)

RUN set -xe \
    && mkdir -p /tmp/boost \
    && cd /tmp/boost \
    && curl -Ls https://archives.boost.io/release/1.88.0/source/boost_1_88_0.tar.gz \
    | tar xzC /tmp/boost --strip-components=1 \
    && ./bootstrap.sh \
    --prefix=/usr/local \
    --with-python=python3 \
    && ./b2 headers \
    && ./b2 stage -j8 \
    threading=multi \
    link=shared \
    && ./b2 install \
    threading=multi \
    link=shared

# Install NASM (https://www.nasm.us)

ENV VERSION_NASM=2.16.01

RUN set -xe \
    && mkdir -p /tmp/nasm \
    && cd /tmp/nasm \
    && curl -Ls  https://www.nasm.us/pub/nasm/releasebuilds/${VERSION_NASM}/nasm-${VERSION_NASM}.tar.xz \
    | tar xJvC /tmp/nasm --strip-components=1 \
    && ./configure --prefix=${INSTALL_DIR} \
    && make \
    && make install

# Configure Default Compiler Variables

ENV PKG_CONFIG_PATH="${INSTALL_DIR}/lib64/pkgconfig:${INSTALL_DIR}/lib/pkgconfig" \
    PKG_CONFIG="/usr/bin/pkg-config" \
    PATH="${INSTALL_DIR}/bin:${PATH}"

ENV LD_LIBRARY_PATH="${INSTALL_DIR}/lib64:${INSTALL_DIR}/lib"

# Build LibXML2 (https://github.com/GNOME/libxml2/releases)

ENV VERSION_XML2=2.14.3
ENV XML2_BUILD_DIR=${BUILD_DIR}/xml2

RUN set -xe; \
    mkdir -p ${XML2_BUILD_DIR}; \
    curl -Ls https://download.gnome.org/sources/libxml2/${VERSION_XML2%.*}/libxml2-${VERSION_XML2}.tar.xz \
    | tar xJf - -C ${XML2_BUILD_DIR} --strip-components=1

WORKDIR  ${XML2_BUILD_DIR}/

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure \
    --prefix=${INSTALL_DIR} \
    --with-sysroot=${INSTALL_DIR} \
    --enable-shared \
    --disable-static \
    --with-html \
    --with-history \
    --enable-ipv6=no \
    # --with-icu \
    --with-zlib=${INSTALL_DIR} \
    --without-python

RUN set -xe; \
    make install \
    && cp xml2-config ${INSTALL_DIR}/bin/xml2-config

# Install FreeType2 (https://github.com/aseprite/freetype2/releases)

ENV VERSION_FREETYPE2=2.13.0
ENV FREETYPE2_BUILD_DIR=${BUILD_DIR}/freetype2

RUN set -xe; \
    mkdir -p ${FREETYPE2_BUILD_DIR}; \
    curl -Ls https://download-mirror.savannah.gnu.org/releases/freetype/freetype-${VERSION_FREETYPE2}.tar.xz \
    | tar xJvC ${FREETYPE2_BUILD_DIR} --strip-components=1

WORKDIR  ${FREETYPE2_BUILD_DIR}/

RUN set -xe; \
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg

RUN set -xe; \
    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
    -i include/freetype/config/ftoption.h

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure  \
    --prefix=${INSTALL_DIR} \
    --with-sysroot=${INSTALL_DIR} \
    --enable-freetype-config  \
    --disable-static \
    && make \
    && make install

# Install gperf

ENV VERSION_GPERF=3.1
ENV GPERF_BUILD_DIR=${BUILD_DIR}/gperf

RUN set -xe; \
    mkdir -p ${GPERF_BUILD_DIR}; \
    curl -Ls http://ftp.gnu.org/pub/gnu/gperf/gperf-${VERSION_GPERF}.tar.gz \
    | tar xzC ${GPERF_BUILD_DIR} --strip-components=1

WORKDIR  ${GPERF_BUILD_DIR}/

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure  \
    --prefix=${INSTALL_DIR} \
    && make \
    && make install

# Install Fontconfig (https://github.com/freedesktop/fontconfig/releases)

ENV VERSION_FONTCONFIG=2.14.2
ENV FONTCONFIG_BUILD_DIR=${BUILD_DIR}/fontconfig

RUN set -xe; \
    mkdir -p ${FONTCONFIG_BUILD_DIR}; \
    curl -Ls https://www.freedesktop.org/software/fontconfig/release/fontconfig-${VERSION_FONTCONFIG}.tar.gz \
    | tar xzC ${FONTCONFIG_BUILD_DIR} --strip-components=1

WORKDIR  ${FONTCONFIG_BUILD_DIR}/

RUN set -xe; \
    rm -f src/fcobjshash.h

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    FONTCONFIG_PATH=${INSTALL_DIR} \
    ./configure  \
    --sysconfdir=${INSTALL_DIR}/etc \
    --localstatedir=${INSTALL_DIR}/var \
    --prefix=${INSTALL_DIR} \
    --disable-docs \
    --enable-libxml2 \
    && make \
    && make install

# Install Libjpeg-Turbo (https://github.com/libjpeg-turbo/libjpeg-turbo/releases)

ENV VERSION_LIBJPEG=2.1.5.1
ENV LIBJPEG_BUILD_DIR=${BUILD_DIR}/libjpeg

RUN set -xe; \
    mkdir -p ${LIBJPEG_BUILD_DIR}/bin; \
    curl -Ls https://ftp.osuosl.org/pub/blfs/conglomeration/libjpeg-turbo/libjpeg-turbo-${VERSION_LIBJPEG}.tar.gz \
    | tar xzC ${LIBJPEG_BUILD_DIR} --strip-components=1

WORKDIR  ${LIBJPEG_BUILD_DIR}/bin/

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    cmake .. \
    -DCMAKE_BUILD_TYPE=RELEASE \
    -DENABLE_STATIC=FALSE \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    && make \
    && make install

# Install OpenJPEG (https://github.com/uclouvain/openjpeg/releases)

ENV VERSION_OPENJPEG2=2.5.0
ENV OPENJPEG2_BUILD_DIR=${BUILD_DIR}/openjpeg2

RUN set -xe; \
    mkdir -p ${OPENJPEG2_BUILD_DIR}/bin; \
    curl -Ls https://github.com/uclouvain/openjpeg/archive/refs/tags/v${VERSION_OPENJPEG2}.tar.gz \
    | tar xzC ${OPENJPEG2_BUILD_DIR} --strip-components=1

WORKDIR  ${OPENJPEG2_BUILD_DIR}/bin/

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    cmake .. \
    -DCMAKE_BUILD_TYPE=RELEASE \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DBUILD_STATIC_LIBS=OFF \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    && make \
    && make install

# Install Libpng (https://github.com/glennrp/libpng/releases)

ENV VERSION_LIBPNG=1.6.48
ENV LIBPNG_BUILD_DIR=${BUILD_DIR}/libpng

RUN set -xe; \
    mkdir -p ${LIBPNG_BUILD_DIR}; \
    curl -Ls https://downloads.sourceforge.net/libpng/libpng-${VERSION_LIBPNG}.tar.xz \
    | tar xJvC ${LIBPNG_BUILD_DIR} --strip-components=1

WORKDIR  ${LIBPNG_BUILD_DIR}/

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure  \
    --prefix=${INSTALL_DIR} \
    --disable-static \
    && make \
    && make install

# Install LibTIFF (http://download.osgeo.org/libtiff)

ENV VERSION_LIBTIFF=4.5.1
ENV LIBTIFF_BUILD_DIR=${BUILD_DIR}/tiff

RUN set -xe; \
    mkdir -p ${LIBTIFF_BUILD_DIR}; \
    curl -Ls http://download.osgeo.org/libtiff/tiff-${VERSION_LIBTIFF}.tar.gz \
    | tar xzC ${LIBTIFF_BUILD_DIR} --strip-components=1

WORKDIR  ${LIBTIFF_BUILD_DIR}/

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure  \
    --prefix=${INSTALL_DIR} \
    --disable-static \
    && make \
    && make install

# Install Pixman (https://www.cairographics.org/releases)

ENV VERSION_PIXMAN=0.46.0
ENV PIXMAN_BUILD_DIR=${BUILD_DIR}/pixman

RUN set -xe; \
    mkdir -p ${PIXMAN_BUILD_DIR}; \
    curl -Ls https://www.cairographics.org/releases/pixman-${VERSION_PIXMAN}.tar.gz \
    | tar xzC ${PIXMAN_BUILD_DIR} --strip-components=1

WORKDIR  ${PIXMAN_BUILD_DIR}/build

RUN set -xe; \
    ls -al ${PIXMAN_BUILD_DIR}

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    # ./configure  \
    # --prefix=${INSTALL_DIR} \
    # --disable-static \
    # && make \
    # && make install
    pip3 install meson \
    && meson setup --prefix=${INSTALL_DIR} --buildtype=release .. \
    && ninja \
    && ninja install

# Install Cairo (http://www.linuxfromscratch.org/blfs/view/svn/x/cairo.html)

ENV VERSION_CAIRO=1.18.4
ENV CAIRO_BUILD_DIR=${BUILD_DIR}/cairo

RUN set -xe; \
    mkdir -p ${CAIRO_BUILD_DIR}; \
    curl -Ls https://ftp.osuosl.org/pub/blfs/conglomeration/cairo/cairo-${VERSION_CAIRO}.tar.xz \
    | tar xJvC ${CAIRO_BUILD_DIR} --strip-components=1

WORKDIR  ${CAIRO_BUILD_DIR}/build

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    # ./configure  \
    # --prefix=${INSTALL_DIR} \
    # --disable-static \
    # --enable-tee \
    # && make \
    # && make install
    pip3 install meson \
    && meson setup \
    --prefix=${INSTALL_DIR} \
    --buildtype=release -Dxlib-xcb=disabled .. \
    && ninja \
    && ninja install


# Install Little CMS (https://downloads.sourceforge.net/lcms)

ENV VERSION_LCMS=2-2.15
ENV LCMS_BUILD_DIR=${BUILD_DIR}/lcms

RUN set -xe; \
    mkdir -p ${LCMS_BUILD_DIR}; \
    curl -Ls https://downloads.sourceforge.net/lcms/lcms${VERSION_LCMS}.tar.gz \
    | tar xzC ${LCMS_BUILD_DIR} --strip-components=1

WORKDIR  ${LCMS_BUILD_DIR}/

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure  \
    --prefix=${INSTALL_DIR} \
    --disable-static \
    && make \
    && make install

# Install harfbuzz (https://github.com/harfbuzz/harfbuzz/releases)

ENV VERSION_HARFBUZZ=11.2.1
ENV HARFBUZZ_BUILD_DIR=${BUILD_DIR}/harfbuzz

RUN set -xe; \
    mkdir -p ${HARFBUZZ_BUILD_DIR}; \
    curl -Ls "https://github.com/harfbuzz/harfbuzz/archive/refs/tags/${VERSION_HARFBUZZ}.tar.gz" \
    | tar xzC ${HARFBUZZ_BUILD_DIR} --strip-components=1

WORKDIR  ${HARFBUZZ_BUILD_DIR}/

RUN set -xe; \
    pip3 install meson \
    && meson setup build \
    --prefix=${INSTALL_DIR} \
    --buildtype=release \
    && meson compile -C build -j9 \
    && meson install -C build

# Install icu (https://github.com/unicode-org/icu/releases)

ENV VERSION_ICU=67-1
ENV ICU_BUILD_DIR=${BUILD_DIR}/icu

RUN set -xe; \
    mkdir -p ${ICU_BUILD_DIR}; \
    curl -Ls https://github.com/unicode-org/icu/releases/download/release-${VERSION_ICU}/icu4c-${VERSION_ICU/-/_}-src.tgz \
    | tar xzC ${ICU_BUILD_DIR} --strip-components=1

WORKDIR ${ICU_BUILD_DIR}/source

RUN set -xe; \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./runConfigureICU Linux \
    --enable-shared \
    --disable-static \
    # --prefix=${INSTALL_DIR}
    --prefix=/usr/local

RUN set -xe; \
    make \
    && make install

# Install Poppler (https://gitlab.freedesktop.org/poppler/poppler/-/tags)

ENV VERSION_POPPLER=25.05.0
ENV POPPLER_BUILD_DIR=${BUILD_DIR}/poppler
ENV POPPLER_TEST_DIR=${BUILD_DIR}/poppler-test

RUN set -xe; \
    mkdir -p ${POPPLER_TEST_DIR}; \
    git clone git://git.freedesktop.org/git/poppler/test ${POPPLER_TEST_DIR}

RUN set -xe; \
    mkdir -p ${POPPLER_BUILD_DIR}/bin; \
    curl -Ls https://poppler.freedesktop.org/poppler-${VERSION_POPPLER}.tar.xz \
    | tar xJvC ${POPPLER_BUILD_DIR} --strip-components=1

WORKDIR ${POPPLER_BUILD_DIR}/bin/

RUN set -xe; \
    CFLAGS="" \
    # CC="/usr/bin/gcc10-gcc" \
    # CXX="/usr/bin/gcc10-c++" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    -DENABLE_UNSTABLE_API_ABI_HEADERS=ON \
    -DTESTDATADIR=${POPPLER_TEST_DIR} \
    -DENABLE_NSS3=OFF \
    -DENABLE_GPGME=OFF \
    -DENABLE_QT5=OFF \
    -DENABLE_QT6=OFF \
    -DENABLE_LIBCURL=OFF \
    && make \
    && make install

# Install brotli (https://github.com/google/brotli/releases)

ENV VERSION_BROTLI=1.1.0
ENV BROTLI_BUILD_DIR=${BUILD_DIR}/brotli

RUN set -xe; \
    mkdir -p ${BROTLI_BUILD_DIR}; \
    curl -Ls https://github.com/google/brotli/archive/refs/tags/v${VERSION_BROTLI}.tar.gz \
    | tar xzC ${BROTLI_BUILD_DIR} --strip-components=1

WORKDIR ${BROTLI_BUILD_DIR}/out

RUN set -xe; \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_PREFIX_PATH=${INSTALL_DIR} \
    && make \
    && make install

# Remove unnecessary files
RUN rm -rf /opt/share/gtk-doc \
    /opt/share/man \
    /opt/share/doc \
    /opt/lib*/cmake/*Test*
