# syntax=docker/dockerfile:1
# check=error=true

# Production image for Lumen (PRD §10). Built and run by compose.yml:
#   make up        (or: docker compose up -d --build)
#
# Stages keep the final image small — Node, compilers and -dev headers never reach it:
#   frontend → builds the Vue app with Vite into public/vite
#   vips     → compiles a minimal libvips (JPEG/PNG/WebP/GIF/HEIC/AVIF only)
#   build    → installs gems (needs compilers) and precompiles bootsnap
#   final    → ruby-slim + small runtime libs + gems + app + built assets

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.12
ARG NODE_VERSION=24
ARG VIPS_VERSION=8.18.7

# ---- frontend ---------------------------------------------------------------
FROM docker.io/library/node:${NODE_VERSION}-slim AS frontend
WORKDIR /app

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

COPY vite.config.ts tsconfig.json ./
COPY config/vite.json ./config/
COPY app/frontend ./app/frontend
RUN npx vite build --mode production

# ---- base -------------------------------------------------------------------
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Runtime libraries only. Debian's libvips package drags in ~120 MB (ImageMagick, Poppler,
# GnuPG, HDF5, OpenEXR…), so we compile libvips ourselves (vips stage) and install just
# the codecs it links against. jemalloc lowers Ruby's memory use. The pg gem bundles libpq.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libjemalloc2 \
      libglib2.0-0t64 libexpat1 libjpeg62-turbo libspng0 libwebp7 libwebpmux3 libwebpdemux2 \
      libexif12 liblcms2-2 libhwy1t64 libheif1 libheif-plugin-libde265 libheif-plugin-dav1d && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives /usr/share/doc /usr/share/man

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# ---- vips -------------------------------------------------------------------
FROM base AS vips
ARG VIPS_VERSION

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential meson ninja-build pkg-config \
      libglib2.0-dev libexpat1-dev libjpeg62-turbo-dev libspng-dev libwebp-dev libexif-dev \
      liblcms2-dev libhwy-dev libheif-dev

# Source archive of the release tag. Bump VIPS_VERSION and the checksum together:
#   curl -sL https://codeload.github.com/libvips/libvips/tar.gz/refs/tags/v<version> | shasum -a 256
ADD --checksum=sha256:5024b4b36f20e722c267f4a9bfbdbbafb3b37d48d7125cf425c55bbf76cc9286 \
    https://codeload.github.com/libvips/libvips/tar.gz/refs/tags/v${VIPS_VERSION} /tmp/vips.tar.gz

# auto_features=disabled turns every optional codec off; we enable only what Lumen needs.
RUN tar -xzf /tmp/vips.tar.gz -C /tmp && cd /tmp/libvips-${VIPS_VERSION} && \
    meson setup build --prefix=/usr/local --libdir=lib --buildtype=release -Dauto_features=disabled \
      -Djpeg=enabled -Dspng=enabled -Dwebp=enabled -Dexif=enabled -Dlcms=enabled -Dheif=enabled \
      -Dhighway=enabled -Dzlib=enabled -Dnsgif=true -Dppm=false -Danalyze=false -Dradiance=false \
      -Dmodules=disabled -Dcplusplus=false -Dexamples=false -Ddeprecated=false -Dintrospection=disabled && \
    meson compile -C build && meson install -C build --strip && \
    mkdir -p /vips && cp -a /usr/local/lib/libvips.so.42* /vips/

# ---- build ------------------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    find "${BUNDLE_PATH}" -type f \( -name "*.o" -o -name "*.c" -o -name "*.h" \) -delete

COPY . .

# Frontend sources were compiled in the frontend stage; drop them from the image.
# Only app/ and lib/ are bootsnap-precompiled: the full gem cache adds ~44 MB for ~1s of boot.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN rm -rf app/frontend && \
    bundle exec bootsnap precompile -j 1 app/ lib/

# ---- final ------------------------------------------------------------------
FROM base

COPY --from=vips /vips/ /usr/local/lib/
RUN ldconfig && \
    groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails
COPY --chown=rails:rails --from=frontend /app/public/vite /rails/public/vite

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
