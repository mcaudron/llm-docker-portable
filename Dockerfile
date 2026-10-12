# syntax=docker/dockerfile:1.7
# Build once while connected, then export the resulting image with `docker save`.

FROM debian:bookworm-slim AS build

ARG LLAMA_CPP_REF=v0.6.0
ARG MODEL_URL=https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf
ARG MODEL_FILE=qwen2.5-coder-7b-instruct-q4_k_m.gguf

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates cmake curl g++ git libcurl4-openssl-dev make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch ${LLAMA_CPP_REF} https://github.com/ggml-org/llama.cpp.git . \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF -DGGML_OPENMP=ON -DLLAMA_CURL=OFF \
    && cmake --build build --config Release -j "$(nproc)" --target llama-server

RUN mkdir -p /models \
    && curl --fail --location --retry 3 --output /models/${MODEL_FILE} "${MODEL_URL}"

FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="Offline code LLM API" \
      org.opencontainers.image.description="llama.cpp OpenAI-compatible server with Qwen2.5-Coder 7B"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --uid 10001 llm

# llama.cpp's server links to sibling shared libraries (libllama-server-impl,
# libllama, libggml, ...).  Keep the complete runtime directory together.
COPY --from=build /src/build/bin/ /opt/llama/bin/
COPY --from=build /models /models
COPY docker/entrypoint.sh /usr/local/bin/entrypoint

RUN chmod 0555 /usr/local/bin/entrypoint /opt/llama/bin/llama-server \
    && chown -R llm:llm /models

USER llm
EXPOSE 8080

ENV MODEL=/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
    PATH=/opt/llama/bin:${PATH} \
    LD_LIBRARY_PATH=/opt/llama/bin \
    HOST=0.0.0.0 \
    PORT=8080 \
    MODEL_ID=qwen2.5-coder-7b-instruct-q4_k_m.gguf \
    CONTEXT_SIZE=8192 \
    THREADS=0 \
    PARALLEL=1 \
    N_GPU_LAYERS=0 \
    FLASH_ATTN=auto \
    API_KEY=

ENTRYPOINT ["/usr/local/bin/entrypoint"]
