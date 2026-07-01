# Thin image for the Qlty coverage Harness plugin.
#
# The qlty CLI is installed at runtime by entrypoint.sh (not baked in) so that
# coverage uploads always use the current CLI without rebuilding this image on
# every qlty release. Pin a specific version with the `qlty_version` setting.
FROM debian:bookworm-slim

# Runtime deps for https://qlty.sh/install.sh: curl to download, xz to
# decompress, ca-certificates for TLS.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
